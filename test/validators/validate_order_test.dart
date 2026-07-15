import 'package:flutter_test/flutter_test.dart';
import 'package:order_flow/providers/order_provider.dart';

Map<String, dynamic> _prod({
  required String id,
  required double weightKg,
  required int stock,
  double price = 100.0,
}) =>
    {
      'id': id,
      'name': 'Test $id',
      'price': price,
      'stock': stock,
      'weightKg': weightKg,
    };

void main() {
  group('OrderProvider.validateOrder', () {
    test('rechaza cantidad cero', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 100),
        quantity: 0,
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('Cantidad'));
    });

    test('rechaza cantidad negativa', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 100),
        quantity: -1,
      );
      expect(v.ok, isFalse);
    });

    test('rechaza producto sin peso definido', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 0, stock: 100),
        quantity: 5,
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('peso'));
    });

    test('rechaza pedido por debajo del minimo (10kg < 100kg)', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 100),
        quantity: 1,
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('100'));
    });

    test('acepta pedido exacto al minimo (10kg x 10 = 100kg)', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 100),
        quantity: 10,
      );
      expect(v.ok, isTrue);
      expect(v.totalKg, 100.0);
    });

    test('acepta pedido por encima del minimo (15kg x 7 = 105kg)', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 15, stock: 100),
        quantity: 7,
      );
      expect(v.ok, isTrue);
      expect(v.totalKg, closeTo(105.0, 0.001));
    });

    test('rechaza pedido que excede capacidad de ruta (10kg x 600 = 6000kg > 5000kg)', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 1000),
        quantity: 600,
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('5000'));
    });

    test('acepta pedido en el limite superior de ruta (5000kg)', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 1000),
        quantity: 500,
      );
      expect(v.ok, isTrue);
      expect(v.totalKg, 5000.0);
    });

    test('rechaza pedido que excede stock disponible', () {
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 50),
        quantity: 100,
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('Stock'));
      expect(v.message, contains('50'));
    });

    test('prioridad: stock insuficiente se chequea antes de peso minimo', () {
      // 1 bolsa de 10kg con stock=0: falla por stock, no por peso
      final v = OrderProvider.validateOrder(
        product: _prod(id: 'P', weightKg: 10, stock: 0),
        quantity: 1,
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('Stock'));
    });

    group('Productos seed del backend', () {
      test('PROD-ICE-001 (10kg, stock 100): cantidad 10 → ok (100kg exacto)', () {
        final p = _prod(id: 'PROD-ICE-001', weightKg: 10, stock: 100);
        final v = OrderProvider.validateOrder(product: p, quantity: 10);
        expect(v.ok, isTrue);
        expect(v.totalKg, 100.0);
      });

      test('PROD-ICE-002 (5kg, stock 300): cantidad 20 → ok (100kg exacto)', () {
        final p = _prod(id: 'PROD-ICE-002', weightKg: 5, stock: 300);
        final v = OrderProvider.validateOrder(product: p, quantity: 20);
        expect(v.ok, isTrue);
        expect(v.totalKg, 100.0);
      });

      test('PROD-ICE-002 (5kg): cantidad 19 → rechazado (95kg < 100kg)', () {
        final p = _prod(id: 'PROD-ICE-002', weightKg: 5, stock: 300);
        final v = OrderProvider.validateOrder(product: p, quantity: 19);
        expect(v.ok, isFalse);
      });

      test('PROD-ICE-003 (10kg, stock 150): cantidad 7 → rechazado (70kg)', () {
        final p = _prod(id: 'PROD-ICE-003', weightKg: 10, stock: 150);
        final v = OrderProvider.validateOrder(product: p, quantity: 7);
        expect(v.ok, isFalse);
      });

      test('PROD-ICE-004 (15kg, stock 100): cantidad 7 → ok (105kg)', () {
        final p = _prod(id: 'PROD-ICE-004', weightKg: 15, stock: 100);
        final v = OrderProvider.validateOrder(product: p, quantity: 7);
        expect(v.ok, isTrue);
        expect(v.totalKg, closeTo(105.0, 0.001));
      });

      test('PROD-ICE-004 (15kg): 334 sacos = 5010kg → rechazado (ruta)', () {
        final p = _prod(id: 'PROD-ICE-004', weightKg: 15, stock: 1000);
        final v = OrderProvider.validateOrder(product: p, quantity: 334);
        expect(v.ok, isFalse);
        expect(v.message, contains('ruta'));
      });
    });
  });

  group('OrderProvider business constants', () {
    test('kMinOrderWeightKg es 100.0', () {
      expect(OrderProvider.kMinOrderWeightKg, 100.0);
    });

    test('kMaxRouteWeightKg es 5000.0', () {
      expect(OrderProvider.kMaxRouteWeightKg, 5000.0);
    });
  });
}
