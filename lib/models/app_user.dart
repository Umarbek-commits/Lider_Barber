enum UserRole {
  client,
  admin;

  static UserRole fromDb(String value) =>
      value == 'admin' ? UserRole.admin : UserRole.client;
}

/// Authenticated user profile (row in `public.users`, keyed to auth uid).
class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.contactPhone,
    this.createdAt,
  });

  final String id;
  final String phone;
  final UserRole role;
  final String? name;

  /// Real contact phone the client entered when booking (Google gives none).
  final String? contactPhone;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      phone: map['phone'] as String,
      role: UserRole.fromDb(map['role'] as String),
      name: map['name'] as String?,
      contactPhone: map['contact_phone'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
    );
  }
}
