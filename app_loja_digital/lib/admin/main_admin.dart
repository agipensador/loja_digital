import 'package:app_loja_digital/admin/admin_dashboard.dart';
import 'package:app_loja_digital/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// Painel da PLATAFORMA (admin master) — web, separado dos apps das lojas.
///
///   flutter run -d chrome -t lib/admin/main_admin.dart
///   flutter build web -t lib/admin/main_admin.dart --output build/admin
///
/// Só entra quem tem o documento platform/superadmins/{uid} (criado pelo
/// console do Firebase). As rules dão ao superadmin acesso a todas as lojas.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  const useEmulators = bool.fromEnvironment('USE_EMULATORS');
  if (useEmulators) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }
  Intl.defaultLocale = 'pt_BR';
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inforizz — Painel da plataforma',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B7A8A),
        useMaterial3: true,
      ),
      home: const _AdminGate(),
    );
  }
}

class _AdminGate extends StatelessWidget {
  const _AdminGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, auth) {
        final user = auth.data;
        if (user == null) return const _AdminLogin();
        return FutureBuilder<bool>(
          future: FirebaseFirestore.instance
              .doc('platform/superadmins/items/${user.uid}')
              .get()
              .then((d) => d.exists)
              .catchError((_) => false),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (snap.data != true) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Acesso restrito à equipe da plataforma.'),
                      TextButton(
                        onPressed: FirebaseAuth.instance.signOut,
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const AdminDashboard();
          },
        );
      },
    );
  }
}

class _AdminLogin extends StatefulWidget {
  const _AdminLogin();

  @override
  State<_AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<_AdminLogin> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Painel da plataforma',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'E-mail')),
                  TextField(
                      controller: _pass,
                      obscureText: true,
                      onSubmitted: (_) => _login(),
                      decoration: const InputDecoration(labelText: 'Senha')),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _login, child: const Text('Entrar')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
