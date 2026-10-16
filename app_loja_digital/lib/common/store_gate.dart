import 'package:app_loja_digital/l10n/app_localizations.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Loja suspensa (mensalidade vencida + carência): o cliente vê só o aviso
/// de "fora do ar"; a equipe continua entrando (com uma faixa no topo) para
/// conseguir pagar e reativar a loja.
class StoreGate extends StatefulWidget {
  const StoreGate({super.key, required this.child, required this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<StoreGate> createState() => _StoreGateState();
}

class _StoreGateState extends State<StoreGate> {
  /// Enquanto a tela de login está aberta (para a equipe entrar).
  bool _loginOpen = false;

  Future<void> _openLogin() async {
    setState(() => _loginOpen = true);
    await widget.navigatorKey.currentState?.pushNamed('/login');
    if (mounted) setState(() => _loginOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final tenant = context.watch<TenantManager>();
    if (tenant.canSell) return child;

    final isTeam = context.watch<UserManager>().adminEnabled;
    final name = tenant.store?.name.isNotEmpty == true
        ? tenant.store!.name
        : context.watch<ThemeManager>().storeName;

    if (!isTeam) {
      return Stack(
        children: <Widget>[
          child,
          if (!_loginOpen)
            Positioned.fill(child: _OfflineScreen(name, onTeamLogin: _openLogin)),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Material(
          color: Colors.red.shade700,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: const <Widget>[
                  Icon(Icons.warning_amber, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Loja fora do ar para os clientes: mensalidade em '
                      'atraso. Pague em Perfil → Assinatura para reativar.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen(this.name, {required this.onTeamLogin});

  final String name;
  final VoidCallback onTeamLogin;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.cloud_off, size: 72, color: primary),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)
                      .appOffline(name.toUpperCase()),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).noOrdersWhileOffline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                // A equipe precisa conseguir entrar para regularizar.
                TextButton(
                  onPressed: onTeamLogin,
                  child: Text(AppLocalizations.of(context).teamLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
