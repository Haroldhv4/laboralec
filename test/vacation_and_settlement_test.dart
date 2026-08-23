import 'package:flutter_test/flutter_test.dart';
import 'package:laboral_ec/domain/calculation_engine.dart';

void main() {
  const engine = CalculationEngine();

  test('vacaciones usadas reducen el saldo estimado del periodo', () {
    final withoutTaken = engine.automaticSettlement(
      remunerationBase: 600,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 7, 1),
      cause: TerminationCause.resignation,
      region: EcuadorRegion.costaInsular,
      salaryCurrentMonthPaid: true,
    );

    final withTaken = engine.automaticSettlement(
      remunerationBase: 600,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 7, 1),
      cause: TerminationCause.resignation,
      region: EcuadorRegion.costaInsular,
      salaryCurrentMonthPaid: true,
      vacationDaysTakenInCurrentPeriod: 4,
    );

    expect(withTaken.vacationDays, lessThan(withoutTaken.vacationDays));
    expect(
      withoutTaken.vacationDays - withTaken.vacationDays,
      closeTo(4, 0.01),
    );
  });

  test('sueldo proporcional usa mes comercial de treinta días', () {
    final result = engine.automaticSettlement(
      remunerationBase: 900,
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 20),
      cause: TerminationCause.resignation,
      region: EcuadorRegion.sierraAmazonia,
      vacationDaysPending: 0,
    );

    expect(result.pendingSalaryDays, 11);
    expect(result.breakdown.pendingSalary, closeTo(330, 0.001));
  });
}
