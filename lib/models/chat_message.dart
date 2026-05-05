class ChatMessage {
  final int? id;
  final String senderEmail;
  final String receiverEmail;
  final String message;
  final String timestamp;
  final String senderRole; // 'doctor' or 'customer'

  ChatMessage({
    this.id,
    required this.senderEmail,
    required this.receiverEmail,
    required this.message,
    required this.timestamp,
    required this.senderRole,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderEmail': senderEmail,
      'receiverEmail': receiverEmail,
      'message': message,
      'timestamp': timestamp,
      'senderRole': senderRole,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      senderEmail: map['senderEmail'] as String,
      receiverEmail: map['receiverEmail'] as String,
      message: map['message'] as String,
      timestamp: map['timestamp'] as String,
      senderRole: map['senderRole'] as String,
    );
  }
}



