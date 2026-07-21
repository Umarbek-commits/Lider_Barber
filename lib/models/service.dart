/// A bookable service offered by the barber.
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.priceSom,
    required this.durationMin,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int priceSom;
  final int durationMin;
  final String? description;
  final bool isActive;
  final int sortOrder;

  Duration get duration => Duration(minutes: durationMin);
  String get priceLabel => '$priceSom сом';

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: map['id'] as String,
      name: map['name'] as String,
      priceSom: (map['price_som'] as num).toInt(),
      durationMin: (map['duration_min'] as num).toInt(),
      description: map['description'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsert() => {
        'name': name,
        'price_som': priceSom,
        'duration_min': durationMin,
        'description': description,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}
