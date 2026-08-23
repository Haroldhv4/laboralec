import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../domain/calculation_engine.dart';
import '../../widgets/app_drawer.dart';
import '../employees/employees_page.dart';
import '../employees/worklogs_page.dart';
import '../obligations/obligations_page.dart';
import '../payroll/payroll_page.dart';
import '../settlements/settlements_page.dart';

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
      _OverviewTab(
        company: widget.company,
        onOpenEmployees: () => setState(() => _index = 1),
      ),
      EmployeesPage(company: widget.company),
      PayrollPage(company: widget.company),
      SettlementsPage(company: widget.company),
    ];

    return Scaffold(
      drawer: AppDrawer(companyName: widget.company.displayName),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.company.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Centro laboral',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Empleados'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Nómina'),
          NavigationDestination(icon: Icon(Icons.assignment_turned_in_outlined), selectedIcon: Icon(Icons.assignment_turned_in_rounded), label: 'Finiquitos'),
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
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<EmployeeRecord>>(
      future: EmployeeRepository().listEmployeeRecords(company.id),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <EmployeeRecord>[];
        final active = records.where((item) => item.contract != null).toList();
        final salaries = active.fold<double>(0, (sum, item) => sum + item.contract!.monthlySalary);
        final estimatedCost = active.fold<double>(
          0,
          (sum, item) {
            final contract = item.contract!;
            final reserve = engine.completedYears(contract.startDate, DateTime.now()) >= 1;
            return sum + engine.employmentCost(contract.monthlySalary, includeReserveFund: reserve).total;
          },
        );

        return RefreshIndicator(
          onRefresh: () async {
            await EmployeeRepository().listEmployeeRecords(company.id);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            company.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            company.region == 'sierra_amazonia' ? 'Sierra / Amazonía' : 'Costa / Insular',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (company.ruc?.isNotEmpty ?? false) 'RUC ${company.ruc}',
                        if (company.city?.isNotEmpty ?? false) company.city!,
                      ].join(' · ').isEmpty
                          ? 'Gestión laboral centralizada'
                          : [
                              if (company.ruc?.isNotEmpty ?? false) 'RUC ${company.ruc}',
                              if (company.city?.isNotEmpty ?? false) company.city!,
                            ].join(' · '),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _HeroMetric(label: 'Empleados', value: '${records.length}')),
                        Container(width: 1, height: 42, color: Colors.white.withValues(alpha: 0.25)),
                        const SizedBox(width: 16),
                        Expanded(child: _HeroMetric(label: 'Sueldos', value: money(salaries))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _WideMetric(
                label: 'Costo laboral mensual estimado',
                value: money(estimatedCost),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 26),
              Text('Gestión diaria', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Novedades',
                      subtitle: 'Horas extra y vacaciones',
                      icon: Icons.event_repeat_rounded,
                      accent: scheme.secondary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => WorklogsPage(company: company)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: 'Obligaciones',
                      subtitle: 'IESS, décimos y alertas',
                      icon: Icons.notifications_active_outlined,
                      accent: scheme.primary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ObligationsPage(company: company)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Icon(Icons.groups_outlined, color: scheme.primary)),
                  title: const Text('Administrar empleados', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text('Datos personales, contrato, sueldo y beneficios'),
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  onTap: onOpenEmployees,
                ),
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text('No pudimos actualizar todas las métricas: ${snapshot.error}'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 11)),
          const SizedBox(height: 5),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
        ],
      );
}

class _WideMetric extends StatelessWidget {
  const _WideMetric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: scheme.secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.accent, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
        ),
      );
}
