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

  group('Finiquito automático', () {
    test('calcula sueldo pendiente usando días del mes de salida', () {
      final estimate = engine.automaticSettlement(
        remunerationBase: 650,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2026, 8, 22),
        cause: TerminationCause.resignation,
        region: EcuadorRegion.costaInsular,
        vacationDaysPending: 0,
      );

      expect(estimate.pendingSalaryDays, 22);
      expect(
        estimate.breakdown.pendingSalary,
        closeTo(650 * 22 / 30, 0.0001),
      );
    });

    test('décimo tercero mensualizado calcula solo fracción del mes final', () {
      final estimate = engine.automaticSettlement(
        remunerationBase: 520,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2026, 2, 21),
        cause: TerminationCause.resignation,
        region: EcuadorRegion.costaInsular,
        thirteenthMonthlyized: true,
        salaryCurrentMonthPaid: true,
        vacationDaysPending: 0,
      );

      expect(estimate.thirteenthDays, 21);
      expect(
        estimate.breakdown.thirteenth,
        closeTo(520 * 21 / 360, 0.0001),
      );
    });

    test('décimo cuarto usa SBU 2026 y periodo regional', () {
      final estimate = engine.automaticSettlement(
        remunerationBase: 650,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 30),
        cause: TerminationCause.resignation,
        region: EcuadorRegion.costaInsular,
        salaryCurrentMonthPaid: true,
        vacationDaysPending: 0,
      );

      expect(estimate.sbuUsed, 482);
      expect(estimate.fourteenthDays, 30);
      expect(
        estimate.breakdown.fourteenth,
        closeTo(482 * 30 / 360, 0.0001),
      );
    });

    test('despido automático suma indemnización y desahucio cuando corresponde', () {
      final estimate = engine.automaticSettlement(
        remunerationBase: 650,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2026, 8, 22),
        cause: TerminationCause.unfairDismissal,
        region: EcuadorRegion.costaInsular,
        salaryCurrentMonthPaid: true,
        vacationDaysPending: 0,
      );

      expect(estimate.breakdown.dismissalIndemnification, 1950);
      expect(estimate.breakdown.desahucio, 162.5);
    });

    test('permite excluir sueldo del mes cuando ya fue pagado', () {
      final estimate = engine.automaticSettlement(
        remunerationBase: 650,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 8, 22),
        cause: TerminationCause.resignation,
        region: EcuadorRegion.sierraAmazonia,
        salaryCurrentMonthPaid: true,
        vacationDaysPending: 0,
      );

      expect(estimate.breakdown.pendingSalary, 0);
    });
  });
}
