import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../domain/calculation_engine.dart';

class SettlementCalculatorPage extends StatefulWidget {
  const SettlementCalculatorPage({
    super.key,
    this.record,
    this.companyRegion,
  });

  final EmployeeRecord? record;
  final String? companyRegion;

  @override
  State<SettlementCalculatorPage> createState() =>
      _SettlementCalculatorPageState();
}

class _SettlementCalculatorPageState
    extends State<SettlementCalculatorPage> {
  final _engine = const CalculationEngine();
  late final TextEditingController _salary;
  final _deductions = TextEditingController(text: '0');
  final _otherIncome = TextEditingController(text: '0');
  final _vacationDays = TextEditingController();

  late DateTime _startDate;
  DateTime _endDate = DateTime.now();
  TerminationCause _cause = TerminationCause.resignation;
  EcuadorRegion _region = EcuadorRegion.costaInsular;
  bool _thirteenthMonthlyized = false;
  bool _fourteenthMonthlyized = false;
  bool _salaryCurrentMonthPaid = false;
  bool _includeCurrentReserveFund = false;
  bool _saving = false;

  EmploymentContract? get _contract => widget.record?.contract;
  bool get _employeeMode => widget.record != null && _contract != null;

  @override
  void initState() {
    super.initState();
    final contract = _contract;
    _salary = TextEditingController(
      text: contract == null ? '' : contract.monthlySalary.toStringAsFixed(2),
    );
    _startDate = contract?.startDate ??
        DateTime(
          DateTime.now().year - 1,
          DateTime.now().month,
          DateTime.now().day,
        );
    _thirteenthMonthlyized =
        contract?.thirteenthPaymentMode == 'monthly';
    _fourteenthMonthlyized =
        contract?.fourteenthPaymentMode == 'monthly';
    _includeCurrentReserveFund =
        contract?.reserveFundPaymentMode == 'monthly';
    _region = widget.companyRegion == 'sierra_amazonia'
        ? EcuadorRegion.sierraAmazonia
        : EcuadorRegion.costaInsular;
  }

  @override
  void dispose() {
    _salary.dispose();
    _deductions.dispose();
    _otherIncome.dispose();
    _vacationDays.dispose();
    super.dispose();
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  SettlementEstimate? get _estimate {
    final salary = _number(_salary);
    if (salary <= 0 || _endDate.isBefore(_startDate)) return null;

    final vacationOverride = _vacationDays.text.trim().isEmpty
        ? null
        : _number(_vacationDays);

    return _engine.automaticSettlement(
      remunerationBase: salary,
      startDate: _startDate,
      endDate: _endDate,
      cause: _cause,
      region: _region,
      thirteenthMonthlyized: _thirteenthMonthlyized,
      fourteenthMonthlyized: _fourteenthMonthlyized,
      salaryCurrentMonthPaid: _salaryCurrentMonthPaid,
      vacationDaysPending: vacationOverride,
      includeCurrentReserveFund: _includeCurrentReserveFund,
      otherIncome: _number(_otherIncome),
      deductions: _number(_deductions),
    );
  }

  Future<void> _pickStartDate() async {
    if (_employeeMode) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1980),
      lastDate: _endDate,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save(SettlementEstimate estimate) async {
    final record = widget.record;
    if (record == null) return;

    setState(() => _saving = true);
    try {
      await SettlementRepository().saveDraft(
        record: record,
        terminationDate: _endDate,
        cause: _cause,
        breakdown: estimate.breakdown,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finiquito guardado como borrador.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    final theme = Theme.of(context);
    final record = widget.record;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          record == null ? 'Calculadora de finiquito' : 'Finiquito',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          _HeaderCard(
            employeeName: record?.employee.fullName,
            subtitle: record == null
                ? 'Calcula una liquidación laboral aproximada con los datos esenciales.'
                : 'Los datos del contrato ya están cargados. Solo indica cómo y cuándo terminó la relación.',
          ),
          const SizedBox(height: 20),
          Text(
            'Datos esenciales',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (!_employeeMode) ...[
            TextField(
              controller: _salary,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Última remuneración mensual',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _DateTile(
              title: 'Fecha de ingreso',
              date: _startDate,
              icon: Icons.login_rounded,
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 12),
          ] else ...[
            _ContractSummary(record: record!, contract: _contract!),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<TerminationCause>(
            initialValue: _cause,
            decoration: const InputDecoration(
              labelText: 'Causal de terminación',
              prefixIcon: Icon(Icons.rule_folder_outlined),
            ),
            items: TerminationCause.values
                .map(
                  (cause) => DropdownMenuItem(
                    value: cause,
                    child: Text(_causeName(cause)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _cause = value);
            },
          ),
          const SizedBox(height: 12),
          _DateTile(
            title: 'Fecha de terminación',
            date: _endDate,
            icon: Icons.event_available_outlined,
            onTap: _pickEndDate,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<EcuadorRegion>(
            initialValue: _region,
            decoration: const InputDecoration(
              labelText: 'Región laboral',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: EcuadorRegion.costaInsular,
                child: Text('Costa / Insular'),
              ),
              DropdownMenuItem(
                value: EcuadorRegion.sierraAmazonia,
                child: Text('Sierra / Amazonía'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _region = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deductions,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Descuentos pendientes (opcional)',
              prefixText: '\$ ',
              prefixIcon: Icon(Icons.remove_circle_outline),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              childrenPadding:
                  const EdgeInsets.fromLTRB(18, 0, 18, 18),
              title: const Text(
                'Ajustes opcionales',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Solo cambia algo si el caso lo necesita',
              ),
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Décimo tercero mensualizado'),
                  value: _thirteenthMonthlyized,
                  onChanged: (value) =>
                      setState(() => _thirteenthMonthlyized = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Décimo cuarto mensualizado'),
                  value: _fourteenthMonthlyized,
                  onChanged: (value) =>
                      setState(() => _fourteenthMonthlyized = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('El sueldo del mes de salida ya fue pagado'),
                  subtitle: const Text(
                    'Si está activo, no se suma remuneración pendiente.',
                  ),
                  value: _salaryCurrentMonthPaid,
                  onChanged: (value) =>
                      setState(() => _salaryCurrentMonthPaid = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir fondo de reserva del mes'),
                  subtitle: const Text(
                    'Úsalo cuando corresponde pago mensual y aún está pendiente.',
                  ),
                  value: _includeCurrentReserveFund,
                  onChanged: (value) =>
                      setState(() => _includeCurrentReserveFund = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _vacationDays,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Días de vacaciones pendientes',
                    hintText: 'Vacío = estimación automática',
                    prefixIcon: Icon(Icons.beach_access_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otherIncome,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Otros ingresos pendientes',
                    prefixText: '\$ ',
                    prefixIcon: Icon(Icons.add_circle_outline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (estimate == null)
            const _EmptyResult()
          else
            _SettlementResultCard(estimate: estimate),
          if (estimate != null && record != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(estimate),
              icon: const Icon(Icons.save_outlined),
              label: Text(
                _saving ? 'Guardando...' : 'Guardar finiquito',
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'La calculadora oficial del Ministerio solicita causal, región, fechas de inicio y fin, última remuneración, modalidad de décimos y vacaciones pendientes. Laboral EC automatiza esos rubros cuando dispone de la información.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _causeName(TerminationCause cause) => switch (cause) {
        TerminationCause.resignation => 'Renuncia',
        TerminationCause.desahucio => 'Desahucio',
        TerminationCause.mutualAgreement => 'Mutuo acuerdo',
        TerminationCause.unfairDismissal => 'Despido intempestivo',
        TerminationCause.contractEnd => 'Fin de contrato',
      };
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.employeeName,
    required this.subtitle,
  });

  final String? employeeName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            color: scheme.onPrimary,
            size: 32,
          ),
          const SizedBox(height: 18),
          Text(
            employeeName ?? 'Finiquito laboral',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.84),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractSummary extends StatelessWidget {
  const _ContractSummary({
    required this.record,
    required this.contract,
  });

  final EmployeeRecord record;
  final EmploymentContract contract;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _row('Empleado', record.employee.fullName),
            _row('Ingreso', compactDate(contract.startDate)),
            _row('Sueldo', money(contract.monthlySalary)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.title,
    required this.date,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final DateTime date;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      compactDate(date),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettlementResultCard extends StatelessWidget {
  const _SettlementResultCard({required this.estimate});

  final SettlementEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final result = estimate.breakdown;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total estimado',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  money(result.total),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${estimate.completedServiceYears} años completos de servicio',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                if (result.pendingSalary > 0)
                  _row(
                    'Sueldo pendiente (${estimate.pendingSalaryDays} días)',
                    result.pendingSalary,
                  ),
                _row(
                  'Décimo tercero',
                  result.thirteenth,
                  hint: '${estimate.thirteenthDays} días proporcionales',
                ),
                _row(
                  'Décimo cuarto',
                  result.fourteenth,
                  hint:
                      '${estimate.fourteenthDays} días · SBU ${money(estimate.sbuUsed)}',
                ),
                _row(
                  'Vacaciones',
                  result.vacations,
                  hint:
                      '${estimate.vacationDays.toStringAsFixed(2)} días estimados',
                ),
                if (result.reserveFund > 0)
                  _row('Fondo de reserva pendiente', result.reserveFund),
                if (result.desahucio > 0)
                  _row('Bonificación por desahucio', result.desahucio),
                if (result.dismissalIndemnification > 0)
                  _row(
                    'Indemnización por despido',
                    result.dismissalIndemnification,
                  ),
                if (result.otherIncome > 0)
                  _row('Otros ingresos', result.otherIncome),
                if (result.deductions > 0)
                  _row('Descuentos', -result.deductions),
                const Divider(height: 28),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Supuestos del cálculo',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  children: estimate.notes
                      .map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 17,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  note,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double amount, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (hint != null)
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(amount),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.calculate_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Completa los datos para ver el resultado',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
