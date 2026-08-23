import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/brand_mark.dart';
import '../calculators/calculators_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;

    if (!email.contains('@') || password.length < 6) {
      _message('Ingresa un correo válido y una contraseña de al menos 6 caracteres.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_register) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (response.session == null) {
          _message('Cuenta creada. Confirma el correo para continuar.');
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      _message(error.message);
    } catch (error) {
      _message('No pudimos completar la operación: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -100,
            child: _GlowCircle(size: 260, color: scheme.secondary.withValues(alpha: .09)),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: _GlowCircle(size: 300, color: scheme.primary.withValues(alpha: .07)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(child: BrandMark(size: 82)),
                      const SizedBox(height: 25),
                      Text(
                        'Laboral EC',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _register
                            ? 'Crea tu espacio de trabajo y empieza a organizar tu empresa.'
                            : 'La gestión laboral de tu negocio, en un solo lugar.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _register ? 'Crear cuenta' : 'Bienvenido de nuevo',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _register
                                    ? 'Tus empresas y empleados quedarán vinculados a esta cuenta.'
                                    : 'Ingresa para continuar con tus empresas.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                              ),
                              const SizedBox(height: 13),
                              TextField(
                                controller: _password,
                                obscureText: _hidePassword,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _loading ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(_register ? 'Crear mi cuenta' : 'Ingresar'),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => setState(() => _register = !_register),
                                child: Text(
                                  _register
                                      ? 'Ya tengo una cuenta'
                                      : 'Crear una cuenta nueva',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('o continúa sin cuenta', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CalculatorsPage()),
                        ),
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Abrir calculadoras laborales'),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: scheme.secondary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Puedes calcular sin registrarte. La cuenta solo es necesaria para guardar información.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
