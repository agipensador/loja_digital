import 'package:app_loja_digital/helpers/validators.dart';
import 'package:flutter/material.dart';
import 'package:app_loja_digital/models/user.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:provider/provider.dart';

class SignupScreen extends StatelessWidget {
  SignupScreen({super.key});

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final User user = User(
    name: '',
    email: '',
    password: '',
    confirmPassword: '',
    id: '',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
        centerTitle: true,
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
                    TextFormField(
                      decoration: const InputDecoration(hintText: 'Nome Completo'),
                      enabled: !userManager.loading,
                      validator: (String? name) {
                        if (name == null || name.isEmpty) {
                          return 'Campo obrigatório';
                        } else if (name.trim().split(' ').length <= 1) {
                          return 'Preencha seu Nome Completo';
                        }
                        return null;
                      },
                      onSaved: (name) => user.name = name ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(hintText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !userManager.loading,
                      validator: (String? email) {
                        if (email == null || email.isEmpty) {
                          return 'Campo obrigatório';
                        } else if (!emailValid(email)) {
                          return 'Email inválido';
                        }
                        return null;
                      },
                      onSaved: (email) => user.email = email ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(hintText: 'Senha'),
                      obscureText: true,
                      enabled: !userManager.loading,
                      validator: (String? pass) {
                        if (pass == null || pass.isEmpty) {
                          return 'Campo obrigatório';
                        } else if (pass.length < 6) {
                          return 'Senha muito curta (o mínimo 6)';
                        }
                        return null;
                      },
                      onSaved: (pass) => user.password = pass ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(hintText: 'Repita a Senha'),
                      obscureText: true,
                      enabled: !userManager.loading,
                      validator: (String? pass) {
                        if (pass == null || pass.isEmpty) {
                          return 'Campo obrigatório';
                        } else if (pass.length < 6) {
                          return 'Senha muito curta (o mínimo 6)';
                        }
                        return null;
                      },
                      onSaved: (pass) => user.confirmPassword = pass ?? '',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          disabledBackgroundColor: Theme.of(context).primaryColor.withAlpha(100),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: userManager.loading
                            ? null
                            : () {
                                if (formKey.currentState!.validate()) {
                                  formKey.currentState!.save();

                                  if (user.password != user.confirmPassword) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Senhas não coincidem!'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  userManager.signUp(
                                    user: user,
                                    onSuccess: () {
                                      Navigator.of(context).pop();
                                    },
                                    onFail: (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Falha ao cadastrar: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                                  );
                                }
                              },
                        child: userManager.loading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              )
                            : const Text(
                                'Criar conta',
                                style: TextStyle(fontSize: 18),
                              ),
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
}
