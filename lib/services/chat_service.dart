import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stable chat ID prevents duplicates
  static String getChatId(String customerId, String doctorId) {
    return '${customerId}_$doctorId';
  }

  // Completes the Entry Gate flow and initializes the chat
  static Future<void> initializeChat({
    required String customerId,
    required String doctorId,
    required bool hasReservation,
    required bool isUrgent,
    required String initialMessage,
    required String customerName,
    required String doctorName,
  }) async {
    final chatId = getChatId(customerId, doctorId);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final consultationRef = chatRef.collection('consultations').doc();
    final consultationId = consultationRef.id;
    
    // Create the consultation document
    await consultationRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'isUrgent': isUrgent,
      'hasReservation': hasReservation,
      'status': 'active',
    });

    // Create or update the chat document
    await chatRef.set({
      'participants': [customerId, doctorId],
      'customerId': customerId,
      'doctorId': doctorId,
      'customerName': customerName,
      'doctorName': doctorName,
      'lastMessage': initialMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'hasReservation': hasReservation,
      'isUrgent': isUrgent,
      'isInitialized': true,
      'activeConsultationId': consultationId,
      // createdAt only sets on initial creation
    }, SetOptions(merge: true));
    
    // Increment unread count safely
    await chatRef.update({
      'unreadCountDoctor': FieldValue.increment(1),
    });

    // Send the first message (from customer)
    await sendMessage(
      chatId: chatId,
      senderId: customerId,
      text: initialMessage,
      type: 'text',
      isFirstMessage: true, // skip updating unread since we just did it above
      consultationId: consultationId,
    );

    // Send the automated system message to CUSTOMER only
    await sendMessage(
      chatId: chatId,
      senderId: 'system',
      text: "We have notified the doctor about your case. You will receive a response shortly.",
      type: 'system',
      isFirstMessage: false, // updates unreadCountUser
      consultationId: consultationId,
      visibleTo: customerId,
    );

    // Send the automated system message to DOCTOR only
    await sendMessage(
      chatId: chatId,
      senderId: 'system',
      text: "New Case Received\nUrgent: ${isUrgent ? 'Yes' : 'No'}\nReservation: ${hasReservation ? 'Yes' : 'No'}\nProblem: $initialMessage",
      type: 'system',
      isFirstMessage: false, // updates unreadCountDoctor
      consultationId: consultationId,
      visibleTo: doctorId,
    );
  }

  // Create an Emergency Auto-Booking or Doctor Quick Booking safely
  static Future<void> createLinkedBooking({
    required String chatId,
    required String customerId,
    required String customerName,
    required String doctorId,
    required String doctorName,
    required bool isEmergency,
  }) async {
    // 1. Check if user already has an active booking with this doctor
    final existingRes = await _firestore
        .collection('reservations')
        .where('userId', isEqualTo: customerId)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    if (existingRes.docs.isNotEmpty) {
      throw Exception('You already have an active reservation with this doctor.');
    }

    // 2. Find the nearest available slot by sorting in Dart to avoid missing composite index
    final slotsQuery = await _firestore
        .collection('available_slots')
        .where('doctorId', isEqualTo: doctorId)
        .where('isBooked', isEqualTo: false)
        .get();

    // Sort manually to avoid index issues
    final availableSlots = slotsQuery.docs.toList();
    availableSlots.sort((a, b) {
      final aTime = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      return aTime.compareTo(bTime);
    });

    final slotDoc = availableSlots.isNotEmpty ? availableSlots.first : null;
    final slotId = slotDoc?.id;
    final slotData = slotDoc?.data();

    final chatRef = _firestore.collection('chats').doc(chatId);
    final resRef = _firestore.collection('reservations').doc();

    final chatDoc = await chatRef.get();
    final activeConsultationId = chatDoc.data()?['activeConsultationId'] as String?;

    // 3. Perform a transaction to ensure slot is still available
    await _firestore.runTransaction((transaction) async {
      if (slotDoc != null) {
        final slotRef = _firestore.collection('available_slots').doc(slotId);
        final freshSlot = await transaction.get(slotRef);
        if (!freshSlot.exists || freshSlot.data()?['isBooked'] == true) {
          throw Exception('Slot is no longer available. Please try again.');
        }

        // Mark slot as booked
        transaction.update(slotRef, {'isBooked': true});
      }

      // Create reservation
      transaction.set(resRef, {
        'userId': customerId,
        'doctorId': doctorId,
        'customerName': customerName,
        'doctorName': doctorName,
        'date': slotData?['date'] ?? 'Immediate',
        'time': slotData?['time'] ?? 'Now',
        'status': isEmergency ? 'confirmed' : 'pending',
        'isEmergency': isEmergency,
        'chatId': chatId,
        'createdFromChat': true,
        'slotId': slotId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update Chat
      transaction.update(chatRef, {
        'hasReservation': true,
        'isUrgent': false, // Turn off urgent since it's booked
        'linkedReservationId': resRef.id,
        if (slotId != null) 'linkedSlotId': slotId,
      });

      // Update Consultation if exists
      if (activeConsultationId != null) {
        final consultationRef = chatRef.collection('consultations').doc(activeConsultationId);
        transaction.update(consultationRef, {
          'hasReservation': true,
          'isUrgent': false,
          'status': 'closed',
          'linkedReservationId': resRef.id,
          if (slotId != null) 'linkedSlotId': slotId,
        });
      }
    });

    // 4. Send a system message about the booking
    await sendMessage(
      chatId: chatId,
      senderId: 'system',
      text: isEmergency 
          ? "Emergency booking created for ${slotData?['date'] ?? 'Immediate'} at ${slotData?['time'] ?? 'Now'}. Please go to the clinic immediately."
          : "A booking has been created for ${slotData?['date'] ?? 'Immediate'} at ${slotData?['time'] ?? 'Now'}.",
      type: 'system',
      visibleTo: customerId,
    );
  }

  static Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required String type,
    String? consultationId,
    String? visibleTo,
    bool isFirstMessage = false,
  }) async {
    final isSystem = type == 'system';
    
    String? activeId = consultationId;
    if (activeId == null) {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      activeId = chatDoc.data()?['activeConsultationId'] as String?;
    }

    // Add message to subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'text': text,
      'type': type,
      if (activeId != null) 'consultationId': activeId,
      if (visibleTo != null) 'visibleTo': visibleTo,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!isFirstMessage) {
      // Find out who is who by looking at the chatId (customerId_doctorId)
      final parts = chatId.split('_');
      if (parts.length != 2) return;
      final customerId = parts[0];
      final doctorId = parts[1];

      bool isCustomerSending = senderId == customerId;
      // If it's a system message sent after the user initialized, we determine recipient by visibleTo
      if (isSystem && visibleTo != null) {
        isCustomerSending = visibleTo == doctorId; // If visible to doctor, act as if customer sent it
      } else if (isSystem) {
        isCustomerSending = false; // default system messages go to user
      }

      try {
        await _firestore.collection('chats').doc(chatId).update({
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          // Use atomic increment
          if (isCustomerSending) 'unreadCountDoctor': FieldValue.increment(1),
          if (!isCustomerSending) 'unreadCountUser': FieldValue.increment(1),
        });
      } catch (e) {
        // Fallback to set with merge if document somehow missing
        await _firestore.collection('chats').doc(chatId).set({
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          if (isCustomerSending) 'unreadCountDoctor': FieldValue.increment(1),
          if (!isCustomerSending) 'unreadCountUser': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    }
  }

  static Future<void> resetUnreadCount(String chatId, String role) async {
    // If the role is customer, reset unreadCountUser. Else reset unreadCountDoctor.
    final updateData = role == 'customer' 
        ? {'unreadCountUser': 0} 
        : {'unreadCountDoctor': 0};

    try {
      await _firestore.collection('chats').doc(chatId).update(updateData);
    } catch (e) {
      // Document might not exist yet if this is a new chat, ignore.
    }
  }

  static Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  static Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
