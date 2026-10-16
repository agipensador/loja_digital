// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String appOffline(String name) {
    return 'OOPS! THE $name APP IS OFFLINE RIGHT NOW. WE\'LL BE BACK SOON.';
  }

  @override
  String get noOrdersWhileOffline => 'Orders are unavailable in the meantime.';

  @override
  String get teamLogin => 'I\'m on the store team';

  @override
  String get chatTitle => 'Support';

  @override
  String chatGreeting(String store) {
    return 'Hi! I\'m the $store assistant. How can I help?';
  }

  @override
  String get notificationsTitle => 'Notifications';
}
