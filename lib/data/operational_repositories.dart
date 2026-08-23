import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/calculation_engine.dart';
import 'models.dart';
import 'operational_models.dart';

class OvertimeRepository {
  OvertimeRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<OvertimeRecord>> listForEmployee(String employeeId) async {
    final rows = await _client
        .from('overtime_records')
        .select()
        .eq('employee_id', employeeId)
        .order('work_date', ascending: false);
    return (rows as List)
        .map((row) => OvertimeRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<OvertimeRecord> create({
    required EmployeeRecord record,
    required DateTime workDate,
    required double hours,
    required String type,
  }) async {
    final contract = record.contract;
    if (contract == null) throw StateError('El empleado no tiene contrato activo.');

    final engine = const CalculationEngine();
    final hourlyBase = engine.hourlyRate(contract.monthlySalary);
    final multiplier = switch (type) {
      'supplementary_50' => 1.5,
      'extraordinary_100' => 2.0,
      'night_25' => 0.25,
      _ => 1.0,
    };
    final amount = hourlyBase * multiplier * hours;

    final row = await _client
        .from('overtime_records')
        .insert({
          'company_id': record.employee.companyId,
          'employee_id': record.employee.id,
          'contract_id': contract.id,
          'work_date': _date(workDate),
          'hours': hours,
          'overtime_type': type,
          'hourly_base': hourlyBase,
          'multiplier': multiplier,
          'amount': amount,
          'status': 'approved',
          'calculation_snapshot': {
            'salary': contract.monthlySalary,
            'hourly_base': hourlyBase,
            'multiplier': multiplier,
          },
        })
        .select()
        .single();

    return OvertimeRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String id) async {
    await _client.from('overtime_records').delete().eq('id', id);
  }
}

class VacationRepository {
  VacationRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<VacationRecord>> listForEmployee(String employeeId) async {
    final rows = await _client
        .from('vacation_periods')
        .select()
        .eq('employee_id', employeeId)
        .order('period_start', ascending: false);
    return (rows as List)
        .map((row) => VacationRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<VacationRecord> registerTaken({
    required EmployeeRecord record,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final contract = record.contract;
    if (contract == null) throw StateError('El empleado no tiene contrato activo.');
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('La fecha final no puede ser anterior a la inicial.');
    }

    final days = endDate.difference(startDate).inDays + 1.0;
    final value = const CalculationEngine().vacationValue(
      contract.monthlySalary,
      days,
    );

    final row = await _client
        .from('vacation_periods')
        .insert({
          'company_id': record.employee.companyId,
          'employee_id': record.employee.id,
          'contract_id': contract.id,
          'period_start': _date(startDate),
          'period_end': _date(endDate),
          'earned_days': days,
          'taken_days': days,
          'paid_days': 0,
          'monetary_value': value,
          'calculation_snapshot': {
            'salary': contract.monthlySalary,
            'registered_as': 'taken_leave',
          },
        })
        .select()
        .single();

    return VacationRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<double> takenDaysInCurrentServicePeriod(
    EmploymentContract contract,
    DateTime until,
  ) async {
    final completed = const CalculationEngine().completedYears(
      contract.startDate,
      until,
    );
    var anniversary = DateTime(
      contract.startDate.year + completed,
      contract.startDate.month,
      contract.startDate.day,
    );
    if (anniversary.isAfter(until)) {
      anniversary = DateTime(
        contract.startDate.year + completed - 1,
        contract.startDate.month,
        contract.startDate.day,
      );
    }

    final rows = await _client
        .from('vacation_periods')
        .select('taken_days')
        .eq('contract_id', contract.id)
        .gte('period_start', _date(anniversary))
        .lte('period_start', _date(until));

    return (rows as List).fold<double>(
      0,
      (sum, row) => sum + _number((row as Map)['taken_days']),
    );
  }
}

class PayrollRepository {
  PayrollRepository([SupabaseClient? client])
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

      final overtimeRows = await _client
          .from('overtime_records')
          .select('id,amount,overtime_type,hours')
          .eq('employee_id', record.employee.id)
          .eq('status', 'approved')
          .gte('work_date', _date(periodStart))
          .lt('work_date', _date(nextMonth));

      final overtime = (overtimeRows as List).fold<double>(
        0,
        (sum, row) => sum + _number((row as Map)['amount']),
      );
      final baseSalary = contract.monthlySalary;
      final grossIncome = baseSalary + overtime;
      final personalIess = _engine.employeeIess(grossIncome);
      final employerIess = _engine.employerIess(grossIncome);
      final netPay = grossIncome - personalIess;
      final includeReserve =
          _engine.completedYears(contract.startDate, periodEnd) >= 1;
      final employerCost = _engine
          .employmentCost(
            grossIncome,
            includeReserveFund: includeReserve,
          )
          .total;

      final entryRow = await _client
          .from('payroll_entries')
          .insert({
            'payroll_period_id': period.id,
            'company_id': company.id,
            'employee_id': record.employee.id,
            'contract_id': contract.id,
            'base_salary': baseSalary,
            'gross_income': grossIncome,
            'employee_iess': personalIess,
            'other_deductions': 0,
            'net_pay': netPay,
            'employer_iess': employerIess,
            'employer_cost': employerCost,
            'calculation_snapshot': {
              'year': year,
              'month': month,
              'overtime': overtime,
              'reserve_fund_included': includeReserve,
            },
          })
          .select()
          .single();

      final entryId = entryRow['id'].toString();
      final items = <Map<String, dynamic>>[
        {
          'payroll_entry_id': entryId,
          'company_id': company.id,
          'code': 'salary',
          'label': 'Sueldo base',
          'item_type': 'income',
          'amount': baseSalary,
        },
        if (overtime > 0)
          {
            'payroll_entry_id': entryId,
            'company_id': company.id,
            'code': 'overtime',
            'label': 'Horas adicionales',
            'item_type': 'income',
            'amount': overtime,
          },
        {
          'payroll_entry_id': entryId,
          'company_id': company.id,
          'code': 'iess_personal',
          'label': 'Aporte personal IESS',
          'item_type': 'deduction',
          'amount': personalIess,
        },
        {
          'payroll_entry_id': entryId,
          'company_id': company.id,
          'code': 'iess_patronal',
          'label': 'Aporte patronal IESS',
          'item_type': 'employer_cost',
          'amount': employerIess,
        },
      ];
      await _client.from('payroll_items').insert(items);
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
}

class SettlementHistoryRepository {
  SettlementHistoryRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SettlementHistoryRecord>> list(String companyId) async {
    final rows = await _client
        .from('settlements')
        .select(
          '*,employees(first_names,last_names,identification_number),terminations(termination_date,cause_label)',
        )
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => SettlementHistoryRecord.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }
}

class ReminderRepository {
  ReminderRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ReminderRecord>> list(String companyId) async {
    try {
      final rows = await _client
          .from('reminders')
          .select()
          .eq('company_id', companyId)
          .neq('status', 'dismissed')
          .order('due_date');
      return (rows as List)
          .map((row) => ReminderRecord.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } on PostgrestException catch (error) {
      if (error.code == '42P01') return const [];
      rethrow;
    }
  }

  Future<void> create({
    required String companyId,
    required String title,
    required DateTime dueDate,
    String type = 'custom',
  }) async {
    await _client.from('reminders').insert({
      'company_id': companyId,
      'reminder_type': type,
      'title': title.trim(),
      'due_date': _date(dueDate),
      'status': 'pending',
    });
  }

  Future<void> setDone(String id, bool done) async {
    await _client
        .from('reminders')
        .update({'status': done ? 'done' : 'pending'})
        .eq('id', id);
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
