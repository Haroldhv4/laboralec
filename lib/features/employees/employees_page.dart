import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../domain/calculation_engine.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key, required this.company});
  final Company company;

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late Future<List<EmployeeRecord>> _records;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _records = EmployeeRepository().listEmployeeRecords(widget.company.id);
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EmployeeFormPage(company: widget.company)),
    );
    if (created == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmployeeRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _CenteredMessage(
            icon: Icons.error_outline,
            title: 'No pudimos cargar empleados',
            subtitle: snapshot.error.toString(),
            actionLabel: 'Reintentar',
            onAction: () => setState(_reload),
          );
        }
        final records = snapshot.data ?? const <EmployeeRecord>[];
        if (records.isEmpty) {
          return _CenteredMessage(
            icon: Icons.group_add_outlined,
            title: 'Aún no hay empleados',
            subtitle: 'Registra el primero para empezar a controlar sueldo, beneficios y finiquito.',
            actionLabel: 'Agregar empleado',
            onAction: _add,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _records;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: records.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Agregar empleado'),
                  ),
                );
              }
              final record = records[index - 1];
              final contract = record.contract;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    leading: CircleAvatar(child: Text(_initials(record.employee.fullName))),
                    title: Text(record.employee.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      contract == null
                          ? record.employee.identificationNumber
                          : '${contract.position ?? 'Empleado'} · ${money(contract.monthlySalary)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EmployeeDetailPage(record: record)),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class EmployeeFormPage extends StatefulWidget {
  const EmployeeFormPage({super.key, required this.company});
  final Company company;

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _names = TextEditingController();
  final _lastNames = TextEditingController();
  final _position = TextEditingController();
  final _salary = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _weeklyHours = TextEditingController(text: '40');
  DateTime _startDate = DateTime.now();
  String _thirteenth = 'monthly';
  String _fourteenth = 'monthly';
  String _reserve = 'iess';
  bool _loading = false;

  @override
  void dispose() {
    for (final controller in [_id, _names, _lastNames, _position, _salary, _email, _phone, _weeklyHours]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final salary = double.tryParse(_salary.text.replaceAll(',', '.')) ?? 0;
    final weeklyHours = double.tryParse(_weeklyHours.text.replaceAll(',', '.')) ?? 40;
    setState(() => _loading = true);
    try {
      await EmployeeRepository().createEmployee(
        companyId: widget.company.id,
        identificationNumber: _id.text,
        firstNames: _names.text,
        lastNames: _lastNames.text,
        position: _position.text,
        monthlySalary: salary,
        startDate: _startDate,
        weeklyHours: weeklyHours,
        email: _email.text,
        phone: _phone.text,
        thirteenthPaymentMode: _thirteenth,
        fourteenthPaymentMode: _fourteenth,
        reserveFundPaymentMode: _reserve,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo empleado')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _field(_id, 'Cédula', Icons.badge_outlined, keyboard: TextInputType.number, required: true),
            const SizedBox(height: 12),
            _field(_names, 'Nombres', Icons.person_outline, required: true),
            const SizedBox(height: 12),
            _field(_lastNames, 'Apellidos', Icons.person_outline, required: true),
            const SizedBox(height: 12),
            _field(_position, 'Cargo', Icons.work_outline, required: true),
            const SizedBox(height: 12),
            _field(_salary, 'Sueldo mensual', Icons.payments_outlined, keyboard: const TextInputType.numberWithOptions(decimal: true), required: true, numericPositive: true),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFDDE1EA))),
              tileColor: Colors.white,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Fecha de ingreso'),
              subtitle: Text(compactDate(_startDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            _field(_weeklyHours, 'Horas semanales', Icons.schedule_outlined, keyboard: const TextInputType.numberWithOptions(decimal: true), numericPositive: true),
            const SizedBox(height: 12),
            _field(_email, 'Correo (opcional)', Icons.mail_outline, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_phone, 'Teléfono (opcional)', Icons.phone_outlined, keyboard: TextInputType.phone),
            const SizedBox(height: 22),
            const Text('Beneficios', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _thirteenth,
              decoration: const InputDecoration(labelText: 'Décimo tercero'),
              items: const [DropdownMenuItem(value: 'monthly', child: Text('Mensualizado')), DropdownMenuItem(value: 'accumulated', child: Text('Acumulado'))],
              onChanged: (value) => setState(() => _thirteenth = value ?? 'monthly'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fourteenth,
              decoration: const InputDecoration(labelText: 'Décimo cuarto'),
              items: const [DropdownMenuItem(value: 'monthly', child: Text('Mensualizado')), DropdownMenuItem(value: 'accumulated', child: Text('Acumulado'))],
              onChanged: (value) => setState(() => _fourteenth = value ?? 'monthly'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reserve,
              decoration: const InputDecoration(labelText: 'Fondo de reserva'),
              items: const [DropdownMenuItem(value: 'iess', child: Text('Acumular en IESS')), DropdownMenuItem(value: 'monthly', child: Text('Pago mensual'))],
              onChanged: (value) => setState(() => _reserve = value ?? 'iess'),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_loading ? 'Guardando...' : 'Guardar empleado'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard, bool required = false, bool numericPositive = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        if (required && (value?.trim().isEmpty ?? true)) return 'Campo obligatorio';
        if (numericPositive && (double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0) <= 0) return 'Ingresa un valor mayor a 0';
        return null;
      },
    );
  }
}

class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({super.key, required this.record});
  final EmployeeRecord record;

  @override
  Widget build(BuildContext context) {
    final contract = record.contract;
    final engine = const CalculationEngine();
    final cost = contract == null ? null : engine.employmentCost(contract.monthlySalary, includeReserveFund: true);
    return Scaffold(
      appBar: AppBar(title: Text(record.employee.fullName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.employee.fullName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Cédula ${record.employee.identificationNumber}'),
                  if (contract?.position != null) Text(contract!.position!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (contract == null)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Este empleado no tiene un contrato registrado.')))
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _detail('Sueldo', money(contract.monthlySalary)),
                    _detail('Ingreso', compactDate(contract.startDate)),
                    _detail('Jornada', '${contract.weeklyHours.toStringAsFixed(0)} h/semana'),
                    _detail('IESS personal estimado', money(engine.employeeIess(contract.monthlySalary))),
                    _detail('Costo mensual estimado', money(cost!.total)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.title, required this.subtitle, required this.actionLabel, required this.onAction});
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
