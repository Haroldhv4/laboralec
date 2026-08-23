import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/operational_models.dart';
import '../../data/payroll_repository.dart';
import '../../data/repositories.dart';
import '../../services/payroll_pdf_service.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key, required this.company});
  final Company company;

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late Future<List<PayrollPeriodRecord>> _periods;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _periods = PayrollRepositoryV2().listPeriods(widget.company.id);
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final employees = await EmployeeRepository().listEmployeeRecords(widget.company.id);
      final active = employees.where((item) => item.contract != null).toList();
      if (active.isEmpty) {
        _message('Agrega al menos un empleado con contrato.');
        return;
      }
      final period = await PayrollRepositoryV2().generate(
        company: widget.company,
        employees: active,
        year: _year,
        month: _month,
      );
      if (mounted) {
        setState(_reload);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PayrollDetailPage(company: widget.company, period: period),
          ),
        );
      }
    } catch (error) {
      _message('No se pudo generar la nómina: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        setState(_reload);
        await _periods;
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
                const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 18),
                Text(
                  'Nómina mensual',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  'Sueldo proporcional, horas extra, décimos mensualizados, fondo de reserva, IESS y roles PDF.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Generar periodo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _month,
                          decoration: const InputDecoration(labelText: 'Mes'),
                          items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(_monthName(index + 1)))),
                          onChanged: (value) => setState(() => _month = value ?? _month),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _year,
                          decoration: const InputDecoration(labelText: 'Año'),
                          items: List.generate(5, (index) {
                            final value = DateTime.now().year - 2 + index;
                            return DropdownMenuItem(value: value, child: Text('$value'));
                          }),
                          onChanged: (value) => setState(() => _year = value ?? _year),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(_generating ? 'Calculando...' : 'Generar nómina'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text('Historial', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          FutureBuilder<List<PayrollPeriodRecord>>(
            future: _periods,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) return _error(snapshot.error.toString());
              final periods = snapshot.data ?? const <PayrollPeriodRecord>[];
              if (periods.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('Todavía no hay periodos guardados. Genera el primero cuando quieras preparar la nómina.'),
                  ),
                );
              }
              return Column(
                children: periods.map((period) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(backgroundColor: scheme.secondaryContainer, child: Icon(Icons.calendar_month, color: scheme.secondary)),
                          title: Text(_capitalize(period.label), style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(period.status == 'closed' ? 'Periodo cerrado' : 'Nómina calculada'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PayrollDetailPage(company: widget.company, period: period)),
                          ),
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

  Widget _error(String text) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No pudimos cargar la nómina: $text'),
        ),
      );
}

class PayrollDetailPage extends StatelessWidget {
  const PayrollDetailPage({super.key, required this.company, required this.period});
  final Company company;
  final PayrollPeriodRecord period;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_capitalize(period.label))),
      body: FutureBuilder<List<PayrollEntryRecord>>(
        future: PayrollRepositoryV2().listEntries(period.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${snapshot.error}')));
          final entries = snapshot.data ?? const <PayrollEntryRecord>[];
          final gross = entries.fold<double>(0, (sum, item) => sum + item.grossIncome);
          final net = entries.fold<double>(0, (sum, item) => sum + item.netPay);
          final iess = entries.fold<double>(0, (sum, item) => sum + item.employeeIess);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Row(
                children: [
                  Expanded(child: _Metric(label: 'Ingresos', value: money(gross))),
                  const SizedBox(width: 10),
                  Expanded(child: _Metric(label: 'Neto', value: money(net))),
                ],
              ),
              const SizedBox(height: 10),
              _Metric(label: 'IESS personal', value: money(iess), wide: true),
              const SizedBox(height: 24),
              Text('Roles de pago', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Toca un empleado para compartir su rol en PDF.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Este periodo no tiene empleados calculados.')))
              else
                ...entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          title: Text(entry.employeeName, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('${entry.position} · Ingresos ${money(entry.grossIncome)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(money(entry.netPay), style: const TextStyle(fontWeight: FontWeight.w900)),
                              const Text('PDF', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          onTap: () async {
                            try {
                              await const PayrollPdfService().shareRole(company: company, period: period, entry: entry);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar el PDF: $error')));
                              }
                            }
                          },
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.wide = false});
  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: EdgeInsets.all(wide ? 18 : 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ),
      );
}

String _monthName(int month) => const ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'][month - 1];
String _capitalize(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
