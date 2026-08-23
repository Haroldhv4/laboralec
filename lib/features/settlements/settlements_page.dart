import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/operational_models.dart';
import '../../data/operational_repositories.dart';
import '../../data/repositories.dart';
import '../calculators/settlement_calculator_page.dart';

class SettlementsPage extends StatefulWidget {
  const SettlementsPage({super.key, required this.company});
  final Company company;

  @override
  State<SettlementsPage> createState() => _SettlementsPageState();
}

class _SettlementsPageState extends State<SettlementsPage> {
  late Future<List<EmployeeRecord>> _employees;
  late Future<List<SettlementHistoryRecord>> _history;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _employees = EmployeeRepository().listEmployeeRecords(widget.company.id);
    _history = SettlementHistoryRepository().list(widget.company.id);
  }

  Future<void> _newSettlement() async {
    final records = (await _employees).where((item) => item.contract != null).toList();
    if (!mounted) return;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega un empleado con contrato primero.')));
      return;
    }

    final selected = await showModalBottomSheet<EmployeeRecord>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Text('¿A quién vas a liquidar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: records.map((record) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(record.employee.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${record.contract!.position ?? 'Empleado'} · ${money(record.contract!.monthlySalary)}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, record),
                    )).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettlementCalculatorPage(record: selected, companyRegion: widget.company.region),
      ),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        setState(_reload);
        await Future.wait([_employees, _history]);
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
                const Icon(Icons.assignment_turned_in_outlined, color: Colors.white, size: 32),
                const SizedBox(height: 18),
                Text('Finiquitos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text('Calcula con los datos del contrato y conserva el historial de cada liquidación.', style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.35)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: scheme.primary),
                  onPressed: _newSettlement,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo finiquito'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('Historial', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          FutureBuilder<List<SettlementHistoryRecord>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()));
              if (snapshot.hasError) return Card(child: Padding(padding: const EdgeInsets.all(20), child: Text('No pudimos cargar el historial: ${snapshot.error}')));
              final history = snapshot.data ?? const <SettlementHistoryRecord>[];
              if (history.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('Todavía no hay finiquitos guardados. Los cálculos que guardes aparecerán aquí.'),
                  ),
                );
              }
              return Column(
                children: history.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Icon(Icons.description_outlined, color: scheme.primary)),
                          title: Text(item.employeeName, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('${item.cause} · ${compactDate(item.terminationDate)}'),
                          trailing: Text(money(item.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        ),
                      ),
                    )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
