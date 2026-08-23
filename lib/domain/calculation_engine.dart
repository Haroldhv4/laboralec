import 'dart:math' as math;

class LegalConfig {
  const LegalConfig({
    this.sbu = 482,
    this.employeeIessRate = 0.0945,
    this.employerIessRate = 0.1115,
    this.reserveFundRate = 0.0833,
    this.monthlyHours = 240,
    this.nightPremiumRate = 0.25,
  });

  final double sbu;
  final double employeeIessRate;
  final double employerIessRate;
  final double reserveFundRate;
  final double monthlyHours;
  final double nightPremiumRate;
}

class EmploymentCost {
  const EmploymentCost({
    required this.salary,
    required this.employerIess,
    required this.thirteenthProvision,
    required this.fourteenthProvision,
    required this.vacationProvision,
    required this.reserveFund,
    required this.total,
  });

  final double salary;
  final double employerIess;
  final double thirteenthProvision;
  final double fourteenthProvision;
  final double vacationProvision;
  final double reserveFund;
  final double total;
}

enum TerminationCause {
  resignation,
  desahucio,
  mutualAgreement,
  unfairDismissal,
  contractEnd,
}

enum EcuadorRegion {
  costaInsular,
  sierraAmazonia,
}

class SettlementBreakdown {
  const SettlementBreakdown({
    required this.pendingSalary,
    required this.thirteenth,
    required this.fourteenth,
    required this.vacations,
    required this.reserveFund,
    required this.desahucio,
    required this.dismissalIndemnification,
    required this.otherIncome,
    required this.deductions,
  });

  final double pendingSalary;
  final double thirteenth;
  final double fourteenth;
  final double vacations;
  final double reserveFund;
  final double desahucio;
  final double dismissalIndemnification;
  final double otherIncome;
  final double deductions;

  double get benefitsTotal =>
      thirteenth + fourteenth + vacations + reserveFund;
  double get indemnificationsTotal =>
      desahucio + dismissalIndemnification;
  double get total =>
      pendingSalary +
      benefitsTotal +
      indemnificationsTotal +
      otherIncome -
      deductions;
}

class SettlementEstimate {
  const SettlementEstimate({
    required this.breakdown,
    required this.pendingSalaryDays,
    required this.thirteenthDays,
    required this.fourteenthDays,
    required this.vacationDays,
    required this.completedServiceYears,
    required this.dismissalServiceYears,
    required this.sbuUsed,
    required this.notes,
  });

  final SettlementBreakdown breakdown;
  final int pendingSalaryDays;
  final int thirteenthDays;
  final int fourteenthDays;
  final double vacationDays;
  final int completedServiceYears;
  final int dismissalServiceYears;
  final double sbuUsed;
  final List<String> notes;
}

class CalculationEngine {
  const CalculationEngine([this.config = const LegalConfig()]);

  final LegalConfig config;

  double employeeIess(double taxableIncome) =>
      taxableIncome * config.employeeIessRate;

  double employerIess(double taxableIncome) =>
      taxableIncome * config.employerIessRate;

  double hourlyRate(double monthlySalary) =>
      monthlySalary / config.monthlyHours;

  double supplementaryHour(double monthlySalary) =>
      hourlyRate(monthlySalary) * 1.5;

  double extraordinaryHour(double monthlySalary) =>
      hourlyRate(monthlySalary) * 2;

  double nightHourPremium(double monthlySalary) =>
      hourlyRate(monthlySalary) * config.nightPremiumRate;

  double thirteenthMonthly(double eligibleIncome) => eligibleIncome / 12;

  double fourteenthMonthly({double? sbu}) => (sbu ?? config.sbu) / 12;

  double vacationMonthlyProvision(double monthlySalary) =>
      monthlySalary / 24;

  double reserveFund(double taxableIncome) =>
      taxableIncome * config.reserveFundRate;

  double vacationValue(double monthlySalary, double pendingDays) =>
      (monthlySalary / 30) * math.max(0, pendingDays);

  double sbuForYear(int year) => switch (year) {
        2024 => 460,
        2025 => 470,
        2026 => 482,
        _ => config.sbu,
      };

  EmploymentCost employmentCost(
    double monthlySalary, {
    bool includeReserveFund = false,
  }) {
    final employer = employerIess(monthlySalary);
    final thirteenth = thirteenthMonthly(monthlySalary);
    final fourteenth = fourteenthMonthly();
    final vacations = vacationMonthlyProvision(monthlySalary);
    final reserve =
        includeReserveFund ? reserveFund(monthlySalary) : 0.0;

    return EmploymentCost(
      salary: monthlySalary,
      employerIess: employer,
      thirteenthProvision: thirteenth,
      fourteenthProvision: fourteenth,
      vacationProvision: vacations,
      reserveFund: reserve,
      total:
          monthlySalary + employer + thirteenth + fourteenth + vacations + reserve,
    );
  }

  int completedYears(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    var years = end.year - start.year;
    final anniversaryPassed =
        end.month > start.month ||
        (end.month == start.month && end.day >= start.day);
    if (!anniversaryPassed) years--;
    return math.max(0, years);
  }

  int dismissalYears(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    final completed = completedYears(start, end);
    final anniversary = DateTime(
      start.year + completed,
      start.month,
      start.day,
    );
    final hasFraction = end.isAfter(anniversary);
    return completed + (hasFraction ? 1 : 0);
  }

  double desahucio(
    double lastRemuneration,
    DateTime start,
    DateTime end,
  ) {
    final years = completedYears(start, end);
    return lastRemuneration * 0.25 * years;
  }

  double unfairDismissal(
    double remunerationBase,
    DateTime start,
    DateTime end,
  ) {
    final exactYears = completedYears(start, end);
    if (exactYears < 3) return remunerationBase * 3;
    final years = dismissalYears(start, end);
    return remunerationBase * math.min(years, 25);
  }

  int commercialDaysInclusive(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    final startDay = math.min(start.day, 30);
    final endDay = math.min(end.day, 30);
    final days =
        (end.year - start.year) * 360 +
        (end.month - start.month) * 30 +
        (endDay - startDay) +
        1;
    return math.max(0, days);
  }

  DateTime thirteenthPeriodStart(DateTime end) {
    if (end.month == 12) return DateTime(end.year, 12, 1);
    return DateTime(end.year - 1, 12, 1);
  }

  DateTime fourteenthPeriodStart(
    DateTime end,
    EcuadorRegion region,
  ) {
    final cycleMonth =
        region == EcuadorRegion.sierraAmazonia ? 8 : 3;
    final thisYearStart = DateTime(end.year, cycleMonth, 1);
    return end.isBefore(thisYearStart)
        ? DateTime(end.year - 1, cycleMonth, 1)
        : thisYearStart;
  }

  double estimatedVacationDays(
    DateTime start,
    DateTime end, {
    double alreadyTakenInCurrentPeriod = 0,
  }) {
    if (end.isBefore(start)) return 0;

    final completed = completedYears(start, end);
    var periodStart = DateTime(
      start.year + completed,
      start.month,
      start.day,
    );

    if (_sameDate(periodStart, end) && completed > 0) {
      periodStart = DateTime(
        start.year + completed - 1,
        start.month,
        start.day,
      );
    }

    if (periodStart.isBefore(start)) periodStart = start;

    final daysInPeriod =
        commercialDaysInclusive(periodStart, end).clamp(0, 360).toInt();

    final completedAtPeriodStart =
        completedYears(start, periodStart);
    final additionalDays =
        math.min(math.max(completedAtPeriodStart - 5, 0), 15);
    final annualEntitlement = 15.0 + additionalDays;

    final accrued = annualEntitlement * daysInPeriod / 360;
    return math.max(0, accrued - alreadyTakenInCurrentPeriod);
  }

  SettlementEstimate automaticSettlement({
    required double remunerationBase,
    required DateTime startDate,
    required DateTime endDate,
    required TerminationCause cause,
    required EcuadorRegion region,
    bool thirteenthMonthlyized = false,
    bool fourteenthMonthlyized = false,
    bool salaryCurrentMonthPaid = false,
    double? vacationDaysPending,
    double vacationDaysTakenInCurrentPeriod = 0,
    bool includeCurrentReserveFund = false,
    double otherIncome = 0,
    double deductions = 0,
  }) {
    final notes = <String>[];

    if (endDate.isBefore(startDate)) {
      notes.add(
        'La fecha de terminación no puede ser anterior a la fecha de ingreso.',
      );
      return SettlementEstimate(
        breakdown: const SettlementBreakdown(
          pendingSalary: 0,
          thirteenth: 0,
          fourteenth: 0,
          vacations: 0,
          reserveFund: 0,
          desahucio: 0,
          dismissalIndemnification: 0,
          otherIncome: 0,
          deductions: 0,
        ),
        pendingSalaryDays: 0,
        thirteenthDays: 0,
        fourteenthDays: 0,
        vacationDays: 0,
        completedServiceYears: 0,
        dismissalServiceYears: 0,
        sbuUsed: sbuForYear(endDate.year),
        notes: notes,
      );
    }

    final monthStart = DateTime(endDate.year, endDate.month, 1);
    final salaryPeriodStart = _later(startDate, monthStart);
    final pendingSalaryDays =
        commercialDaysInclusive(salaryPeriodStart, endDate)
            .clamp(0, 30)
            .toInt();
    final pendingSalary = salaryCurrentMonthPaid
        ? 0.0
        : remunerationBase * pendingSalaryDays / 30;

    final thirteenthBaseStart = thirteenthMonthlyized
        ? monthStart
        : thirteenthPeriodStart(endDate);
    final thirteenthStart = _later(startDate, thirteenthBaseStart);
    final thirteenthDays =
        commercialDaysInclusive(thirteenthStart, endDate)
            .clamp(0, 360)
            .toInt();
    final thirteenth = remunerationBase * thirteenthDays / 360;

    final fourteenthBaseStart = fourteenthMonthlyized
        ? monthStart
        : fourteenthPeriodStart(endDate, region);
    final fourteenthStart = _later(startDate, fourteenthBaseStart);
    final fourteenthDays =
        commercialDaysInclusive(fourteenthStart, endDate)
            .clamp(0, 360)
            .toInt();
    final sbu = sbuForYear(endDate.year);
    final fourteenth = sbu * fourteenthDays / 360;

    final autoVacationDays = estimatedVacationDays(
      startDate,
      endDate,
      alreadyTakenInCurrentPeriod:
          vacationDaysTakenInCurrentPeriod,
    );
    final vacationDays =
        math.max(0, vacationDaysPending ?? autoVacationDays);
    final vacations = vacationValue(
      remunerationBase,
      vacationDays,
    );

    final completedService = completedYears(startDate, endDate);
    final reserveEligible = completedService >= 1;
    final reserveFundPending =
        includeCurrentReserveFund && reserveEligible
        ? reserveFund(
            remunerationBase * pendingSalaryDays / 30,
          )
        : 0.0;

    var desahucioAmount = 0.0;
    var dismissal = 0.0;

    if (cause == TerminationCause.desahucio ||
        cause == TerminationCause.unfairDismissal) {
      desahucioAmount = desahucio(
        remunerationBase,
        startDate,
        endDate,
      );
    }

    if (cause == TerminationCause.unfairDismissal) {
      dismissal = unfairDismissal(
        remunerationBase,
        startDate,
        endDate,
      );
    }

    if (vacationDaysPending == null) {
      notes.add(
        'Vacaciones estimadas suponiendo que no existen días pendientes de periodos anteriores. Ajusta los días si el trabajador ya tomó vacaciones o acumula saldos.',
      );
    }

    if (endDate.year < 2024 || endDate.year > 2026) {
      notes.add(
        'El SBU histórico de ${endDate.year} debe verificarse antes de usar este cálculo como definitivo.',
      );
    }

    if (thirteenthMonthlyized || fourteenthMonthlyized) {
      notes.add(
        'Los décimos mensualizados se estiman únicamente por la fracción pendiente del mes de salida.',
      );
    }

    notes.add(
      'El cálculo usa la última remuneración ingresada. Si hubo cambios de sueldo, comisiones u otros ingresos habituales, revisa el resultado.',
    );

    return SettlementEstimate(
      breakdown: SettlementBreakdown(
        pendingSalary: pendingSalary,
        thirteenth: thirteenth,
        fourteenth: fourteenth,
        vacations: vacations,
        reserveFund: reserveFundPending,
        desahucio: desahucioAmount,
        dismissalIndemnification: dismissal,
        otherIncome: math.max(0, otherIncome),
        deductions: math.max(0, deductions),
      ),
      pendingSalaryDays: pendingSalaryDays,
      thirteenthDays: thirteenthDays,
      fourteenthDays: fourteenthDays,
      vacationDays: vacationDays,
      completedServiceYears: completedService,
      dismissalServiceYears: dismissalYears(startDate, endDate),
      sbuUsed: sbu,
      notes: notes,
    );
  }

  SettlementBreakdown settlement({
    required double remunerationBase,
    required DateTime startDate,
    required DateTime endDate,
    required TerminationCause cause,
    double pendingSalary = 0,
    double thirteenth = 0,
    double fourteenth = 0,
    double vacations = 0,
    double reserveFundPending = 0,
    double otherIncome = 0,
    double deductions = 0,
  }) {
    var desahucioAmount = 0.0;
    var dismissal = 0.0;

    if (cause == TerminationCause.desahucio ||
        cause == TerminationCause.unfairDismissal) {
      desahucioAmount = desahucio(
        remunerationBase,
        startDate,
        endDate,
      );
    }

    if (cause == TerminationCause.unfairDismissal) {
      dismissal = unfairDismissal(
        remunerationBase,
        startDate,
        endDate,
      );
    }

    return SettlementBreakdown(
      pendingSalary: pendingSalary,
      thirteenth: thirteenth,
      fourteenth: fourteenth,
      vacations: vacations,
      reserveFund: reserveFundPending,
      desahucio: desahucioAmount,
      dismissalIndemnification: dismissal,
      otherIncome: otherIncome,
      deductions: deductions,
    );
  }

  DateTime _later(DateTime a, DateTime b) =>
      a.isAfter(b) ? a : b;

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
