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
  String _region = 'costa_insular';
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
        region: _region,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva empresa')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configura tu empresa',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Estos datos nos permiten reutilizar información en nómina y finiquitos.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Datos básicos',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _tradeName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre comercial (opcional)',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ruc,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'RUC (opcional)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _region,
              decoration: const InputDecoration(
                labelText: 'Región laboral',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'costa_insular',
                  child: Text('Costa / Insular'),
                ),
                DropdownMenuItem(
                  value: 'sierra_amazonia',
                  child: Text('Sierra / Amazonía'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _region = value);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'La región se utiliza para el período del décimo cuarto.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
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
              icon: const Icon(Icons.check_rounded),
              label: Text(_loading ? 'Guardando...' : 'Crear empresa'),
            ),
          ],
        ),
      ),
    );
  }
}
