import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/brand_mark.dart';
import '../calculators/calculators_page.dart';
import '../calculators/settlement_calculator_page.dart';
import '../company/company_dashboard_page.dart';
import '../company/company_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Company>> _companies;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _companies = CompanyRepository().listCompanies();

  Future<void> _refresh() async {
    setState(_reload);
    await _companies;
  }

  Future<void> _createCompany() async {
    final company = await Navigator.of(context).push<Company>(
      MaterialPageRoute(builder: (_) => const CompanyFormPage()),
    );
    if (company != null && mounted) setState(_reload);
  }

  void _open(Widget page) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      );

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = user?.userMetadata?['full_name']?.toString().trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 38, showShadow: false),
            SizedBox(width: 11),
            Text('Laboral EC'),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(right: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => Scaffold.of(context).openDrawer(),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.secondaryContainer,
                  child: Text(
                    _initial(name.isEmpty ? user?.email ?? 'U' : name),
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCompany,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva empresa'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 112),
          children: [
            _WelcomeHero(
              firstName: firstName,
              onCalculators: () => _open(const CalculatorsPage()),
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Accesos rápidos',
              subtitle: 'Resuelve una consulta en segundos',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    title: 'Finiquito',
                    subtitle: 'Cálculo automático',
                    icon: Icons.assignment_turned_in_rounded,
                    accent: scheme.secondary,
                    onTap: () => _open(const SettlementCalculatorPage()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    title: 'Costo laboral',
                    subtitle: 'Antes de contratar',
                    icon: Icons.business_center_rounded,
                    accent: scheme.primary,
                    onTap: () => _open(const EmploymentCostCalculatorPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: _SectionHeader(
                    title: 'Mis empresas',
                    subtitle: 'Centros de trabajo guardados',
                  ),
                ),
                TextButton.icon(
                  onPressed: _createCompany,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Company>>(
              future: _companies,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(42),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _ErrorCard(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(_reload),
                  );
                }

                final companies = snapshot.data ?? const <Company>[];
                if (companies.isEmpty) {
                  return _EmptyCompanies(onTap: _createCompany);
                }

                return Column(
                  children: companies.map((company) {
                    final metadata = [
                      if (company.ruc?.isNotEmpty ?? false) 'RUC ${company.ruc}',
                      if (company.city?.isNotEmpty ?? false) company.city!,
                    ];
                    final region = company.region == 'sierra_amazonia'
                        ? 'Sierra / Amazonía'
                        : 'Costa / Insular';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(CompanyDashboardPage(company: company)),
                          child: Padding(
                            padding: const EdgeInsets.all(17),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        scheme.primaryContainer,
                                        scheme.secondaryContainer,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(Icons.apartment_rounded, color: scheme.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        metadata.isEmpty ? region : '${metadata.join(' · ')} · $region',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(Icons.arrow_forward_rounded, size: 19, color: scheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String value) => value.trim().isEmpty ? 'U' : value.trim()[0].toUpperCase();
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.firstName, required this.onCalculators});

  final String firstName;
  final VoidCallback onCalculators;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .16),
            blurRadius: 30,
            offset: const Offset(0, 14),
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
                    colors: [scheme.primary, const Color(0xFF0B5862), scheme.secondary],
                    stops: const [0, .58, 1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -65,
              right: -45,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: 80,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .045),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'GESTIÓN LABORAL · ECUADOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    firstName.isEmpty
                        ? 'Todo lo laboral,\nen un solo lugar.'
                        : 'Hola, $firstName.\n¿Qué necesitas hoy?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      height: 1.03,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'Controla empleados, nómina, obligaciones y finiquitos con una experiencia más simple.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .84),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                    ),
                    onPressed: onCalculators,
                    icon: const Icon(Icons.calculate_rounded),
                    label: const Text('Abrir calculadoras'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
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
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const Spacer(),
                  Icon(Icons.north_east_rounded, size: 17, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCompanies extends StatelessWidget {
  const _EmptyCompanies({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.domain_add_rounded, color: scheme.secondary, size: 31),
              ),
              const SizedBox(height: 17),
              const Text('Crea tu primera empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Registra empleados una sola vez y reutiliza sus datos en nómina, vacaciones, horas extra y finiquitos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: scheme.errorContainer,
              child: Icon(Icons.error_outline_rounded, color: scheme.error),
            ),
            const SizedBox(height: 14),
            const Text('No pudimos cargar tus empresas', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
