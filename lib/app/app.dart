import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../features/auth/auth_gate.dart';

class LaboralEcApp extends StatelessWidget {
  const LaboralEcApp({super.key, required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laboral EC',
      theme: AppTheme.light,
      home: configured
          ? const AuthGate()
          : const _MissingConfigurationPage(),
    );
  }
}

class _MissingConfigurationPage extends StatelessWidget {
  const _MissingConfigurationPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    'Falta configurar Supabase',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ejecuta la app con SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY mediante --dart-define.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
