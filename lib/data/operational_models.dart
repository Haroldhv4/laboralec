import '../core/formatters.dart';

class OvertimeRecord {
  const OvertimeRecord({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.contractId,
    required this.workDate,
    required this.hours,
    required this.type,
    required this.amount,
    required this.status,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String contractId;
  final DateTime workDate;
  final double hours;
  final String type;
  final double amount;
  final String status;

  String get typeLabel => switch (type) {
        'supplementary_50' => 'Suplementaria 50 %',
        'extraordinary_100' => 'Extraordinaria 100 %',
        'night_25' => 'Recargo nocturno 25 %',
        _ => type,
      };

  factory OvertimeRecord.fromMap(Map<String, dynamic> map) => OvertimeRecord(
        id: map['id'].toString(),
        companyId: map['company_id'].toString(),
        employeeId: map['employee_id'].toString(),
        contractId: map['contract_id'].toString(),
        workDate: parseDate(map['work_date']) ?? DateTime.now(),
        hours: asDouble(map['hours']),
        type: map['overtime_type']?.toString() ?? 'supplementary_50',
        amount: asDouble(map['amount']),
        status: map['status']?.toString() ?? 'pending',
      );
}

class VacationRecord {
  const VacationRecord({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.contractId,
    required this.startDate,
    required this.endDate,
    required this.earnedDays,
    required this.takenDays,
    required this.paidDays,
    required this.monetaryValue,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String contractId;
  final DateTime startDate;
  final DateTime endDate;
  final double earnedDays;
  final double takenDays;
  final double paidDays;
  final double monetaryValue;

  factory VacationRecord.fromMap(Map<String, dynamic> map) => VacationRecord(
        id: map['id'].toString(),
        companyId: map['company_id'].toString(),
        employeeId: map['employee_id'].toString(),
        contractId: map['contract_id'].toString(),
        startDate: parseDate(map['period_start']) ?? DateTime.now(),
        endDate: parseDate(map['period_end']) ?? DateTime.now(),
        earnedDays: asDouble(map['earned_days']),
        takenDays: asDouble(map['taken_days']),
        paidDays: asDouble(map['paid_days']),
        monetaryValue: asDouble(map['monetary_value']),
      );
}

class PayrollPeriodRecord {
  const PayrollPeriodRecord({
    required this.id,
    required this.companyId,
    required this.year,
    required this.month,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final int year;
  final int month;
  final String status;
  final DateTime createdAt;

  String get label => '${_monthName(month)} $year';

  factory PayrollPeriodRecord.fromMap(Map<String, dynamic> map) =>
      PayrollPeriodRecord(
        id: map['id'].toString(),
        companyId: map['company_id'].toString(),
        year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
        month: (map['month'] as num?)?.toInt() ?? DateTime.now().month,
        status: map['status']?.toString() ?? 'draft',
        createdAt: parseDate(map['created_at']) ?? DateTime.now(),
      );
}

class PayrollEntryRecord {
  const PayrollEntryRecord({
    required this.id,
    required this.payrollPeriodId,
    required this.companyId,
    required this.employeeId,
    required this.contractId,
    required this.employeeName,
    required this.identificationNumber,
    required this.position,
    required this.baseSalary,
    required this.grossIncome,
    required this.employeeIess,
    required this.otherDeductions,
    required this.netPay,
    required this.employerIess,
    required this.employerCost,
  });

  final String id;
  final String payrollPeriodId;
  final String companyId;
  final String employeeId;
  final String contractId;
  final String employeeName;
  final String identificationNumber;
  final String position;
  final double baseSalary;
  final double grossIncome;
  final double employeeIess;
  final double otherDeductions;
  final double netPay;
  final double employerIess;
  final double employerCost;

  factory PayrollEntryRecord.fromMap(Map<String, dynamic> map) {
    final employee = map['employees'] is Map
        ? Map<String, dynamic>.from(map['employees'] as Map)
        : const <String, dynamic>{};
    final contract = map['contracts'] is Map
        ? Map<String, dynamic>.from(map['contracts'] as Map)
        : const <String, dynamic>{};
    final first = employee['first_names']?.toString() ?? '';
    final last = employee['last_names']?.toString() ?? '';

    return PayrollEntryRecord(
      id: map['id'].toString(),
      payrollPeriodId: map['payroll_period_id'].toString(),
      companyId: map['company_id'].toString(),
      employeeId: map['employee_id'].toString(),
      contractId: map['contract_id'].toString(),
      employeeName: '$first $last'.trim(),
      identificationNumber:
          employee['identification_number']?.toString() ?? '',
      position: contract['position']?.toString() ?? 'Empleado',
      baseSalary: asDouble(map['base_salary']),
      grossIncome: asDouble(map['gross_income']),
      employeeIess: asDouble(map['employee_iess']),
      otherDeductions: asDouble(map['other_deductions']),
      netPay: asDouble(map['net_pay']),
      employerIess: asDouble(map['employer_iess']),
      employerCost: asDouble(map['employer_cost']),
    );
  }
}

class SettlementHistoryRecord {
  const SettlementHistoryRecord({
    required this.id,
    required this.employeeName,
    required this.identificationNumber,
    required this.terminationDate,
    required this.cause,
    required this.total,
    required this.status,
  });

  final String id;
  final String employeeName;
  final String identificationNumber;
  final DateTime terminationDate;
  final String cause;
  final double total;
  final String status;

  factory SettlementHistoryRecord.fromMap(Map<String, dynamic> map) {
    final employee = map['employees'] is Map
        ? Map<String, dynamic>.from(map['employees'] as Map)
        : const <String, dynamic>{};
    final termination = map['terminations'] is Map
        ? Map<String, dynamic>.from(map['terminations'] as Map)
        : const <String, dynamic>{};
    final first = employee['first_names']?.toString() ?? '';
    final last = employee['last_names']?.toString() ?? '';

    return SettlementHistoryRecord(
      id: map['id'].toString(),
      employeeName: '$first $last'.trim(),
      identificationNumber:
          employee['identification_number']?.toString() ?? '',
      terminationDate:
          parseDate(termination['termination_date']) ?? DateTime.now(),
      cause: termination['cause_label']?.toString() ?? 'Terminación',
      total: asDouble(map['total']),
      status: map['status']?.toString() ?? 'calculated',
    );
  }
}

class ReminderRecord {
  const ReminderRecord({
    required this.id,
    required this.companyId,
    required this.title,
    required this.type,
    required this.dueDate,
    required this.status,
    this.employeeId,
  });

  final String id;
  final String companyId;
  final String? employeeId;
  final String title;
  final String type;
  final DateTime dueDate;
  final String status;

  bool get completed => status == 'done';

  factory ReminderRecord.fromMap(Map<String, dynamic> map) => ReminderRecord(
        id: map['id'].toString(),
        companyId: map['company_id'].toString(),
        employeeId: map['employee_id']?.toString(),
        title: map['title']?.toString() ?? 'Recordatorio',
        type: map['reminder_type']?.toString() ?? 'custom',
        dueDate: parseDate(map['due_date']) ?? DateTime.now(),
        status: map['status']?.toString() ?? 'pending',
      );
}

String _monthName(int month) => const [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ][month.clamp(1, 12) - 1];
