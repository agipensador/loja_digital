import 'package:app_loja_digital/models/user.dart' as app;
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

/// Conta de demonstração exibida na tela de login.
class _TestAccount {
  const _TestAccount({
    required this.label,
    required this.name,
    required this.email,
    required this.password,
    this.admin = false,
  });

  final String label;
  final String name;
  final String email;
  final String password;
  final bool admin;
}

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  static const List<_TestAccount> _testAccounts = [
    _TestAccount(
      label: 'Admin (gerencia a loja)',
      name: 'Admin',
      email: 'admin@lojadigital.com',
      password: '123456',
      admin: true,
    ),
    _TestAccount(
      label: 'Cliente (compra)',
      name: 'Cliente Teste',
      email: 'cliente@lojadigital.com',
      password: '123456',
    ),
  ];

  bool emailValid(String email) {
    final RegExp regex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return regex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar'),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/signup');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('CRIAR CONTA', style: TextStyle(fontSize: 14)),
          )
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Form(
            key: formKey,
            child: Consumer<UserManager>(
              builder: (_, userManager, __) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                Theme.of(context).primaryColor.withAlpha(80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Contas para teste',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          for (final account in _testAccounts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${account.admin ? "Admin" : "Cliente"}: '
                                '${account.email}  ·  senha: ${account.password}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Text('Toque num cartão abaixo para entrar.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: emailController,
                      enabled: !userManager.loading,
                      decoration: const InputDecoration(hintText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      validator: (String? email) {
                        if (email == null || !emailValid(email)) {
                          return 'E-mail inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passController,
                      enabled: !userManager.loading,
                      decoration: const InputDecoration(hintText: 'Senha'),
                      autocorrect: false,
                      obscureText: true,
                      validator: (String? pass) {
                        if (pass == null || pass.isEmpty || pass.length < 6) {
                          return 'Senha inválida (mínimo 6 caracteres)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          disabledBackgroundColor:
                              Theme.of(context).primaryColor.withAlpha(100),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: userManager.loading
                            ? null
                            : () {
                                if (formKey.currentState!.validate()) {
                                  _signIn(context);
                                }
                              },
                        child: userManager.loading
                            ? const CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              )
                            : const Text('Entrar',
                                style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const Text(
                      'Contas de teste (toque para entrar)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final account in _testAccounts)
                      Card(
                        color: Theme.of(context).primaryColor.withAlpha(20),
                        child: ListTile(
                          leading: Icon(
                            account.admin
                                ? Icons.admin_panel_settings
                                : Icons.person,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(account.label),
                          subtitle: Text(
                            '${account.email}\nsenha: ${account.password}',
                          ),
                          isThreeLine: true,
                          enabled: !userManager.loading,
                          onTap: () => _useTestAccount(context, account),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context) {
    return context.read<UserManager>().signIn(
          app.User(
            name: '',
            email: emailController.text,
            password: passController.text,
            confirmPassword: '',
            id: '',
          ),
          onFail: (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Falha ao entrar: $e'),
                backgroundColor: Colors.red,
              ),
            );
          },
          onSuccess: (_) {
            Navigator.of(context).pop();
          },
        );
  }

  /// Entra com a conta de teste; se ela ainda não existir, cria na hora.
  /// A conta admin é promovida a administrador automaticamente.
  Future<void> _useTestAccount(
      BuildContext context, _TestAccount account) async {
    emailController.text = account.email;
    passController.text = account.password;

    final userManager = context.read<UserManager>();

    await userManager.signIn(
      app.User(
        name: account.name,
        email: account.email,
        password: account.password,
        confirmPassword: account.password,
        id: '',
      ),
      onFail: (_) {},
      onSuccess: (_) {},
    );

    if (!userManager.isLoggedIn) {
      // conta não existe ainda -> cria
      await userManager.signUp(
        user: app.User(
          name: account.name,
          email: account.email,
          password: account.password,
          confirmPassword: account.password,
          id: '',
        ),
        onFail: (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Falha: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onSuccess: () {},
      );
    }

    if (account.admin && userManager.isLoggedIn) {
      await userManager.makeCurrentUserAdmin();
    }

    if (userManager.isLoggedIn && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
