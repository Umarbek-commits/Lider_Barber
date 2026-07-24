/// A сом-discount promo code the client enters at booking.
class PromoCode {
  const PromoCode({
    required this.id,
    required this.code,
    required this.discountSom,
    required this.isActive,
  });

  final String id;
  final String code;
  final int discountSom;
  final bool isActive;

  factory PromoCode.fromMap(Map<String, dynamic> map) {
    return PromoCode(
      id: map['id'] as String,
      code: map['code'] as String,
      discountSom: (map['discount_som'] as num).toInt(),
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }
}
