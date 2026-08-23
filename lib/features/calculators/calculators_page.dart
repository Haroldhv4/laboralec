import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../domain/calculation_engine.dart';
import 'settlement_calculator_page.dart';

class CalculatorsPage extends StatelessWidget {
  const CalculatorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final calculators = <_CalculatorItem>[
      _CalculatorItem(
        title: 'IESS y sueldo neto',
        subtitle: 'Aporte personal, patronal y neto estimado',
        icon: Icons.account_balance_outlined,
        page: const IessCalculatorPage(),
      ),
      _CalculatorItem(
        title: 'Décimo tercero',
        subtitle: 'Calcula el proporcional o provisión mensual',
        icon: Icons.card_giftcard_outlined,
        page: const ThirteenthCalculatorPage(),
      ),
      _CalculatorItem(
        title: 'Décimo cuarto',
        subtitle: 'SBU y proporcional según meses',
        icon: Icons.school_outlined,
        page: const FourteenthCalculatorPage(),
      ),
      _CalculatorItem(
        title: 'Vacaciones',
        subtitle: 'Valor de días pendientes por pagar',
        icon: Icons.beach_access_outlined,
        page: const VacationCalculatorPage(),
      ),
      _CalculatorItem(
        title: 'Horas extra',
        subtitle: 'Horas suplementarias 50 % y extraordinarias 100 %',
        icon: Icons.schedule_outlined,
        page: const OvertimeCalculatorPage(),
      ),
      _CalculatorItem(
        title: 'Costo de empleado',
        subtitle: 'Cuánto cuesta realmente una contratación',
        icon: Icons.business_center_outlined,
        page: const EmploymentCostCalculatorPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Calculadoras')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
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
                Icon(Icons.calculate_rounded, color: scheme.onPrimary, size: 34),
                const SizedBox(height: 22),
                Text(
                  'Calcula lo que necesitas, sin complicarte.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Herramientas laborales para Ecuador con parámetros base 2026.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _FeaturedCalculatorCard(
            title: 'Calculadora de finiquito',
            subtitle: 'Fechas + sueldo + causal. Nosotros calculamos los rubros proporcionales.',
            icon: Icons.assignment_turned_in_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettlementCalculatorPage(),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Calculadoras individuales',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Úsalas cuando solo quieres resolver una duda puntual.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.93,
            ),
            itemCount: calculators.length,
            itemBuilder: (context, index) {
              final item = calculators[index];
              return _CalculatorCard(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => item.page),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            'Los resultados son estimativos. Casos con contratos colectivos, remuneración variable, regímenes especiales u otras particularidades requieren revisión adicional.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class IessCalculatorPage extends StatefulWidget {
  const IessCalculatorPage({super.key});

  @override
  State<IessCalculatorPage> createState() => _IessCalculatorPageState();
}

class _IessCalculatorPageState extends State<IessCalculatorPage> {
  final _salary = TextEditingController(text: '650');
  final _engine = const CalculationEngine();

  @override
  void dispose() {
    _salary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salary = _value(_salary);
    final personal = _engine.employeeIess(salary);
    final employer = _engine.employerIess(salary);

    return _CalculatorScaffold(
      title: 'IESS y sueldo neto',
      description: 'Calcula los aportes referenciales de un trabajador privado bajo relación de dependencia.',
      icon: Icons.account_balance_outlined,
      children: [
        _MoneyInput(
          controller: _salary,
          label: 'Remuneración gravada',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 16),
        _ResultCard(
          title: 'Resultado mensual',
          totalLabel: 'Neto base estimado',
          total: salary - personal,
          rows: [
            _ResultLine('Remuneración', salary),
            _ResultLine('IESS personal · 9,45 %', -personal),
            _ResultLine('IESS patronal · 11,15 %', employer),
            _ResultLine('Aporte total IESS', personal + employer),
          ],
        ),
      ],
    );
  }
}

class ThirteenthCalculatorPage extends StatefulWidget {
  const ThirteenthCalculatorPage({super.key});

  @override
  State<ThirteenthCalculatorPage> createState() => _ThirteenthCalculatorPageState();
}

class _ThirteenthCalculatorPageState extends State<ThirteenthCalculatorPage> {
  final _salary = TextEditingController(text: '650');
  final _months = TextEditingController(text: '12');
  final _engine = const CalculationEngine();

  @override
  void dispose() {
    _salary.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salary = _value(_salary);
    final months = _value(_months).clamp(0, 12).toDouble();
    final amount = salary * months / 12;

    return _CalculatorScaffold(
      title: 'Décimo tercero',
      description: 'Para una remuneración fija, estima la parte proporcional según los meses equivalentes trabajados.',
      icon: Icons.card_giftcard_outlined,
      children: [
        _MoneyInput(
          controller: _salary,
          label: 'Remuneración mensual computable',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _months,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Meses equivalentes',
            prefixIcon: Icon(Icons.calendar_month_outlined),
            suffixText: '/ 12',
          ),
        ),
        const SizedBox(height: 16),
        _ResultCard(
          title: 'Décimo tercero estimado',
          totalLabel: 'Valor proporcional',
          total: amount,
          rows: [
            _ResultLine('Provisión por mes', _engine.thirteenthMonthly(salary)),
            _ResultLine('Meses considerados', months, isMoney: false),
          ],
        ),
      ],
    );
  }
}

class FourteenthCalculatorPage extends StatefulWidget {
  const FourteenthCalculatorPage({super.key});

  @override
  State<FourteenthCalculatorPage> createState() => _FourteenthCalculatorPageState();
}

class _FourteenthCalculatorPageState extends State<FourteenthCalculatorPage> {
  final _months = TextEditingController(text: '12');
  final _engine = const CalculationEngine();
  int _year = 2026;

  @override
  void dispose() {
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = _value(_months).clamp(0, 12).toDouble();
    final sbu = _engine.sbuForYear(_year);
    final amount = sbu * months / 12;

    return _CalculatorScaffold(
      title: 'Décimo cuarto',
      description: 'Estima el beneficio a partir del Salario Básico Unificado del año seleccionado.',
      icon: Icons.school_outlined,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _year,
          decoration: const InputDecoration(
            labelText: 'Año',
            prefixIcon: Icon(Icons.date_range_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 2024, child: Text('2024 · SBU $460')),
            DropdownMenuItem(value: 2025, child: Text('2025 · SBU $470')),
            DropdownMenuItem(value: 2026, child: Text('2026 · SBU $482')),
          ],
          onChanged: (value) => setState(() => _year = value ?? 2026),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _months,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Meses equivalentes',
            prefixIcon: Icon(Icons.calendar_month_outlined),
            suffixText: '/ 12',
          ),
        ),
        const SizedBox(height: 16),
        _ResultCard(
          title: 'Décimo cuarto estimado',
          totalLabel: 'Valor proporcional',
          total: amount,
          rows: [
            _ResultLine('SBU utilizado', sbu),
            _ResultLine('Provisión mensual', sbu / 12),
          ],
        ),
      ],
    );
  }
}

class VacationCalculatorPage extends StatefulWidget {
  const VacationCalculatorPage({super.key});

  @override
  State<VacationCalculatorPage> createState() => _VacationCalculatorPageState();
}

class _VacationCalculatorPageState extends State<VacationCalculatorPage> {
  final _salary = TextEditingController(text: '650');
  final _days = TextEditingController(text: '15');
  final _engine = const CalculationEngine();

  @override
  void dispose() {
    _salary.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salary = _value(_salary);
    final days = _value(_days).clamp(0, 365).toDouble();
    final value = _engine.vacationValue(salary, days);

    return _CalculatorScaffold(
      title: 'Vacaciones',
      description: 'Convierte días de vacaciones pendientes en un valor estimado usando la remuneración mensual.',
      icon: Icons.beach_access_outlined,
      children: [
        _MoneyInput(
          controller: _salary,
          label: 'Remuneración mensual',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _days,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Días pendientes',
            prefixIcon: Icon(Icons.sunny_snowing),
          ),
        ),
        const SizedBox(height: 16),
        _ResultCard(
          title: 'Vacaciones pendientes',
          totalLabel: 'Valor estimado',
          total: value,
          rows: [
            _ResultLine('Valor diario', salary / 30),
            _ResultLine('Días ingresados', days, isMoney: false),
          ],
        ),
      ],
    );
  }
}

class OvertimeCalculatorPage extends StatefulWidget {
  const OvertimeCalculatorPage({super.key});

  @override
  State<OvertimeCalculatorPage> createState() => _OvertimeCalculatorPageState();
}

class _OvertimeCalculatorPageState extends State<OvertimeCalculatorPage> {
  final _salary = TextEditingController(text: '650');
  final _supplementary = TextEditingController(text: '0');
  final _extraordinary = TextEditingController(text: '0');
  final _engine = const CalculationEngine();

  @override
  void dispose() {
    _salary.dispose();
    _supplementary.dispose();
    _extraordinary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salary = _value(_salary);
    final suppHours = _value(_supplementary).clamp(0, 999).toDouble();
    final extraHours = _value(_extraordinary).clamp(0, 999).toDouble();
    final supp = _engine.supplementaryHour(salary) * suppHours;
    final extra = _engine.extraordinaryHour(salary) * extraHours;

    return _CalculatorScaffold(
      title: 'Horas extra',
      description: 'Calcula horas suplementarias con recargo del 50 % y extraordinarias con recargo del 100 %.',
      icon: Icons.schedule_outlined,
      children: [
        _MoneyInput(
          controller: _salary,
          label: 'Remuneración mensual',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _supplementary,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Horas 50 %'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _extraordinary,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Horas 100 %'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ResultCard(
          title: 'Horas adicionales',
          totalLabel: 'Total estimado',
          total: supp + extra,
          rows: [
            _ResultLine('Hora ordinaria', _engine.hourlyRate(salary)),
            _ResultLine('Valor hora 50 %', _engine.supplementaryHour(salary)),
            _ResultLine('Subtotal 50 %', supp),
            _ResultLine('Valor hora 100 %', _engine.extraordinaryHour(salary)),
            _ResultLine('Subtotal 100 %', extra),
          ],
        ),
      ],
    );
  }
}

class EmploymentCostCalculatorPage extends StatefulWidget {
  const EmploymentCostCalculatorPage({super.key});

  @override
  State<EmploymentCostCalculatorPage> createState() => _EmploymentCostCalculatorPageState();
}

class _EmploymentCostCalculatorPageState extends State<EmploymentCostCalculatorPage> {
  final _salary = TextEditingController(text: '650');
  final _engine = const CalculationEngine();
  bool _includeReserve = false;

  @override
  void dispose() {
    _salary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salary = _value(_salary);
    final cost = _engine.employmentCost(
      salary,
      includeReserveFund: _includeReserve,
    );

    return _CalculatorScaffold(
      title: 'Costo de empleado',
      description: 'Mira cuánto puede representar mensualmente una contratación, más allá del sueldo acordado.',
      icon: Icons.business_center_outlined,
      children: [
        _MoneyInput(
          controller: _salary,
          label: 'Sueldo mensual',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir fondo de reserva'),
          subtitle: const Text('Actívalo cuando ya corresponda por antigüedad.'),
          value: _includeReserve,
          onChanged: (value) => setState(() => _includeReserve = value),
        ),
        const SizedBox(height: 8),
        _ResultCard(
          title: 'Costo mensual aproximado',
          totalLabel: 'Costo empresarial',
          total: cost.total,
          rows: [
            _ResultLine('Sueldo', cost.salary),
            _ResultLine('IESS patronal', cost.employerIess),
            _ResultLine('Provisión décimo tercero', cost.thirteenthProvision),
            _ResultLine('Provisión décimo cuarto', cost.fourteenthProvision),
            _ResultLine('Provisión vacaciones', cost.vacationProvision),
            if (_includeReserve) _ResultLine('Fondo de reserva', cost.reserveFund),
          ],
        ),
      ],
    );
  }
}

class _CalculatorScaffold extends StatelessWidget {
  const _CalculatorScaffold({
    required this.title,
    required this.description,
    required this.icon,
    required this.children,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
          const SizedBox(height: 18),
          Text(
            'Resultado referencial para orientación. Verifica condiciones particulares antes de realizar pagos o trámites oficiales.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCalculatorCard extends StatelessWidget {
  const _FeaturedCalculatorCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(icon, color: scheme.secondary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const SizedBox(height: 5),
                    Text(subtitle, style: const TextStyle(height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculatorCard extends StatelessWidget {
  const _CalculatorCard({required this.item, required this.onTap});

  final _CalculatorItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(item.icon, color: scheme.primary),
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.totalLabel,
    required this.total,
    required this.rows,
  });

  final String title;
  final String totalLabel;
  final double total;
  final List<_ResultLine> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 12),
                ...rows.map(
                  (line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text(line.label)),
                        Text(
                          line.isMoney ? money(line.value) : line.value.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 17),
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            child: Row(
              children: [
                Expanded(
                  child: Text(totalLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(
                  money(total),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyInput extends StatelessWidget {
  const _MoneyInput({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
    );
  }
}

class _CalculatorItem {
  const _CalculatorItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
}

class _ResultLine {
  const _ResultLine(this.label, this.value, {this.isMoney = true});

  final String label;
  final double value;
  final bool isMoney;
}

double _value(TextEditingController controller) =>
    double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
