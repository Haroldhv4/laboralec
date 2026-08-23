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
      extendBody: true,
      drawer: AppDrawer(companyName: widget.company.displayName),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.company.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _tabSubtitle(_index),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.apartment_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Resumen',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded),
                label: 'Empleados',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Nómina',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_turned_in_outlined),
                selectedIcon: Icon(Icons.assignment_turned_in_rounded),
                label: 'Finiquitos',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tabSubtitle(int index) => switch (index) {
        1 => 'Equipo y contratos',
        2 => 'Roles y periodos',
        3 => 'Terminaciones e historial',
        _ => 'Centro laboral',
      };
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
        final salaries = active.fold<double>(
          0,
          (sum, item) => sum + item.contract!.monthlySalary,
        );
        final estimatedCost = active.fold<double>(
          0,
          (sum, item) {
            final contract = item.contract!;
            final reserve =
                engine.completedYears(contract.startDate, DateTime.now()) >= 1;
            return sum +
                engine
                    .employmentCost(
                      contract.monthlySalary,
                      includeReserveFund: reserve,
                    )
                    .total;
          },
        );

        return RefreshIndicator(
          onRefresh: () async {
            await EmployeeRepository().listEmployeeRecords(company.id);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 118),
            children: [
              _CompanyHero(
                company: company,
                employees: records.length,
                salaries: salaries,
                estimatedCost: estimatedCost,
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gestión diaria',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${active.length} activos',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Novedades',
                      subtitle: 'Horas extra y vacaciones',
                      icon: Icons.event_repeat_rounded,
                      accent: scheme.secondary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorklogsPage(company: company),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: 'Obligaciones',
                      subtitle: 'IESS, décimos y alertas',
                      icon: Icons.notifications_active_rounded,
                      accent: scheme.primary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ObligationsPage(company: company),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenEmployees,
                  child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.groups_rounded, color: scheme.primary),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Administrar empleados',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Contratos, sueldo y beneficios',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: scheme.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No pudimos actualizar todas las métricas: ${snapshot.error}',
                          ),
                        ),
                      ],
                    ),
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

class _CompanyHero extends StatelessWidget {
  const _CompanyHero({
    required this.company,
    required this.employees,
    required this.salaries,
    required this.estimatedCost,
  });

  final Company company;
  final int employees;
  final double salaries;
  final double estimatedCost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final region = company.region == 'sierra_amazonia'
        ? 'Sierra / Amazonía'
        : 'Costa / Insular';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .15),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, const Color(0xFF0B5963), scheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -45,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
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
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          region,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroMetric(
                          icon: Icons.groups_rounded,
                          label: 'Empleados',
                          value: '$employees',
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _HeroMetric(
                          icon: Icons.payments_rounded,
                          label: 'Sueldos',
                          value: money(salaries),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withValues(alpha: .09)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Costo laboral estimado',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .78),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          money(estimatedCost),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

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
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: accent),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
