import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey =
  String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw Exception(
      'Faltan SUPABASE_URL o SUPABASE_PUBLISHABLE_KEY',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const LaboralEcApp());
}

final supabase = Supabase.instance.client;

class LaboralEcApp extends StatelessWidget {
  const LaboralEcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laboral EC',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          return const LoginPage();
        }

        return const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool registerMode = false;

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Ingresa correo y contraseña');
      return;
    }

    if (password.length < 6) {
      showMessage('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      if (registerMode) {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (response.session == null) {
          showMessage(
            'Cuenta creada. Revisa tu correo para confirmar tu cuenta.',
          );
        } else {
          showMessage('Cuenta creada correctamente');
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (error) {
      showMessage('Error: $error');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.business_center,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Laboral EC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    registerMode
                        ? 'Crea tu cuenta'
                        : 'Tu asistente laboral para Ecuador',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: loading ? null : submit,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        registerMode
                            ? 'Crear cuenta'
                            : 'Ingresar',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                      setState(() {
                        registerMode = !registerMode;
                      });
                    },
                    child: Text(
                      registerMode
                          ? 'Ya tengo una cuenta'
                          : 'Crear una cuenta',
                    ),
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;

  List<Map<String, dynamic>> companies = [];

  @override
  void initState() {
    super.initState();

    loadCompanies();
  }

  Future<void> loadCompanies() async {
    try {
      final response = await supabase
          .from('companies')
          .select()
          .order('created_at');

      if (!mounted) return;

      setState(() {
        companies = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('Error cargando empresas: $error');
    }
  }

  Future<void> createCompany() async {
    final nameController = TextEditingController();
    final rucController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nueva empresa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rucController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'RUC (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final companyName = nameController.text.trim();

    if (companyName.isEmpty) {
      showMessage('Debes ingresar un nombre');
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('No existe una sesión activa');
      return;
    }

    try {
      await supabase.from('companies').insert({
        'owner_id': user.id,
        'legal_name': companyName,
        'trade_name': companyName,
        'ruc': rucController.text.trim().isEmpty
            ? null
            : rucController.text.trim(),
      }); 

      showMessage('Empresa creada correctamente');

      await loadCompanies();
    } catch (error) {
      showMessage('Error creando empresa: $error');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboral EC'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createCompany,
        icon: const Icon(Icons.add),
        label: const Text('Empresa'),
      ),
      body: RefreshIndicator(
        onRefresh: loadCompanies,
        child: loading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : companies.isEmpty
            ? ListView(
          children: [
            const SizedBox(height: 120),
            const Icon(
              Icons.business_outlined,
              size: 90,
            ),
            const SizedBox(height: 24),
            const Text(
              'Todavía no tienes empresas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Presiona + Empresa para comenzar.',
              textAlign: TextAlign.center,
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final company = companies[index];

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.business),
                ),
                title: Text(
                  company['trade_name'] ??
                      company['legal_name'] ??
                      'Empresa',
                ),
                subtitle: Text(
                  company['ruc'] == null
                      ? 'Sin RUC registrado'
                      : 'RUC: ${company['ruc']}',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}