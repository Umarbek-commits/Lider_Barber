enum UserRole {
  client,
  admin,
  barber;

  static UserRole fromDb(String value) => switch (value) {
        'admin' => UserRole.admin,
        'barber' => UserRole.barber,
        _ => UserRole.client,
      };
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
  bool get isBarber => role == UserRole.barber;

  /// Admin or barber — has access to the management panel.
  bool get isStaff => role == UserRole.admin || role == UserRole.barber;

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
