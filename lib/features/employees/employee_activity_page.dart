import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/operational_models.dart';
import '../../data/operational_repositories.dart';
import '../../domain/calculation_engine.dart';

class EmployeeActivityPage extends StatefulWidget {
  const EmployeeActivityPage({super.key, required this.record});

  final EmployeeRecord record;

  @override
  State<EmployeeActivityPage> createState() => _EmployeeActivityPageState();
}

class _EmployeeActivityPageState extends State<EmployeeActivityPage> {
  late Future<_ActivityData> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = _load();
  }

  Future<_ActivityData> _load() async {
    final contract = widget.record.contract;
    if (contract == null) {
      return const _ActivityData(overtime: [], vacations: [], takenCurrentPeriod: 0);
    }
    final overtimeRepo = OvertimeRepository();
    final vacationRepo = VacationRepository();
    final results = await Future.wait([
      overtimeRepo.listForEmployee(widget.record.employee.id),
      vacationRepo.listForEmployee(widget.record.employee.id),
      vacationRepo.takenDaysInCurrentServicePeriod(contract, DateTime.now()),
    ]);
    return _ActivityData(
      overtime: results[0] as List<OvertimeRecord>,
      vacations: results[1] as List<VacationRecord>,
      takenCurrentPeriod: results[2] as double,
    );
  }

  Future<void> _addOvertime() async {
    final contract = widget.record.contract;
    if (contract == null) return;
    var date = DateTime.now();
    var type = 'supplementary_50';
    final hours = TextEditingController(text: '1');

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Registrar horas adicionales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'supplementary_50', child: Text('Suplementaria · 50 %')),
                  DropdownMenuItem(value: 'extraordinary_100', child: Text('Extraordinaria · 100 %')),
                  DropdownMenuItem(value: 'night_25', child: Text('Recargo nocturno · 25 %')),
                ],
                onChanged: (value) => setSheetState(() => type = value ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hours,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Número de horas', prefixIcon: Icon(Icons.schedule)),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                leading: const Icon(Icons.event_outlined),
                title: const Text('Fecha'),
                subtitle: Text(compactDate(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: contract.startDate,
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar horas'),
              ),
            ],
          ),
        ),
      ),
    );

    if (accepted != true) return;
    final value = double.tryParse(hours.text.replaceAll(',', '.')) ?? 0;
    if (value <= 0) return;
    try {
      await OvertimeRepository().create(
        record: widget.record,
        workDate: date,
        hours: value,
        type: type,
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) _message('No se pudo registrar: $error');
    }
  }

  Future<void> _addVacation() async {
    final contract = widget.record.contract;
    if (contract == null) return;
    var range = DateTimeRange(start: DateTime.now(), end: DateTime.now());

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Registrar vacaciones tomadas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.beach_access_outlined),
                  title: Text('${compactDate(range.start)} → ${compactDate(range.end)}'),
                  subtitle: Text('${range.duration.inDays + 1} día(s) registrados'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: range,
                      firstDate: contract.startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheetState(() => range = picked);
                  },
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar vacaciones'),
              ),
            ],
          ),
        ),
      ),
    );

    if (accepted != true) return;
    try {
      await VacationRepository().registerTaken(
        record: widget.record,
        startDate: range.start,
        endDate: range.end,
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) _message('No se pudo registrar: $error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final contract = widget.record.contract;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.record.employee.fullName)),
      body: contract == null
          ? const Center(child: Text('Este empleado no tiene contrato activo.'))
          : FutureBuilder<_ActivityData>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center)));
                }
                final data = snapshot.data!;
                final engine = const CalculationEngine();
                final pendingVacation = engine.estimatedVacationDays(
                  contract.startDate,
                  DateTime.now(),
                  alreadyTakenInCurrentPeriod: data.takenCurrentPeriod,
                );
                final overtimeTotal = data.overtime
                    .where((item) => item.status != 'cancelled')
                    .fold<double>(0, (sum, item) => sum + item.amount);

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _data;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _HeroMetric(label: 'Vacaciones estimadas', value: '${pendingVacation.toStringAsFixed(1)} días')),
                            Container(width: 1, height: 46, color: Colors.white.withValues(alpha: 0.25)),
                            const SizedBox(width: 16),
                            Expanded(child: _HeroMetric(label: 'Horas registradas', value: money(overtimeTotal))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'Horas adicionales', action: 'Registrar', onTap: _addOvertime),
                      const SizedBox(height: 10),
                      if (data.overtime.isEmpty)
                        const _EmptyCard(icon: Icons.schedule_outlined, text: 'No hay horas adicionales registradas.')
                      else
                        ...data.overtime.take(12).map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Card(
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Icon(Icons.schedule, color: scheme.primary)),
                                  title: Text(item.typeLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${compactDate(item.workDate)} · ${item.hours.toStringAsFixed(1)} h'),
                                  trailing: Text(money(item.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ),
                            )),
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'Vacaciones tomadas', action: 'Registrar', onTap: _addVacation),
                      const SizedBox(height: 10),
                      if (data.vacations.isEmpty)
                        const _EmptyCard(icon: Icons.beach_access_outlined, text: 'Aún no has registrado vacaciones tomadas.')
                      else
                        ...data.vacations.take(12).map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Card(
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: scheme.secondaryContainer, child: Icon(Icons.beach_access, color: scheme.secondary)),
                                  title: Text('${item.takenDays.toStringAsFixed(0)} día(s)', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${compactDate(item.startDate)} → ${compactDate(item.endDate)}'),
                                ),
                              ),
                            )),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ActivityData {
  const _ActivityData({required this.overtime, required this.vacations, required this.takenCurrentPeriod});
  final List<OvertimeRecord> overtime;
  final List<VacationRecord> vacations;
  final double takenCurrentPeriod;
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 11)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
        ],
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, required this.onTap});
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          TextButton.icon(onPressed: onTap, icon: const Icon(Icons.add, size: 18), label: Text(action)),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}
