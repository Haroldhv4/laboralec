import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/operational_models.dart';
import '../../data/operational_repositories.dart';

class ObligationsPage extends StatefulWidget {
  const ObligationsPage({super.key, required this.company});
  final Company company;

  @override
  State<ObligationsPage> createState() => _ObligationsPageState();
}

class _ObligationsPageState extends State<ObligationsPage> {
  late Future<List<ReminderRecord>> _reminders;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _reminders = ReminderRepository().list(widget.company.id);
  }

  Future<void> _addReminder() async {
    final title = TextEditingController();
    var dueDate = DateTime.now().add(const Duration(days: 7));
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Nuevo recordatorio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Qué debes recordar', prefixIcon: Icon(Icons.edit_note_rounded)),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                leading: const Icon(Icons.event_outlined),
                title: const Text('Fecha límite'),
                subtitle: Text(compactDate(dueDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setSheetState(() => dueDate = picked);
                },
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar recordatorio')),
            ],
          ),
        ),
      ),
    );

    if (accepted != true || title.text.trim().isEmpty) return;
    try {
      await ReminderRepository().create(companyId: widget.company.id, title: title.text, dueDate: dueDate);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar. Aplica la migración de reminders en Supabase. $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final obligations = _automaticObligations(widget.company, DateTime.now());
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        setState(_reload);
        await _reminders;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 32),
                const SizedBox(height: 18),
                Text('Obligaciones', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text('Fechas clave del empleador y tus propios recordatorios.', style: TextStyle(color: Colors.white.withValues(alpha: 0.82))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Próximas fechas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...obligations.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ObligationCard(item: item),
              )),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(child: Text('Mis recordatorios', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              TextButton.icon(onPressed: _addReminder, icon: const Icon(Icons.add, size: 18), label: const Text('Agregar')),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<ReminderRecord>>(
            future: _reminders,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              if (snapshot.hasError) return Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('No se pudieron cargar recordatorios: ${snapshot.error}')));
              final reminders = snapshot.data ?? const <ReminderRecord>[];
              if (reminders.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Icon(Icons.task_alt_rounded, color: scheme.secondary),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('No tienes recordatorios personalizados pendientes.')),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: reminders.map((reminder) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Card(
                        child: CheckboxListTile(
                          value: reminder.completed,
                          title: Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(compactDate(reminder.dueDate)),
                          secondary: const Icon(Icons.event_note_outlined),
                          onChanged: (value) async {
                            await ReminderRepository().setDone(reminder.id, value ?? false);
                            if (mounted) setState(_reload);
                          },
                        ),
                      ),
                    )).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Referencias: IESS exige registrar el aviso de entrada dentro de 15 días, novedades/aviso de salida dentro de 3 días y pagar aportes dentro de los 15 días posteriores al mes. El Ministerio del Trabajo establece un máximo de 15 días desde la terminación para registrar el acta de finiquito. Verifica feriados y disposiciones especiales vigentes.',
            style: TextStyle(fontSize: 11, height: 1.45, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ObligationCard extends StatelessWidget {
  const _ObligationCard({required this.item});
  final _Obligation item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = item.date.difference(DateTime.now()).inDays;
    final urgent = days <= 7;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (urgent ? scheme.errorContainer : scheme.secondaryContainer),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: urgent ? scheme.onErrorContainer : scheme.secondary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(item.subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item.date.day}/${item.date.month}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text('${item.date.year}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Obligation {
  const _Obligation({required this.title, required this.subtitle, required this.date, required this.icon});
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
}

List<_Obligation> _automaticObligations(Company company, DateTime now) {
  final nextMonth = now.month == 12 ? DateTime(now.year + 1, 1, 15) : DateTime(now.year, now.month + 1, 15);
  final thirteenth = _nextDate(now, 12, 24);
  final fourteenth = company.region == 'sierra_amazonia' ? _nextDate(now, 8, 15) : _nextDate(now, 3, 15);
  final items = <_Obligation>[
    _Obligation(
      title: 'Pago de aportes IESS',
      subtitle: 'Planillas del mes · hasta el día 15 o siguiente hábil cuando corresponda',
      date: nextMonth,
      icon: Icons.account_balance_outlined,
    ),
    _Obligation(
      title: 'Décimo tercero acumulado',
      subtitle: 'Fecha máxima general de pago para quienes acumulan',
      date: thirteenth,
      icon: Icons.card_giftcard_outlined,
    ),
    _Obligation(
      title: 'Décimo cuarto acumulado',
      subtitle: company.region == 'sierra_amazonia' ? 'Sierra / Amazonía' : 'Costa / Insular',
      date: fourteenth,
      icon: Icons.school_outlined,
    ),
  ];
  items.sort((a, b) => a.date.compareTo(b.date));
  return items;
}

DateTime _nextDate(DateTime now, int month, int day) {
  var value = DateTime(now.year, month, day);
  if (value.isBefore(DateTime(now.year, now.month, now.day))) value = DateTime(now.year + 1, month, day);
  return value;
}
