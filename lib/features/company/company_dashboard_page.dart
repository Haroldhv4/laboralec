import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../domain/calculation_engine.dart';
import '../calculators/settlement_calculator_page.dart';
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
      _OverviewTab(
        company: widget.company,
        onOpenEmployees: () => setState(() => _index = 1),
        onOpenSettlement: () => setState(() => _index = 3),
      ),
      EmployeesPage(company: widget.company),
      _PayrollTab(company: widget.company),
      _SettlementTab(company: widget.company),
    ];

    return Scaffold(
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
              'Gestión laboral',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
            label: 'Finiquito',
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.company,
    required this.onOpenEmployees,
    required this.onOpenSettlement,
  });

  final Company company;
  final VoidCallback onOpenEmployees;
  final VoidCallback onOpenSettlement;

  @override
  Widget build(BuildContext context) {
    final engine = const CalculationEngine();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<List<EmployeeRecord>>(
      future: EmployeeRepository().listEmployeeRecords(company.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            icon: Icons.cloud_off_outlined,
            title: 'No pudimos cargar el resumen',
            subtitle: snapshot.error.toString(),
          );
        }

        final records = snapshot.data ?? const <EmployeeRecord>[];
        final active = records.where((r) => r.contract != null).toList();
        final salaries = active.fold<double>(
          0,
          (sum, record) => sum + record.contract!.monthlySalary,
        );
        final estimatedCost = active.fold<double>(
          0,
          (sum, record) =>
              sum +
              engine
                  .employmentCost(
                    record.contract!.monthlySalary,
                    includeReserveFund: true,
                  )
                  .total,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.apartment_rounded, color: Colors.white),
                      ),
                      const Spacer(),
                      if (company.ruc?.isNotEmpty ?? false)
                        Text(
                          'RUC ${company.ruc}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    company.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    company.city?.isNotEmpty ?? false
                        ? company.city!
                        : 'Panel de gestión laboral',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Empleados',
                    value: '${records.length}',
                    icon: Icons.groups_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Sueldos',
                    value: money(salaries),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricCard(
              label: 'Costo laboral mensual estimado',
              value: money(estimatedCost),
              icon: Icons.account_balance_wallet_outlined,
              wide: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Acciones rápidas',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Empleados y contratos',
                    subtitle: 'Datos personales, sueldo y beneficios',
                    onTap: onOpenEmployees,
                  ),
                  const Divider(),
                  _ActionTile(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Calcular un finiquito',
                    subtitle: 'Selecciona un empleado y la app completa sus datos',
                    onTap: onOpenSettlement,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PayrollTab extends StatelessWidget {
  const _PayrollTab({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final engine = const CalculationEngine();
    final theme = Theme.of(context);

    return FutureBuilder<List<EmployeeRecord>>(
      future: EmployeeRepository().listEmployeeRecords(company.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            icon: Icons.error_outline,
            title: 'No pudimos preparar la nómina',
            subtitle: snapshot.error.toString(),
          );
        }

        final records = (snapshot.data ?? const <EmployeeRecord>[])
            .where((record) => record.contract != null)
            .toList();

        if (records.isEmpty) {
          return const _Message(
            icon: Icons.receipt_long_outlined,
            title: 'Nómina sin empleados',
            subtitle: 'Agrega empleados con contrato para preparar el cálculo mensual.',
          );
        }

        final gross = records.fold<double>(
          0,
          (sum, record) => sum + record.contract!.monthlySalary,
        );
        final personalIess = records.fold<double>(
          0,
          (sum, record) => sum + engine.employeeIess(record.contract!.monthlySalary),
        );
        final employerIess = records.fold<double>(
          0,
          (sum, record) => sum + engine.employerIess(record.contract!.monthlySalary),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Nómina del mes',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Vista previa con sueldo base e IESS. Después agregaremos novedades, horas extra y cierre mensual.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 22),
            Text('Empleados', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            ...records.map((record) {
              final salary = record.contract!.monthlySalary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(child: Text(_initials(record.employee.fullName))),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.employee.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${record.contract!.position ?? 'Empleado'} · IESS ${money(engine.employeeIess(salary))}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money(salary - engine.employeeIess(salary)),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              money(value),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                fontSize: strong ? 17 : 14,
              ),
            ),
          ],
        ),
      );
}

class _SettlementTab extends StatelessWidget {
  const _SettlementTab({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<EmployeeRecord>>(
      future: EmployeeRepository().listEmployeeRecords(company.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            icon: Icons.error_outline,
            title: 'No pudimos cargar los empleados',
            subtitle: snapshot.error.toString(),
          );
        }

        final records = (snapshot.data ?? const <EmployeeRecord>[])
            .where((record) => record.contract != null)
            .toList();

        if (records.isEmpty) {
          return const _Message(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Aún no puedes calcular finiquitos',
            subtitle: 'Registra un empleado con contrato y su información se reutilizará automáticamente.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Finiquito',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Elige un empleado. Su fecha de ingreso, sueldo y modalidad de décimos ya están guardados.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.secondary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Solo tendrás que elegir causal, fecha de terminación y descuentos si existen.',
                      style: TextStyle(fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...records.map((record) {
              final contract = record.contract!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettlementCalculatorPage(
                          record: record,
                          companyRegion: company.region,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            child: Text(_initials(record.employee.fullName)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.employee.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${compactDate(contract.startDate)} · ${money(contract.monthlySalary)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.wide = false,
  });

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
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
