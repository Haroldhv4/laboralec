import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../domain/calculation_engine.dart';
import '../employees/employees_page.dart';

class CompanyDashboardPage extends StatefulWidget {
  const CompanyDashboardPage({super.key, required this.company});
  final Company company;

  @override
  State<CompanyDashboardPage> createState() => _CompanyDashboardPageState();
}

class _CompanyDashboardPageState extends State<CompanyDashboardPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewTab(company: widget.company, onOpenEmployees: () => setState(() => _index = 1)),
      EmployeesPage(company: widget.company),
      _PayrollTab(company: widget.company),
      _SettlementTab(company: widget.company),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.company.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text('Gestión laboral', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Empleados'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Nómina'),
          NavigationDestination(icon: Icon(Icons.assignment_turned_in_outlined), selectedIcon: Icon(Icons.assignment_turned_in), label: 'Finiquito'),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.company, required this.onOpenEmployees});
  final Company company;
  final VoidCallback onOpenEmployees;

  @override
  Widget build(BuildContext context) {
    final engine = const CalculationEngine();
    return FutureBuilder<List<EmployeeRecord>>(
      future: EmployeeRepository().listEmployeeRecords(company.id),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <EmployeeRecord>[];
        final active = records.where((r) => r.contract != null).toList();
        final salaries = active.fold<double>(0, (sum, r) => sum + r.contract!.monthlySalary);
        final estimatedCost = active.fold<double>(
          0,
          (sum, r) => sum + engine.employmentCost(r.contract!.monthlySalary, includeReserveFund: true).total,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Resumen', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              [
                if (company.ruc?.isNotEmpty ?? false) 'RUC ${company.ruc}',
                if (company.city?.isNotEmpty ?? false) company.city!,
              ].join(' · ').isEmpty
                  ? 'Información general de tu empresa'
                  : [
                      if (company.ruc?.isNotEmpty ?? false) 'RUC ${company.ruc}',
                      if (company.city?.isNotEmpty ?? false) company.city!,
                    ].join(' · '),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _MetricCard(label: 'Empleados', value: '${records.length}', icon: Icons.groups_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(label: 'Sueldos', value: money(salaries), icon: Icons.payments_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            _MetricCard(label: 'Costo laboral mensual estimado', value: money(estimatedCost), icon: Icons.account_balance_wallet_outlined, wide: true),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Acciones rápidas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1_outlined)),
                      title: const Text('Administrar empleados', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Contratos, sueldo y datos personales'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onOpenEmployees,
                    ),
                    const Divider(),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Icon(Icons.notifications_active_outlined)),
                      title: Text('Obligaciones y recordatorios', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Próximamente: IESS, SUT, décimos y fechas límite.'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, this.wide = false});
  final String label;
  final String value;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(wide ? 20 : 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollTab extends StatelessWidget {
  const _PayrollTab({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context) {
    final engine = const CalculationEngine();
    return FutureBuilder<List<EmployeeRecord>>(
      future: EmployeeRepository().listEmployeeRecords(company.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center)));
        final records = (snapshot.data ?? const <EmployeeRecord>[]).where((r) => r.contract != null).toList();
        if (records.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('Agrega empleados con contrato para preparar la nómina.', textAlign: TextAlign.center)));

        final gross = records.fold<double>(0, (sum, r) => sum + r.contract!.monthlySalary);
        final personalIess = records.fold<double>(0, (sum, r) => sum + engine.employeeIess(r.contract!.monthlySalary));
        final employerIess = records.fold<double>(0, (sum, r) => sum + engine.employerIess(r.contract!.monthlySalary));

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Nómina', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Vista previa mensual con sueldo base e IESS. Horas extra y novedades se incorporarán al cierre.'),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _moneyRow('Sueldos', gross),
                    _moneyRow('IESS personal a descontar', personalIess),
                    _moneyRow('IESS patronal', employerIess),
                    const Divider(height: 26),
                    _moneyRow('Neto base empleados', gross - personalIess, strong: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Empleados', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 10),
            ...records.map((record) {
              final salary = record.contract!.monthlySalary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(record.employee.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${record.contract!.position ?? 'Empleado'} · IESS ${money(engine.employeeIess(salary))}'),
                    trailing: Text(money(salary - engine.employeeIess(salary)), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _moneyRow(String label, double value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Expanded(child: Text(label)), Text(money(value), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700))]),
      );
}

class _SettlementTab extends StatefulWidget {
  const _SettlementTab({required this.company});
  final Company company;

  @override
  State<_SettlementTab> createState() => _SettlementTabState();
}

class _SettlementTabState extends State<_SettlementTab> {
  final _engine = const CalculationEngine();
  final _pendingSalary = TextEditingController(text: '0');
  final _thirteenth = TextEditingController(text: '0');
  final _fourteenth = TextEditingController(text: '0');
  final _vacations = TextEditingController(text: '0');
  final _reserve = TextEditingController(text: '0');
  final _otherIncome = TextEditingController(text: '0');
  final _deductions = TextEditingController(text: '0');
  late Future<List<EmployeeRecord>> _records;
  String? _employeeId;
  TerminationCause _cause = TerminationCause.resignation;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _records = EmployeeRepository().listEmployeeRecords(widget.company.id);
  }

  @override
  void dispose() {
    for (final c in [_pendingSalary, _thirteenth, _fourteenth, _vacations, _reserve, _otherIncome, _deductions]) {
      c.dispose();
    }
    super.dispose();
  }

  double _number(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  SettlementBreakdown? _breakdown(List<EmployeeRecord> records) {
    if (_employeeId == null) return null;
    final record = records.where((r) => r.employee.id == _employeeId).firstOrNull;
    final contract = record?.contract;
    if (record == null || contract == null) return null;
    return _engine.settlement(
      remunerationBase: contract.monthlySalary,
      startDate: contract.startDate,
      endDate: _date,
      cause: _cause,
      pendingSalary: _number(_pendingSalary),
      thirteenth: _number(_thirteenth),
      fourteenth: _number(_fourteenth),
      vacations: _number(_vacations),
      reserveFundPending: _number(_reserve),
      otherIncome: _number(_otherIncome),
      deductions: _number(_deductions),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(1980), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(List<EmployeeRecord> records, SettlementBreakdown breakdown) async {
    final record = records.where((r) => r.employee.id == _employeeId).firstOrNull;
    if (record == null) return;
    setState(() => _saving = true);
    try {
      await SettlementRepository().saveDraft(record: record, terminationDate: _date, cause: _cause, breakdown: breakdown);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cálculo guardado como borrador.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el borrador: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmployeeRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${snapshot.error}')));
        final records = (snapshot.data ?? const <EmployeeRecord>[]).where((r) => r.contract != null).toList();
        if (records.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('Agrega un empleado con contrato para calcular su finiquito.', textAlign: TextAlign.center)));

        final breakdown = _breakdown(records);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Finiquito', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Selecciona al empleado, la causal y registra valores pendientes. El resultado es estimado.'),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _employeeId,
              decoration: const InputDecoration(labelText: 'Empleado', prefixIcon: Icon(Icons.person_outline)),
              items: records.map((r) => DropdownMenuItem(value: r.employee.id, child: Text(r.employee.fullName))).toList(),
              onChanged: (value) => setState(() => _employeeId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TerminationCause>(
              initialValue: _cause,
              decoration: const InputDecoration(labelText: 'Causal de terminación'),
              items: TerminationCause.values.map((cause) => DropdownMenuItem(value: cause, child: Text(_causeName(cause)))).toList(),
              onChanged: (value) => setState(() => _cause = value ?? TerminationCause.resignation),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFDDE1EA))),
              leading: const Icon(Icons.event_outlined),
              title: const Text('Fecha de terminación'),
              subtitle: Text(compactDate(_date)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 18),
            const Text('Valores pendientes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 10),
            _amountField(_pendingSalary, 'Remuneración pendiente'),
            _amountField(_thirteenth, 'Décimo tercero pendiente'),
            _amountField(_fourteenth, 'Décimo cuarto pendiente'),
            _amountField(_vacations, 'Vacaciones pendientes'),
            _amountField(_reserve, 'Fondos de reserva pendientes'),
            _amountField(_otherIncome, 'Otros ingresos'),
            _amountField(_deductions, 'Descuentos'),
            if (breakdown != null) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resultado estimado', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 12),
                      _resultRow('Beneficios pendientes', breakdown.benefitsTotal),
                      if (breakdown.desahucio > 0) _resultRow('Bonificación por desahucio', breakdown.desahucio),
                      if (breakdown.dismissalIndemnification > 0) _resultRow('Indemnización por despido', breakdown.dismissalIndemnification),
                      _resultRow('Otros ingresos + sueldo pendiente', breakdown.pendingSalary + breakdown.otherIncome),
                      _resultRow('Descuentos', -breakdown.deductions),
                      const Divider(height: 26),
                      _resultRow('Total estimado', breakdown.total, strong: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(records, breakdown),
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando...' : 'Guardar cálculo'),
              ),
              const SizedBox(height: 12),
              const Text('Antes de pagar o registrar el acta en SUT, revisa la causal y todos los rubros que correspondan al caso concreto.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ],
          ],
        );
      },
    );
  }

  Widget _amountField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, prefixText: '\$ '),
        ),
      );

  Widget _resultRow(String label, double value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Expanded(child: Text(label)), Text(money(value), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 18 : 14))]),
      );

  String _causeName(TerminationCause cause) => switch (cause) {
        TerminationCause.resignation => 'Renuncia',
        TerminationCause.desahucio => 'Desahucio',
        TerminationCause.mutualAgreement => 'Mutuo acuerdo',
        TerminationCause.unfairDismissal => 'Despido intempestivo',
        TerminationCause.contractEnd => 'Fin de contrato',
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
