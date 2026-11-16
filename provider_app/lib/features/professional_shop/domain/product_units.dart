/// Centralized universal units configuration for Jamui Services
class ProductUnits {
  static const List<String> commonUnits = [
    'kg',
    'g',
    'mg',
    'L',
    'ml',
    'piece',
    'pack',
    'packet',
    'bag',
    'bottle',
    'box',
    'dozen',
    'pair',
    'meter',
    'cm',
    'feet',
    'set',
    'size',
    'custom',
  ];

  static String formatUnitLabel(String unit, String value) {
    final v = value.trim();
    final u = unit.trim();
    if (u.toLowerCase() == 'size') {
      return v.toLowerCase().startsWith('size') ? v : 'Size $v';
    }
    if (u.toLowerCase() == 'custom') {
      return v;
    }
    if (v.isEmpty) {
      return u;
    }
    return '$v $u';
  }
}

/// Represents an option in the simplified two-step product form
class ProductUnitOption {
  String id;
  String unit;
  String customUnit;
  String value;
  double sellingPrice;
  double mrp;
  double buyPrice;
  int stock;
  bool isActive;

  ProductUnitOption({
    this.id = '',
    required this.unit,
    this.customUnit = '',
    required this.value,
    required this.sellingPrice,
    required this.mrp,
    this.buyPrice = 0.0,
    required this.stock,
    this.isActive = true,
  });

  String get effectiveUnit => unit == 'custom' && customUnit.isNotEmpty ? customUnit : unit;

  String get displayTitle => ProductUnits.formatUnitLabel(effectiveUnit, value);

  String get uniqueKey => '${effectiveUnit.toLowerCase().trim()}_${value.toLowerCase().trim()}';

  int get baseUnitsPerOption {
    final val = double.tryParse(value) ?? 1.0;
    final u = effectiveUnit.toLowerCase().trim();
    if (u == 'kg' || u == 'kilogram' || u == 'kgs') return (val * 1000).round();
    if (u == 'g' || u == 'gram' || u == 'gm' || u == 'gms') return val.round();
    if (u == 'mg' || u == 'milligram') return val.round().clamp(1, 1000000);
    if (u == 'l' || u == 'liter' || u == 'litre' || u == 'ltr') return (val * 1000).round();
    if (u == 'ml' || u == 'milliliter') return val.round();
    if (u == 'dozen' || u == 'dz' || u == 'दर्जन') return (val * 12).round();
    return val.round();
  }

  ProductUnitOption copyWith({
    String? id,
    String? unit,
    String? customUnit,
    String? value,
    double? sellingPrice,
    double? mrp,
    double? buyPrice,
    int? stock,
    bool? isActive,
  }) {
    return ProductUnitOption(
      id: id ?? this.id,
      unit: unit ?? this.unit,
      customUnit: customUnit ?? this.customUnit,
      value: value ?? this.value,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      mrp: mrp ?? this.mrp,
      buyPrice: buyPrice ?? this.buyPrice,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
    );
  }
}

