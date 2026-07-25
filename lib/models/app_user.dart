class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'business' or 'customer'
  final String? phone;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
    };
  }

  factory AppUser.fromMap(Map<dynamic, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'customer',
      phone: map['phone'],
    );
  }
}
