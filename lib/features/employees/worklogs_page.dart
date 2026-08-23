import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import 'employee_activity_page.dart';

class WorklogsPage extends StatelessWidget {
  const WorklogsPage({super.key, required this.company});
  final Company company;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novedades laborales')),
      body: FutureBuilder<List<EmployeeRecord>>(
        future: EmployeeRepository().listEmployeeRecords(company.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center)));
          }
          final records = (snapshot.data ?? const <EmployeeRecord>[])
              .where((item) => item.contract != null)
              .toList();
          if (records.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('Agrega empleados con contrato para registrar horas extra y vacaciones.', textAlign: TextAlign.center)));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text('Horas extra y vacaciones', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Selecciona un empleado para registrar novedades que luego se reutilizan en nómina y finiquito.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              ...records.map((record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        leading: CircleAvatar(child: Text(_initials(record.employee.fullName))),
                        title: Text(record.employee.fullName, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('${record.contract!.position ?? 'Empleado'} · ${money(record.contract!.monthlySalary)}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EmployeeActivityPage(record: record)),
                        ),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
