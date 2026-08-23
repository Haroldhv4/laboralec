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

class _SettlementCalculatorPageState extends State<SettlementCalculatorPage> {
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
  bool get _hasStoredRegion =>
      widget.companyRegion == 'costa_insular' ||
      widget.companyRegion == 'sierra_amazonia';

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
    _thirteenthMonthlyized = contract?.thirteenthPaymentMode == 'monthly';
    _fourteenthMonthlyized = contract?.fourteenthPaymentMode == 'monthly';
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
          const SnackBar(content: Text('Finiquito guardado como borrador.')),
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
    final record = widget.record;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(record == null ? 'Calculadora de finiquito' : 'Finiquito'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          _Hero(
            employeeName: record?.employee.fullName,
            subtitle: _employeeMode
                ? 'Ya conocemos el contrato. Indica la terminación y calculamos el resto.'
                : 'Ingresa los datos esenciales y obtén el desglose automáticamente.',
          ),
          const SizedBox(height: 24),
          if (_employeeMode) ...[
            _StoredContractCard(
              record: record!,
              contract: _contract!,
              region: _region,
              showRegion: _hasStoredRegion,
            ),
            const SizedBox(height: 18),
          ] else ...[
            Text(
              'Datos del trabajador',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _salary,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Última remuneración mensual',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _DateField(
              title: 'Fecha de ingreso',
              date: _startDate,
              icon: Icons.login_rounded,
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 18),
          ],
          Text(
            'Terminación',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
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
          _DateField(
            title: 'Fecha de terminación',
            date: _endDate,
            icon: Icons.event_available_outlined,
            onTap: _pickEndDate,
          ),
          if (!_employeeMode || !_hasStoredRegion) ...[
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
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _deductions,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Descuentos pendientes (opcional)',
              prefixText: '\$ ',
              prefixIcon: Icon(Icons.remove_circle_outline),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              leading: Icon(Icons.tune_rounded, color: scheme.secondary),
              title: const Text(
                'Ajustes opcionales',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Normalmente no necesitas tocar nada aquí'),
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
                  title: const Text('Sueldo del mes de salida ya pagado'),
                  subtitle: const Text('Evita sumar remuneración pendiente.'),
                  value: _salaryCurrentMonthPaid,
                  onChanged: (value) =>
                      setState(() => _salaryCurrentMonthPaid = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir fondo de reserva pendiente del mes'),
                  value: _includeCurrentReserveFund,
                  onChanged: (value) =>
                      setState(() => _includeCurrentReserveFund = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _vacationDays,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Vacaciones pendientes reales',
                    hintText: 'Vacío = estimación automática',
                    prefixIcon: Icon(Icons.beach_access_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otherIncome,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            _Result(estimate: estimate),
          if (estimate != null && record != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(estimate),
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Guardando...' : 'Guardar borrador'),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Las fechas permiten calcular automáticamente proporcionales de sueldo y décimos. Las vacaciones realmente pendientes no pueden conocerse solo con fechas si el trabajador ya tomó días; por eso la app las estima y permite corregirlas en Ajustes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
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

class _Hero extends StatelessWidget {
  const _Hero({required this.employeeName, required this.subtitle});

  final String? employeeName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_turned_in_outlined, color: Colors.white, size: 34),
          const SizedBox(height: 20),
          Text(
            employeeName ?? 'Finiquito laboral',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoredContractCard extends StatelessWidget {
  const _StoredContractCard({
    required this.record,
    required this.contract,
    required this.region,
    required this.showRegion,
  });

  final EmployeeRecord record;
  final EmploymentContract contract;
  final EcuadorRegion region;
  final bool showRegion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.primary,
                  child: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.employee.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        contract.position ?? 'Empleado',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            _InfoRow(label: 'Ingreso', value: compactDate(contract.startDate)),
            _InfoRow(label: 'Sueldo', value: money(contract.monthlySalary)),
            if (showRegion)
              _InfoRow(
                label: 'Región',
                value: region == EcuadorRegion.sierraAmazonia
                    ? 'Sierra / Amazonía'
                    : 'Costa / Insular',
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

class _DateField extends StatelessWidget {
  const _DateField({
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelMedium),
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

class _Result extends StatelessWidget {
  const _Result({required this.estimate});

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
            color: scheme.primaryContainer.withValues(alpha: 0.62),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total estimado', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  money(result.total),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w900,
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
                  _AmountRow(
                    label: 'Sueldo pendiente',
                    value: result.pendingSalary,
                    detail: '${estimate.pendingSalaryDays} días',
                  ),
                _AmountRow(
                  label: 'Décimo tercero',
                  value: result.thirteenth,
                  detail: '${estimate.thirteenthDays} días proporcionales',
                ),
                _AmountRow(
                  label: 'Décimo cuarto',
                  value: result.fourteenth,
                  detail: '${estimate.fourteenthDays} días · SBU ${money(estimate.sbuUsed)}',
                ),
                _AmountRow(
                  label: 'Vacaciones',
                  value: result.vacations,
                  detail: '${estimate.vacationDays.toStringAsFixed(2)} días',
                ),
                if (result.reserveFund > 0)
                  _AmountRow(label: 'Fondo de reserva', value: result.reserveFund),
                if (result.desahucio > 0)
                  _AmountRow(label: 'Bonificación por desahucio', value: result.desahucio),
                if (result.dismissalIndemnification > 0)
                  _AmountRow(
                    label: 'Indemnización por despido',
                    value: result.dismissalIndemnification,
                  ),
                if (result.otherIncome > 0)
                  _AmountRow(label: 'Otros ingresos', value: result.otherIncome),
                if (result.deductions > 0)
                  _AmountRow(label: 'Descuentos', value: -result.deductions),
                const Divider(height: 28),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cómo se estimó',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  children: estimate.notes
                      .map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 17, color: scheme.secondary),
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
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value, this.detail});

  final String label;
  final double value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
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
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(money(value), style: const TextStyle(fontWeight: FontWeight.w900)),
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
