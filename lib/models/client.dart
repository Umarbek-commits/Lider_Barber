/// A customer record. Deduplicated by phone number.
class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    this.notes,
    this.isBlacklisted = false,
    this.blacklistReason,
    this.visitsCount = 0,
    this.totalSpent = 0,
    this.lastVisit,
  });

  final String id;
  final String name;
  final String phone;
  final String? notes;
  final bool isBlacklisted;
  final String? blacklistReason;
  final int visitsCount;
  final int totalSpent;
  final DateTime? lastVisit;

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      notes: map['notes'] as String?,
      isBlacklisted: (map['is_blacklisted'] as bool?) ?? false,
      blacklistReason: map['blacklist_reason'] as String?,
      visitsCount: (map['visits_count'] as num?)?.toInt() ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toInt() ?? 0,
      lastVisit: map['last_visit'] == null
          ? null
          : DateTime.parse(map['last_visit'] as String),
    );
  }
}
