import 'dart:async';

import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/services/usage_service.dart';
import 'package:flutter/foundation.dart';

/// Uso da loja no mês (visitas e armazenamento), só para a equipe — as rules
/// não deixam cliente ler `stats/`.
class UsageManager extends ChangeNotifier {
  int visits = 0;
  int storageBytes = 0;

  bool _team = false;
  StreamSubscription<int>? _visitsSub;
  StreamSubscription<int>? _storageSub;

  UsageManager updateUser(UserManager userManager) {
    final team = userManager.adminEnabled;
    if (team == _team) return this;
    _team = team;
    _visitsSub?.cancel();
    _storageSub?.cancel();
    if (team) {
      _visitsSub = UsageService.visitsThisMonth().listen((v) {
        visits = v;
        notifyListeners();
      }, onError: (Object e) => debugPrint('Erro no uso (visitas): $e'));
      _storageSub = UsageService.storageBytes().listen((b) {
        storageBytes = b;
        notifyListeners();
      }, onError: (Object e) => debugPrint('Erro no uso (fotos): $e'));
    }
    return this;
  }

  UsageReport report(Plan plan, int products) => UsageReport(
        plan: plan,
        visits: visits,
        products: products,
        storageBytes: storageBytes,
      );

  @override
  void dispose() {
    _visitsSub?.cancel();
    _storageSub?.cancel();
    super.dispose();
  }
}
