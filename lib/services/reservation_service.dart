import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationService {
  /// Confirms a pending reservation
  static Future<void> confirmReservation(String reservationId) async {
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .update({
      'status': 'confirmed',
      'cancelledBy': null, // Clear any previous cancellation
    });
  }

  /// Completes a confirmed reservation
  static Future<void> completeReservation(String reservationId) async {
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .update({
      'status': 'completed',
      'cancelledBy': null,
    });
  }

  /// Cancels a reservation by doctor or admin.
  /// The slot stays booked (isBooked=true) so it does NOT become available again.
  /// Only customer cancellation releases the slot (handled in customer_page.dart).
  static Future<void> cancelReservation(String reservationId, {required String role}) async {
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .update({
      'status': 'cancelled',
      'cancelledBy': role, // 'doctor' or 'admin'
    });
  }

  /// Releases a slot when a reservation is deleted.
  /// Call this before deleting the reservation document.
  static Future<void> releaseSlotForReservation(String reservationId) async {
    final resDoc = await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .get();

    if (!resDoc.exists) return;

    final slotId = resDoc.data()?['slotId'] as String?;
    if (slotId != null && slotId.isNotEmpty) {
      final slotRef = FirebaseFirestore.instance
          .collection('available_slots')
          .doc(slotId);
      final slotDoc = await slotRef.get();
      if (slotDoc.exists) {
        await slotRef.update({'isBooked': false});
      }
    }
  }
}
