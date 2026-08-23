import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../domain/calculation_engine.dart';

class CalculatorsPage extends StatefulWidget {
  const CalculatorsPage({super.key});

  @override
  State<CalculatorsPage> createState() => _CalculatorsPageState();
}

class _CalculatorsPageState extends State<CalculatorsPage> {
  final _salary = TextEditingController(text: '650');
  final _supplementaryHours = TextEditingController(text: '0');
  final _extraordinaryHours = TextEditingController(text: '0');
  bool _includeReserve = false;
  final _engine = const CalculationEngine();

  @override
  void dispose() {
    _salary.dispose();
    _supplementaryHours.dispose();
    _extraordinaryHours.dispose();
    super.dispose();
  }

  double get salary => double.tryParse(_salary.text.replaceAll(',', '.')) ?? 0;
  double get supplementary => double.tryParse(_supplementaryHours.text.replaceAll(',', '.')) ?? 0;
  double get extraordinary => double.tryParse(_extraordinaryHours.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = _engine.employmentCost(salary, includeReserveFund: _includeReserve);
    final employeeIess = _engine.employeeIess(salary);
    final netBase = salary - employeeIess;
    final suppValue = _engine.supplementaryHour(salary) * supplementary;
    final extraValue = _engine.extraordinaryHour(salary) * extraordinary;

    return Scaffold(
      appBar: AppBar(title: const Text('Calculadoras')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Simula antes de decidir',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text('Valores referenciales para el sector privado en Ecuador. Parámetros base 2026.'),
          const SizedBox(height: 22),
          TextField(
            controller: _salary,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Sueldo mensual',
              prefixText: '\$ ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(icon: Icons.account_balance_outlined, title: 'Sueldo e IESS'),
                  const SizedBox(height: 14),
                  _row('Aporte personal IESS 9,45 %', money(employeeIess)),
                  _row('Neto base estimado', money(netBase), strong: true),
                  const Divider(height: 26),
                  _row('Aporte patronal 11,15 %', money(_engine.employerIess(salary))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(icon: Icons.savings_outlined, title: 'Beneficios y provisiones'),
                  const SizedBox(height: 14),
                  _row('Décimo tercero mensual', money(_engine.thirteenthMonthly(salary))),
                  _row('Décimo cuarto mensual', money(_engine.fourteenthMonthly())),
                  _row('Vacaciones (provisión)', money(_engine.vacationMonthlyProvision(salary))),
                  _row('Fondo de reserva 8,33 %', money(_engine.reserveFund(salary))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(icon: Icons.schedule_outlined, title: 'Horas adicionales'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _supplementaryHours,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Horas 50 %'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _extraordinaryHours,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Horas 100 %'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _row('Valor hora suplementaria', money(_engine.supplementaryHour(salary))),
                  _row('Valor hora extraordinaria', money(_engine.extraordinaryHour(salary))),
                  const Divider(height: 26),
                  _row('Total horas ingresadas', money(suppValue + extraValue), strong: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(icon: Icons.business_center_outlined, title: 'Costo de contratar'),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir fondo de reserva'),
                    subtitle: const Text('Actívalo cuando ya corresponda por antigüedad.'),
                    value: _includeReserve,
                    onChanged: (value) => setState(() => _includeReserve = value),
                  ),
                  const Divider(height: 20),
                  _row('Sueldo', money(cost.salary)),
                  _row('IESS patronal', money(cost.employerIess)),
                  _row('Décimo tercero', money(cost.thirteenthProvision)),
                  _row('Décimo cuarto', money(cost.fourteenthProvision)),
                  _row('Vacaciones', money(cost.vacationProvision)),
                  if (_includeReserve) _row('Fondo de reserva', money(cost.reserveFund)),
                  const Divider(height: 26),
                  _row('Costo mensual estimado', money(cost.total), strong: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Estos resultados son orientativos y no sustituyen una revisión laboral cuando existen contratos colectivos, regímenes especiales o circunstancias no contempladas.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ],
    );
  }
}
