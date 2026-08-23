import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';

class CompanyFormPage extends StatefulWidget {
  const CompanyFormPage({super.key});

  @override
  State<CompanyFormPage> createState() => _CompanyFormPageState();
}

class _CompanyFormPageState extends State<CompanyFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _legalName = TextEditingController();
  final _tradeName = TextEditingController();
  final _ruc = TextEditingController();
  final _province = TextEditingController();
  final _city = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _legalName.dispose();
    _tradeName.dispose();
    _ruc.dispose();
    _province.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final company = await CompanyRepository().createCompany(
        legalName: _legalName.text,
        tradeName: _tradeName.text,
        ruc: _ruc.text,
        province: _province.text,
        city: _city.text,
      );
      if (mounted) Navigator.pop<Company>(context, company);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear la empresa: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva empresa')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Datos básicos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Podrás completar o corregir estos datos más adelante.'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _legalName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Razón social o nombre legal',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Este campo es obligatorio'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tradeName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre comercial (opcional)',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ruc,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'RUC (opcional)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _province,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Provincia'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_loading ? 'Guardando...' : 'Crear empresa'),
            ),
          ],
        ),
      ),
    );
  }
}
