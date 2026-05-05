import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user.dart';
import '../services/local_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_nav_bar.dart';
import 'chat_list_page.dart';
import 'sign_in_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerPage extends StatefulWidget {
  final User user;

  const CustomerPage({super.key, required this.user});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  int _currentIndex = 0;
  String? _processingSlotId;
  @override
  void initState() {
    super.initState();
  }


  Future<void> _logout() async {
    await firebase_auth.FirebaseAuth.instance.signOut();
    await LocalStorageService.instance.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.glassBackground,
        child: SafeArea(
          child: Column(
            children: [
              // Glass AppBar
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${widget.user.name ?? widget.user.email}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Customer Dashboard',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
              Expanded(child: _getCurrentPage()),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: GlassNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            activeIcon: Icon(Icons.event_available, color: Colors.white),
            label: 'Available',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            activeIcon: Icon(Icons.book, color: Colors.white),
            label: 'My Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            activeIcon: Icon(Icons.chat, color: Colors.white),
            label: 'Chat',
          ),
        ],
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildAvailableSlots();
      case 1:
        return _buildMyReservations();
      case 2:
        return ChatListPage(currentUser: widget.user);
      default:
        return _buildAvailableSlots();
    }
  }

  Widget _buildAvailableSlots() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('available_slots')
          .where('isBooked', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final slots = snapshot.data?.docs ?? [];

        if (slots.isEmpty) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No available slots right now',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final doc = slots[index];
            final slot = doc.data() as Map<String, dynamic>;
            slot['id'] = doc.id;
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.8),
                    radius: 30,
                    child: const Icon(Icons.calendar_today, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${slot['date']} at ${slot['time']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Doctor: ${slot['doctorName']}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _processingSlotId != null
                        ? null
                        : () => _bookSlot(slot),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(_processingSlotId == slot['id'] ? 'Booking...' : 'Book'),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (index * 100).ms).slideX();
          },
        );
      },
    );
  }

  Future<void> _bookSlot(Map<String, dynamic> slot) async {
    if (_processingSlotId != null) return;
    final userUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return;

    setState(() {
      _processingSlotId = slot['id'];
    });

    try {
      final slotRef = FirebaseFirestore.instance.collection('available_slots').doc(slot['id']);
      
      // Query for existing reservation by this user for this slot to reuse it
      final existingRes = await FirebaseFirestore.instance
          .collection('reservations')
          .where('slotId', isEqualTo: slot['id'])
          .where('userId', isEqualTo: userUid)
          .get();

      final reservationRef = existingRes.docs.isNotEmpty 
          ? existingRes.docs.first.reference 
          : FirebaseFirestore.instance.collection('reservations').doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Proper transactional read using direct doc ref (NOT a query)
        final slotDoc = await transaction.get(slotRef);
        if (!slotDoc.exists || slotDoc.data()?['isBooked'] == true) {
          throw Exception('Slot is no longer available.');
        }

        transaction.set(reservationRef, {
          'userId': userUid,
          'userName': widget.user.name ?? widget.user.email,
          'customerName': widget.user.name ?? widget.user.email,
          'doctorId': slot['doctorId'],
          'doctorName': slot['doctorName'] ?? 'Unknown Doctor',
          'date': slot['date'] ?? 'Unknown Date',
          'time': slot['time'] ?? 'Unknown Time',
          'slotId': slot['id'],
          'status': 'pending',
          'cancelledBy': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(slotRef, {'isBooked': true});
      });

      if (!mounted) return;
      setState(() {
        _processingSlotId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation created! Waiting for doctor confirmation.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingSlotId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please try again.')),
      );
    }
  }

  /// Customer cancels their own reservation.
  /// This releases the slot back to Available for everyone.
  Future<void> _cancelReservation(String reservationId, String? slotId) async {
    try {
      final resRef = FirebaseFirestore.instance.collection('reservations').doc(reservationId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Proper transactional read using direct doc ref
        final resDoc = await transaction.get(resRef);
        if (!resDoc.exists) {
          throw Exception('Reservation not found.');
        }

        final resData = resDoc.data()!;
        final currentStatus = resData['status'] as String? ?? '';
        if (currentStatus == 'cancelled' || currentStatus == 'completed') {
          throw Exception('Reservation is already $currentStatus.');
        }

        // Get slotId from the reservation document (prefer stored, fallback to param)
        final actualSlotId = resData['slotId'] as String? ?? slotId;

        DocumentReference? slotRef;
        DocumentSnapshot? slotDoc;

        // Prepare the slot using direct document reference
        if (actualSlotId != null && actualSlotId.isNotEmpty) {
          slotRef = FirebaseFirestore.instance
              .collection('available_slots')
              .doc(actualSlotId);
          slotDoc = await transaction.get(slotRef);
        }

        // Cancel the reservation
        transaction.update(resRef, {
          'status': 'cancelled',
          'cancelledBy': 'customer',
        });

        if (slotRef != null && slotDoc != null && slotDoc.exists) {
          transaction.update(slotRef, {'isBooked': false});
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled. The slot is now available again.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling: $e')),
      );
    }
  }

  Widget _buildMyReservations() {
    final userUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: userUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Hide reservations cancelled by the customer, as they return to the 'Available' page
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          final cancelledBy = data['cancelledBy'] as String?;
          if (status == 'cancelled' && cancelledBy == 'customer') return false;
          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.calendar_today, size: 80, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No reservations yet',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Book an available slot to get started.',
                    style: TextStyle(color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? 'pending';
            final canCancel = (status == 'pending' || status == 'confirmed');

            Color statusColor;
            IconData statusIcon;
            switch (status) {
              case 'confirmed':
                statusColor = Colors.blue;
                statusIcon = Icons.check_circle_outline;
                break;
              case 'completed':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'cancelled':
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                break;
              case 'pending':
              default:
                statusColor = Colors.yellow;
                statusIcon = Icons.hourglass_empty;
            }

            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.8),
                    radius: 30,
                    child: Icon(statusIcon, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['date'] ?? 'Unknown Date'} at ${data['time'] ?? 'Unknown Time'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Doctor: ${data['doctorName'] ?? 'Unknown Doctor'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canCancel)
                    TextButton(
                      onPressed: () => _cancelReservation(
                        doc.id,
                        data['slotId'] as String?,
                      ),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ).animate().fadeIn(delay: (index * 100).ms).slideX();
          },
        );
      },
    );
  }

}


