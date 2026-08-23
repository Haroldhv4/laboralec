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
  double get indemnificationsTotal => desahucio + dismissalIndemnification;
  double get total => pendingSalary + benefitsTotal + indemnificationsTotal + otherIncome - deductions;
}

class CalculationEngine {
  const CalculationEngine([this.config = const LegalConfig()]);

  final LegalConfig config;

  double employeeIess(double taxableIncome) =>
      taxableIncome * config.employeeIessRate;

  double employerIess(double taxableIncome) =>
      taxableIncome * config.employerIessRate;

  double hourlyRate(double monthlySalary) => monthlySalary / config.monthlyHours;

  double supplementaryHour(double monthlySalary) =>
      hourlyRate(monthlySalary) * 1.5;

  double extraordinaryHour(double monthlySalary) =>
      hourlyRate(monthlySalary) * 2;

  double nightHourPremium(double monthlySalary) =>
      hourlyRate(monthlySalary) * config.nightPremiumRate;

  double thirteenthMonthly(double eligibleIncome) => eligibleIncome / 12;

  double fourteenthMonthly() => config.sbu / 12;

  double vacationMonthlyProvision(double monthlySalary) => monthlySalary / 24;

  double reserveFund(double taxableIncome) => taxableIncome * config.reserveFundRate;

  EmploymentCost employmentCost(
    double monthlySalary, {
    bool includeReserveFund = false,
  }) {
    final employer = employerIess(monthlySalary);
    final thirteenth = thirteenthMonthly(monthlySalary);
    final fourteenth = fourteenthMonthly();
    final vacations = vacationMonthlyProvision(monthlySalary);
    final reserve = includeReserveFund ? reserveFund(monthlySalary) : 0.0;
    return EmploymentCost(
      salary: monthlySalary,
      employerIess: employer,
      thirteenthProvision: thirteenth,
      fourteenthProvision: fourteenth,
      vacationProvision: vacations,
      reserveFund: reserve,
      total: monthlySalary + employer + thirteenth + fourteenth + vacations + reserve,
    );
  }

  int completedYears(DateTime start, DateTime end) {
    var years = end.year - start.year;
    final anniversaryPassed = end.month > start.month ||
        (end.month == start.month && end.day >= start.day);
    if (!anniversaryPassed) years--;
    return math.max(0, years);
  }

  int dismissalYears(DateTime start, DateTime end) {
    final completed = completedYears(start, end);
    final anniversary = DateTime(start.year + completed, start.month, start.day);
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
}
