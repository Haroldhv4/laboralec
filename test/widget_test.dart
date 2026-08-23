import 'package:flutter_test/flutter_test.dart';
import 'package:laboral_ec/domain/calculation_engine.dart';

void main() {
  const engine = CalculationEngine();

  group('Motor laboral 2026', () {
    test('IESS personal sobre 650', () {
      expect(engine.employeeIess(650), closeTo(61.425, 0.0001));
    });

    test('IESS patronal sobre 650', () {
      expect(engine.employerIess(650), closeTo(72.475, 0.0001));
    });

    test('décimo tercero mensual simple', () {
      expect(engine.thirteenthMonthly(650), closeTo(54.1666667, 0.0001));
    });

    test('décimo cuarto con SBU 482', () {
      expect(engine.fourteenthMonthly(), closeTo(40.1666667, 0.0001));
    });

    test('hora suplementaria y extraordinaria', () {
      expect(engine.supplementaryHour(650), closeTo(4.0625, 0.0001));
      expect(engine.extraordinaryHour(650), closeTo(5.4166667, 0.0001));
    });

    test('fondo de reserva', () {
      expect(engine.reserveFund(650), closeTo(54.145, 0.0001));
    });

    test('despido hasta tres años usa tres remuneraciones', () {
      final value = engine.unfairDismissal(
        650,
        DateTime(2025, 1, 1),
        DateTime(2026, 8, 22),
      );
      expect(value, 1950);
    });

    test('fracción posterior a tres años cuenta como año', () {
      final value = engine.unfairDismissal(
        650,
        DateTime(2023, 1, 1),
        DateTime(2026, 1, 2),
      );
      expect(value, 2600);
    });

    test('despido tiene tope de 25 remuneraciones', () {
      final value = engine.unfairDismissal(
        650,
        DateTime(1990, 1, 1),
        DateTime(2026, 1, 2),
      );
      expect(value, 16250);
    });
  });
}
