import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import '../domain/calculation_engine.dart';

class CompanyRepository {
  CompanyRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Company>> listCompanies() async {
    final rows = await _client.from('companies').select().order('created_at');
    return (rows as List)
        .map((row) => Company.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Company> createCompany({
    required String legalName,
    String? tradeName,
    String? ruc,
    String? province,
    String? city,
    String? region,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No existe una sesión activa.');

    final row = await _client
        .from('companies')
        .insert({
          'owner_id': user.id,
          'legal_name': legalName.trim(),
          'trade_name': _nullIfEmpty(tradeName),
          'ruc': _nullIfEmpty(ruc),
          'province': _nullIfEmpty(province),
          'city': _nullIfEmpty(city),
          'region': _nullIfEmpty(region),
        })
        .select()
        .single();

    return Company.fromMap(Map<String, dynamic>.from(row));
  }

  String? _nullIfEmpty(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }
}

class EmployeeRepository {
  EmployeeRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Employee>> listEmployees(String companyId) async {
    final rows = await _client
        .from('employees')
        .select()
        .eq('company_id', companyId)
        .order('last_names');

    return (rows as List)
        .map((row) => Employee.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<EmploymentContract?> activeContract(String employeeId) async {
    final row = await _client
        .from('contracts')
        .select()
        .eq('employee_id', employeeId)
        .order('start_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return EmploymentContract.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<EmployeeRecord>> listEmployeeRecords(String companyId) async {
    final employees = await listEmployees(companyId);
    final contractRows = await _client
        .from('contracts')
        .select()
        .eq('company_id', companyId)
        .order('start_date', ascending: false);

    final contracts = (contractRows as List)
        .map((row) => EmploymentContract.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    final byEmployee = <String, EmploymentContract>{};
    for (final contract in contracts) {
      byEmployee.putIfAbsent(contract.employeeId, () => contract);
    }

    return employees
        .map((employee) => EmployeeRecord(
              employee: employee,
              contract: byEmployee[employee.id],
            ))
        .toList();
  }

  Future<EmployeeRecord> createEmployee({
    required String companyId,
    required String identificationNumber,
    required String firstNames,
    required String lastNames,
    required String position,
    required double monthlySalary,
    required DateTime startDate,
    double weeklyHours = 40,
    String? email,
    String? phone,
    String thirteenthPaymentMode = 'monthly',
    String fourteenthPaymentMode = 'monthly',
    String reserveFundPaymentMode = 'iess',
  }) async {
    final employeeRow = await _client
        .from('employees')
        .insert({
          'company_id': companyId,
          'identification_type': 'cedula',
          'identification_number': identificationNumber.trim(),
          'first_names': firstNames.trim(),
          'last_names': lastNames.trim(),
          'email': _nullIfEmpty(email),
          'phone': _nullIfEmpty(phone),
          'status': 'active',
        })
        .select()
        .single();

    final employee = Employee.fromMap(Map<String, dynamic>.from(employeeRow));

    try {
      final contractRow = await _client
          .from('contracts')
          .insert({
            'employee_id': employee.id,
            'company_id': companyId,
            'contract_type': 'indefinite',
            'position': position.trim(),
            'start_date': _date(startDate),
            'monthly_salary': monthlySalary,
            'workday_type': weeklyHours < 40 ? 'part_time' : 'full_time',
            'weekly_hours': weeklyHours,
            'thirteenth_payment_mode': thirteenthPaymentMode,
            'fourteenth_payment_mode': fourteenthPaymentMode,
            'reserve_fund_payment_mode': reserveFundPaymentMode,
            'status': 'active',
          })
          .select()
          .single();

      final contract =
          EmploymentContract.fromMap(Map<String, dynamic>.from(contractRow));

      await _client.from('salary_history').insert({
        'contract_id': contract.id,
        'company_id': companyId,
        'amount': monthlySalary,
        'effective_from': _date(startDate),
      });

      final recentLimit = DateTime.now().subtract(const Duration(days: 30));
      if (!startDate.isBefore(recentLimit)) {
        await _tryReminder(
          companyId: companyId,
          employeeId: employee.id,
          type: 'iess_entry_notice',
          title: 'Registrar aviso de entrada IESS · ${employee.fullName}',
          dueDate: startDate.add(const Duration(days: 15)),
        );
      }

      return EmployeeRecord(employee: employee, contract: contract);
    } catch (_) {
      await _client.from('employees').delete().eq('id', employee.id);
      rethrow;
    }
  }

  Future<void> _tryReminder({
    required String companyId,
    required String employeeId,
    required String type,
    required String title,
    required DateTime dueDate,
  }) async {
    try {
      await _client.from('reminders').insert({
        'company_id': companyId,
        'employee_id': employeeId,
        'reminder_type': type,
        'title': title,
        'due_date': _date(dueDate),
        'status': 'pending',
      });
    } on PostgrestException catch (error) {
      if (error.code != '42P01') rethrow;
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String? _nullIfEmpty(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }
}

class SettlementRepository {
  SettlementRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> saveDraft({
    required EmployeeRecord record,
    required DateTime terminationDate,
    required TerminationCause cause,
    required SettlementBreakdown breakdown,
  }) async {
    final contract = record.contract;
    if (contract == null) throw StateError('El empleado no tiene contrato.');

    final termination = await _client
        .from('terminations')
        .insert({
          'company_id': record.employee.companyId,
          'employee_id': record.employee.id,
          'contract_id': contract.id,
          'termination_date': _date(terminationDate),
          'cause_code': cause.name,
          'cause_label': _causeLabel(cause),
          'status': 'calculated',
        })
        .select()
        .single();

    try {
      final settlement = await _client
          .from('settlements')
          .insert({
            'company_id': record.employee.companyId,
            'termination_id': termination['id'],
            'employee_id': record.employee.id,
            'contract_id': contract.id,
            'calculation_date': _date(DateTime.now()),
            'income_total': breakdown.pendingSalary + breakdown.otherIncome,
            'benefits_total': breakdown.benefitsTotal,
            'indemnifications_total': breakdown.indemnificationsTotal,
            'deductions_total': breakdown.deductions,
            'total': breakdown.total,
            'status': 'calculated',
            'legal_engine_version': '2026.2',
            'warnings': <String>[
              'Resultado estimado. Verifica remuneraciones variables, saldos históricos y la causal antes de finalizar.',
            ],
            'calculation_snapshot': {
              'salary': contract.monthlySalary,
              'start_date': _date(contract.startDate),
              'termination_date': _date(terminationDate),
              'cause': cause.name,
              'pending_salary': breakdown.pendingSalary,
              'thirteenth': breakdown.thirteenth,
              'fourteenth': breakdown.fourteenth,
              'vacations': breakdown.vacations,
              'reserve_fund': breakdown.reserveFund,
              'desahucio': breakdown.desahucio,
              'dismissal': breakdown.dismissalIndemnification,
              'other_income': breakdown.otherIncome,
              'deductions': breakdown.deductions,
              'total': breakdown.total,
            },
          })
          .select()
          .single();

      final settlementId = settlement['id'].toString();
      final items = <Map<String, dynamic>>[];
      void addItem(String code, String label, String category, double amount) {
        if (amount == 0) return;
        items.add({
          'settlement_id': settlementId,
          'company_id': record.employee.companyId,
          'code': code,
          'label': label,
          'category': category,
          'amount': amount,
        });
      }

      addItem('pending_salary', 'Remuneración pendiente', 'income', breakdown.pendingSalary);
      addItem('thirteenth', 'Décimo tercero', 'benefit', breakdown.thirteenth);
      addItem('fourteenth', 'Décimo cuarto', 'benefit', breakdown.fourteenth);
      addItem('vacations', 'Vacaciones', 'benefit', breakdown.vacations);
      addItem('reserve_fund', 'Fondo de reserva', 'benefit', breakdown.reserveFund);
      addItem('desahucio', 'Bonificación por desahucio', 'indemnification', breakdown.desahucio);
      addItem('dismissal', 'Indemnización por despido', 'indemnification', breakdown.dismissalIndemnification);
      addItem('other_income', 'Otros ingresos', 'income', breakdown.otherIncome);
      addItem('deductions', 'Descuentos', 'deduction', breakdown.deductions);

      if (items.isNotEmpty) {
        await _client.from('settlement_items').insert(items);
      }

      await _tryReminder(
        companyId: record.employee.companyId,
        employeeId: record.employee.id,
        type: 'iess_exit_notice',
        title: 'Registrar aviso de salida IESS · ${record.employee.fullName}',
        dueDate: terminationDate.add(const Duration(days: 3)),
      );
      await _tryReminder(
        companyId: record.employee.companyId,
        employeeId: record.employee.id,
        type: 'sut_settlement',
        title: 'Registrar acta de finiquito en SUT · ${record.employee.fullName}',
        dueDate: terminationDate.add(const Duration(days: 15)),
      );
    } catch (_) {
      await _client.from('terminations').delete().eq('id', termination['id']);
      rethrow;
    }
  }

  Future<void> _tryReminder({
    required String companyId,
    required String employeeId,
    required String type,
    required String title,
    required DateTime dueDate,
  }) async {
    try {
      await _client.from('reminders').insert({
        'company_id': companyId,
        'employee_id': employeeId,
        'reminder_type': type,
        'title': title,
        'due_date': _date(dueDate),
        'status': 'pending',
      });
    } on PostgrestException catch (error) {
      if (error.code != '42P01') rethrow;
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _causeLabel(TerminationCause cause) => switch (cause) {
        TerminationCause.resignation => 'Renuncia',
        TerminationCause.desahucio => 'Desahucio',
        TerminationCause.mutualAgreement => 'Mutuo acuerdo',
        TerminationCause.unfairDismissal => 'Despido intempestivo',
        TerminationCause.contractEnd => 'Fin de contrato',
      };
}
