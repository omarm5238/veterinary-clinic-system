class Reservation {
  final int? id;
  final String? firestoreId;
  final String? userId;
  final String? doctor;
  final String date;
  final String time;
  final String? customerEmail;
  final String? customerName;
  final String status; // 'available', 'booked', 'completed'
  final String? notes;

  Reservation({
    this.id,
    this.firestoreId,
    this.userId,
    this.doctor,
    required this.date,
    required this.time,
    this.customerEmail,
    this.customerName,
    this.status = 'available',
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'doctor': doctor,
      'date': date,
      'time': time,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'status': status,
      'notes': notes,
    };
  }

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'] as int?,
      userId: map['userId'] as String?,
      doctor: map['doctor'] as String?,
      date: map['date'] as String,
      time: map['time'] as String,
      customerEmail: map['customerEmail'] as String?,
      customerName: map['customerName'] as String?,
      status: map['status'] as String,
      notes: map['notes'] as String?,
    );
  }
}



