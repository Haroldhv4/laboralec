import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/calculation_engine.dart';
import 'models.dart';
import 'operational_models.dart';

class PayrollRepositoryV2 {
  PayrollRepositoryV2([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final _engine = const CalculationEngine();

  Future<List<PayrollPeriodRecord>> listPeriods(String companyId) async {
    final rows = await _client
        .from('payroll_periods')
        .select()
        .eq('company_id', companyId)
        .order('year', ascending: false)
        .order('month', ascending: false);
    return (rows as List)
        .map((row) => PayrollPeriodRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<PayrollPeriodRecord> generate({
    required Company company,
    required List<EmployeeRecord> employees,
    required int year,
    required int month,
  }) async {
    final periodRow = await _client
        .from('payroll_periods')
        .upsert(
          {
            'company_id': company.id,
            'year': year,
            'month': month,
            'status': 'calculated',
            'calculated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'company_id,year,month',
        )
        .select()
        .single();

    final period = PayrollPeriodRecord.fromMap(
      Map<String, dynamic>.from(periodRow),
    );

    await _client
        .from('payroll_entries')
        .delete()
        .eq('payroll_period_id', period.id);

    final periodStart = DateTime(year, month, 1);
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    final periodEnd = nextMonth.subtract(const Duration(days: 1));

    for (final record in employees) {
      final contract = record.contract;
      if (contract == null || contract.startDate.isAfter(periodEnd)) continue;

      final employeeStart = contract.startDate.isAfter(periodStart)
          ? contract.startDate
          : periodStart;
      final workedDays = _engine
          .commercialDaysInclusive(employeeStart, periodEnd)
          .clamp(0, 30)
          .toInt();
      if (workedDays == 0) continue;

      final overtimeRows = await _client
          .from('overtime_records')
          .select('id,amount,overtime_type,hours')
          .eq('employee_id', record.employee.id)
          .inFilter('status', ['approved', 'paid'])
          .gte('work_date', _date(periodStart))
          .lt('work_date', _date(nextMonth));

      final overtime = (overtimeRows as List).fold<double>(
        0,
        (sum, row) => sum + _number((row as Map)['amount']),
      );

      final baseSalary = contract.monthlySalary * workedDays / 30;
      final taxableBase = baseSalary + overtime;
      final personalIess = _engine.employeeIess(taxableBase);
      final employerIess = _engine.employerIess(taxableBase);

      final thirteenthProvision = _engine.thirteenthMonthly(taxableBase);
      final thirteenthPaid = contract.thirteenthPaymentMode == 'monthly'
          ? thirteenthProvision
          : 0.0;

      final fourteenthProvision =
          _engine.sbuForYear(year) / 12 * workedDays / 30;
      final fourteenthPaid = contract.fourteenthPaymentMode == 'monthly'
          ? fourteenthProvision
          : 0.0;

      final reserveEligible =
          _engine.completedYears(contract.startDate, periodEnd) >= 1;
      final reserveProvision = reserveEligible
          ? _engine.reserveFund(taxableBase)
          : 0.0;
      final reservePaid = reserveEligible &&
              contract.reserveFundPaymentMode == 'monthly'
          ? reserveProvision
          : 0.0;

      final vacationProvision = taxableBase / 24;
      final totalIncome = taxableBase +
          thirteenthPaid +
          fourteenthPaid +
          reservePaid;
      final netPay = totalIncome - personalIess;
      final employerCost = taxableBase +
          employerIess +
          thirteenthProvision +
          fourteenthProvision +
          vacationProvision +
          reserveProvision;

      final entryRow = await _client
          .from('payroll_entries')
          .insert({
            'payroll_period_id': period.id,
            'company_id': company.id,
            'employee_id': record.employee.id,
            'contract_id': contract.id,
            'base_salary': baseSalary,
            'gross_income': totalIncome,
            'employee_iess': personalIess,
            'other_deductions': 0,
            'net_pay': netPay,
            'employer_iess': employerIess,
            'employer_cost': employerCost,
            'calculation_snapshot': {
              'engine_version': '2026.2',
              'year': year,
              'month': month,
              'worked_days': workedDays,
              'contract_salary': contract.monthlySalary,
              'base_salary': baseSalary,
              'overtime': overtime,
              'taxable_base': taxableBase,
              'thirteenth_paid': thirteenthPaid,
              'fourteenth_paid': fourteenthPaid,
              'reserve_paid': reservePaid,
              'vacation_provision': vacationProvision,
              'reserve_eligible': reserveEligible,
            },
          })
          .select()
          .single();

      final entryId = entryRow['id'].toString();
      final items = <Map<String, dynamic>>[
        _item(entryId, company.id, 'salary', 'Sueldo base', 'income', baseSalary),
        if (overtime > 0)
          _item(entryId, company.id, 'overtime', 'Horas adicionales', 'income', overtime),
        if (thirteenthPaid > 0)
          _item(entryId, company.id, 'thirteenth', 'Décimo tercero mensualizado', 'income', thirteenthPaid),
        if (fourteenthPaid > 0)
          _item(entryId, company.id, 'fourteenth', 'Décimo cuarto mensualizado', 'income', fourteenthPaid),
        if (reservePaid > 0)
          _item(entryId, company.id, 'reserve_fund', 'Fondo de reserva mensual', 'income', reservePaid),
        _item(entryId, company.id, 'iess_personal', 'Aporte personal IESS', 'deduction', personalIess),
        _item(entryId, company.id, 'iess_patronal', 'Aporte patronal IESS', 'employer_cost', employerIess),
        _item(entryId, company.id, 'vacation_provision', 'Provisión de vacaciones', 'provision', vacationProvision),
        if (contract.thirteenthPaymentMode != 'monthly')
          _item(entryId, company.id, 'thirteenth_provision', 'Provisión décimo tercero', 'provision', thirteenthProvision),
        if (contract.fourteenthPaymentMode != 'monthly')
          _item(entryId, company.id, 'fourteenth_provision', 'Provisión décimo cuarto', 'provision', fourteenthProvision),
        if (reserveEligible && contract.reserveFundPaymentMode != 'monthly')
          _item(entryId, company.id, 'reserve_provision', 'Fondo de reserva a IESS', 'provision', reserveProvision),
      ];
      await _client.from('payroll_items').insert(items);

      final overtimeIds = (overtimeRows as List)
          .map((row) => (row as Map)['id']?.toString())
          .whereType<String>()
          .toList();
      if (overtimeIds.isNotEmpty) {
        await _client
            .from('overtime_records')
            .update({'status': 'paid'})
            .inFilter('id', overtimeIds);
      }
    }

    return period;
  }

  Future<List<PayrollEntryRecord>> listEntries(String periodId) async {
    final rows = await _client
        .from('payroll_entries')
        .select(
          '*,employees(first_names,last_names,identification_number),contracts(position)',
        )
        .eq('payroll_period_id', periodId)
        .order('created_at');
    return (rows as List)
        .map((row) => PayrollEntryRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Map<String, dynamic> _item(
    String entryId,
    String companyId,
    String code,
    String label,
    String type,
    double amount,
  ) =>
      {
        'payroll_entry_id': entryId,
        'company_id': companyId,
        'code': code,
        'label': label,
        'item_type': type,
        'amount': amount,
      };

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
