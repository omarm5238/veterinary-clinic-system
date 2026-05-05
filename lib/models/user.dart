class User {
  final String? uid;
  final int? id; // Kept for legacy compatibility if needed
  final String email;
  final String password;
  final String role; // 'doctor' or 'customer'
  final String? name;

  User({
    this.uid,
    this.id,
    required this.email,
    required this.password,
    required this.role,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'id': id,
      'email': email,
      'password': password,
      'role': role,
      'name': name,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid: map['uid'] as String?,
      id: map['id'] as int?,
      email: map['email'] as String,
      password: map['password'] as String,
      role: map['role'] as String,
      name: map['name'] as String?,
    );
  }
}



