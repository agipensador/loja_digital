import 'package:app_loja_digital/common/notify_prompt.dart';
import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/staff_member.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Versão deste build. No release:
///   flutter build ... --dart-define=APP_VERSION=1.1.0
///     --dart-define=APP_NOTES="Pagamento por Pix mais rápido"
class AppRelease {
  AppRelease._();
  static const String version =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String notes = String.fromEnvironment('APP_NOTES');
}

/// Quando a equipe abre uma versão nova do app pela 1ª vez, pergunta:
/// "Atualizamos o app, quer avisar seus clientes?". A versão anunciada fica
/// em stores/{id}.announcedVersion, então só uma pessoa da equipe é
/// perguntada por versão.
class UpdateAnnouncer extends StatefulWidget {
  const UpdateAnnouncer({super.key, required this.child});
  final Widget child;

  @override
  State<UpdateAnnouncer> createState() => _UpdateAnnouncerState();
}

class _UpdateAnnouncerState extends State<UpdateAnnouncer> {
  static bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.watch<TenantManager>().store;
    final user = context.watch<UserManager>();
    if (_checked || store == null || !user.can(Perm.notifications)) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final doc = await Tenant.storeRef.get();
      final announced = doc.data()?['announcedVersion'] as String?;
      if (announced == AppRelease.version) return;
      // Loja nova: a 1ª versão não é "atualização".
      if (announced != null && mounted) {
        await NotifyPrompt.ask(
          context,
          question: 'Atualizamos o app (versão ${AppRelease.version}). '
              'Quer avisar seus clientes?',
          title: 'App atualizado!',
          body: AppRelease.notes.isNotEmpty
              ? AppRelease.notes
              : 'Atualize o app para ter as novidades e melhorias.',
        );
      }
      await Tenant.storeRef.update({'announcedVersion': AppRelease.version});
    } catch (e) {
      debugPrint('Aviso de atualização: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
