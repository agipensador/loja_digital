// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String appOffline(String name) {
    return 'OPS! O APP $name ESTÁ FORA DO AR NO MOMENTO. RETORNAMOS EM BREVE.';
  }

  @override
  String get noOrdersWhileOffline =>
      'Enquanto isso, não é possível fazer pedidos.';

  @override
  String get teamLogin => 'Sou da equipe da loja';

  @override
  String get chatTitle => 'Atendimento';

  @override
  String chatGreeting(String store) {
    return 'Olá! Sou o assistente da $store. Como posso ajudar?';
  }

  @override
  String get notificationsTitle => 'Notificações';
}
