import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/operational_repositories.dart';
import '../../data/repositories.dart';
import '../../domain/calculation_engine.dart';

class EmployeeSettlementPage extends StatefulWidget {
  const EmployeeSettlementPage({
    super.key,
    required this.record,
    required this.companyRegion,
  });

  final EmployeeRecord record;
  final String? companyRegion;

  @override
  State<EmployeeSettlementPage> createState() => _EmployeeSettlementPageState();
}

class _EmployeeSettlementPageState extends State<EmployeeSettlementPage> {
  final _engine = const CalculationEngine();
  final _deductions = TextEditingController(text: '0');
  final _otherIncome = TextEditingController(text: '0');
  final _vacationOverride = TextEditingController();
  DateTime _endDate = DateTime.now();
  TerminationCause _cause = TerminationCause.resignation;
  bool _salaryPaid = false;
  bool _includeReserve = false;
  bool _saving = false;
  double _takenVacationDays = 0;
  bool _loadingVacation = true;

  EmploymentContract get contract => widget.record.contract!;

  EcuadorRegion get region => widget.companyRegion == 'sierra_amazonia'
      ? EcuadorRegion.sierraAmazonia
      : EcuadorRegion.costaInsular;

  @override
  void initState() {
    super.initState();
    _includeReserve = contract.reserveFundPaymentMode == 'monthly';
    _loadVacationTaken();
  }

  @override
  void dispose() {
    _deductions.dispose();
    _otherIncome.dispose();
    _vacationOverride.dispose();
    super.dispose();
  }

  Future<void> _loadVacationTaken() async {
    setState(() => _loadingVacation = true);
    try {
      final value = await VacationRepository().takenDaysInCurrentServicePeriod(
        contract,
        _endDate,
      );
      if (mounted) setState(() => _takenVacationDays = value);
    } catch (_) {
      if (mounted) setState(() => _takenVacationDays = 0);
    } finally {
      if (mounted) setState(() => _loadingVacation = false);
    }
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  SettlementEstimate get estimate {
    final override = _vacationOverride.text.trim().isEmpty
        ? null
        : _number(_vacationOverride);
    return _engine.automaticSettlement(
      remunerationBase: contract.monthlySalary,
      startDate: contract.startDate,
      endDate: _endDate,
      cause: _cause,
      region: region,
      thirteenthMonthlyized: contract.thirteenthPaymentMode == 'monthly',
      fourteenthMonthlyized: contract.fourteenthPaymentMode == 'monthly',
      salaryCurrentMonthPaid: _salaryPaid,
      vacationDaysPending: override,
      vacationDaysTakenInCurrentPeriod: _takenVacationDays,
      includeCurrentReserveFund: _includeReserve,
      otherIncome: _number(_otherIncome),
      deductions: _number(_deductions),
    );
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(contract.startDate) ? contract.startDate : _endDate,
      firstDate: contract.startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      await _loadVacationTaken();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SettlementRepository().saveDraft(
        record: widget.record,
        terminationDate: _endDate,
        cause: _cause,
        breakdown: estimate.breakdown,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finiquito guardado en el historial.')),
        );
        Navigator.pop(context, true);
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
    final result = estimate;
    final b = result.breakdown;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Finiquito del empleado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.record.employee.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${contract.position ?? 'Empleado'} · ${money(contract.monthlySalary)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.84))),
                const SizedBox(height: 4),
                Text('Ingreso ${compactDate(contract.startDate)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Solo necesitamos esto', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          DropdownButtonFormField<TerminationCause>(
            initialValue: _cause,
            decoration: const InputDecoration(labelText: 'Causal de terminación', prefixIcon: Icon(Icons.rule_folder_outlined)),
            items: TerminationCause.values.map((cause) => DropdownMenuItem(value: cause, child: Text(_causeName(cause)))).toList(),
            onChanged: (value) => setState(() => _cause = value ?? _cause),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: scheme.outlineVariant)),
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Fecha de terminación'),
            subtitle: Text(compactDate(_endDate)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickEndDate,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deductions,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Descuentos pendientes (opcional)', prefixText: '\$ ', prefixIcon: Icon(Icons.remove_circle_outline)),
          ),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              title: const Text('Ajustes opcionales', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_loadingVacation ? 'Revisando vacaciones registradas...' : 'Vacaciones tomadas registradas: ${_takenVacationDays.toStringAsFixed(1)} días'),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('El sueldo del mes de salida ya fue pagado'),
                  value: _salaryPaid,
                  onChanged: (value) => setState(() => _salaryPaid = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir fondo de reserva pendiente del mes'),
                  value: _includeReserve,
                  onChanged: (value) => setState(() => _includeReserve = value),
                ),
                TextField(
                  controller: _vacationOverride,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Forzar días de vacaciones pendientes', hintText: 'Vacío = cálculo con historial', prefixIcon: Icon(Icons.beach_access_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otherIncome,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Otros ingresos pendientes', prefixText: '\$ ', prefixIcon: Icon(Icons.add_circle_outline)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total estimado', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(money(b.total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
                const SizedBox(height: 16),
                _line('Sueldo pendiente', b.pendingSalary),
                _line('Décimo tercero', b.thirteenth),
                _line('Décimo cuarto', b.fourteenth),
                _line('Vacaciones · ${result.vacationDays.toStringAsFixed(1)} días', b.vacations),
                if (b.reserveFund > 0) _line('Fondo de reserva', b.reserveFund),
                if (b.desahucio > 0) _line('Bonificación por desahucio', b.desahucio),
                if (b.dismissalIndemnification > 0) _line('Indemnización por despido', b.dismissalIndemnification),
                if (b.otherIncome > 0) _line('Otros ingresos', b.otherIncome),
                if (b.deductions > 0) _line('Descuentos', -b.deductions),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando...' : 'Guardar finiquito'),
          ),
          const SizedBox(height: 14),
          Text('Laboral EC usa el contrato guardado, modalidad de décimos, región y vacaciones registradas. El resultado sigue siendo estimativo cuando existen remuneraciones variables, saldos antiguos o situaciones especiales.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.4, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _line(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12))),
            Text(money(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  String _causeName(TerminationCause cause) => switch (cause) {
        TerminationCause.resignation => 'Renuncia',
        TerminationCause.desahucio => 'Desahucio',
        TerminationCause.mutualAgreement => 'Mutuo acuerdo',
        TerminationCause.unfairDismissal => 'Despido intempestivo',
        TerminationCause.contractEnd => 'Fin de contrato',
      };
}
