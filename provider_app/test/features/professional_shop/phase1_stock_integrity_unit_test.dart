import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JAMUI SERVICES — Phase 1 Stock Integrity & Formatting Unit Tests', () {
    String formatStock(num? val) {
      if (val == null) return '0';
      if (val % 1 == 0) return val.toInt().toString();
      return val.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
    }

    test('10 kg minus 750 g equals 9.25 kg without integer truncation', () {
      const double initialKg = 10.0;
      const int initialGrams = 10000;
      const int orderedGrams = 750;

      final remainingGrams = initialGrams - orderedGrams;
      expect(remainingGrams, equals(9250));

      final remainingKg = remainingGrams / 1000.0;
      expect(remainingKg, equals(9.25));
      expect(formatStock(remainingKg), equals('9.25'));
    });

    test('1 Litre minus 250 ml equals 0.75 L (not 0 L)', () {
      const int initialMl = 1000;
      const int orderedMl = 250;

      final remainingMl = initialMl - orderedMl;
      expect(remainingMl, equals(750));

      final remainingL = remainingMl / 1000.0;
      expect(remainingL, equals(0.75));
      expect(formatStock(remainingL), equals('0.75'));
    });

    test('Whole integer numbers format cleanly without floating point tail', () {
      expect(formatStock(10.0), equals('10'));
      expect(formatStock(50), equals('50'));
      expect(formatStock(0.0), equals('0'));
      expect(formatStock(null), equals('0'));
    });

    test('Decimal precision validation rejects more than 3 decimal places', () {
      bool isValidPrecision(String val) {
        final decParts = val.trim().split('.');
        return !(decParts.length > 1 && decParts[1].length > 3);
      }

      expect(isValidPrecision('0.5'), isTrue);
      expect(isValidPrecision('0.25'), isTrue);
      expect(isValidPrecision('0.125'), isTrue);
      expect(isValidPrecision('10'), isTrue);
      expect(isValidPrecision('0.1234'), isFalse); // 4 decimals rejected
      expect(isValidPrecision('1.0005'), isFalse); // 4 decimals rejected
    });

    test('Pack items reject decimal quantities', () {
      bool isPackAmountValid(String val) {
        final parsed = double.tryParse(val.trim());
        if (parsed == null || parsed <= 0) return false;
        return parsed % 1 == 0;
      }

      expect(isPackAmountValid('1'), isTrue);
      expect(isPackAmountValid('5'), isTrue);
      expect(isPackAmountValid('0.5'), isFalse);
      expect(isPackAmountValid('1.5'), isFalse);
    });

    test('Product edit payload removes protected inventory fields', () {
      final payload = <String, dynamic>{
        'title': 'Tata Salt',
        'sellingPrice': 40.0,
        'regularPrice': 45.0,
        'unit': 'kg',
        'stockType': 'bulk',
        'baseStockQuantity': 50000,
        'stockQuantity': 50,
        'totalStockQuantity': 50,
        'inStock': true,
        'totalOrders': 5,
        'totalRevenue': 200.0,
      };

      final sanitized = Map<String, dynamic>.from(payload);
      sanitized.remove('stockQuantity');
      sanitized.remove('totalStockQuantity');
      sanitized.remove('baseStockQuantity');
      sanitized.remove('inStock');
      sanitized.remove('totalOrders');
      sanitized.remove('totalRevenue');

      expect(sanitized.containsKey('baseStockQuantity'), isFalse);
      expect(sanitized.containsKey('stockQuantity'), isFalse);
      expect(sanitized.containsKey('totalStockQuantity'), isFalse);
      expect(sanitized.containsKey('inStock'), isFalse);
      expect(sanitized['title'], equals('Tata Salt'));
      expect(sanitized['sellingPrice'], equals(40.0));
    });
  });
}

