import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Aparência personalizável da loja (nome + cores), salva em config/appearance.
/// O admin edita e o app inteiro se ajusta.
class ThemeManager extends ChangeNotifier {
  ThemeManager() {
    _load();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Valores padrão (a loja atual).
  String storeName = 'Loja Digital';
  Color primary = const Color(0xFF047D8D);
  Color background = const Color(0xFFB98A82);
  Color menu = const Color(0xFFCBECF1);

  /// Últimas cores usadas pelo admin (máx. 4).
  List<Color> recentColors = [];

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('config').doc('appearance');

  Future<void> _load() async {
    try {
      final doc = await _ref.get();
      final data = doc.data();
      if (data != null) {
        storeName = (data['storeName'] ?? storeName) as String;
        primary = _color(data['primary'], primary);
        background = _color(data['background'], background);
        menu = _color(data['menu'], menu);
        final recent = data['recentColors'];
        if (recent is List) {
          recentColors =
              recent.whereType<int>().map((v) => Color(v)).toList();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar aparência: $e');
    }
  }

  Color _color(dynamic value, Color fallback) =>
      value is int ? Color(value) : fallback;

  // Setters de pré-visualização (aplicam na hora, sem persistir).
  void setStoreName(String v) {
    storeName = v;
    notifyListeners();
  }

  void setPrimary(Color c) {
    primary = c;
    notifyListeners();
  }

  void setBackground(Color c) {
    background = c;
    notifyListeners();
  }

  void setMenu(Color c) {
    menu = c;
    notifyListeners();
  }

  /// Registra uma cor como "usada recentemente" (dedup, máx. 4) e persiste.
  void pushRecent(Color c) {
    recentColors.removeWhere((x) => x.toARGB32() == c.toARGB32());
    recentColors.insert(0, c);
    if (recentColors.length > 4) {
      recentColors = recentColors.sublist(0, 4);
    }
    notifyListeners();
    _ref.set(
      {'recentColors': recentColors.map((c) => c.toARGB32()).toList()},
      SetOptions(merge: true),
    );
  }

  Future<void> save() async {
    await _ref.set({
      'storeName': storeName,
      'primary': primary.toARGB32(),
      'background': background.toARGB32(),
      'menu': menu.toARGB32(),
      'recentColors': recentColors.map((c) => c.toARGB32()).toList(),
    });
  }

  Future<void> discard() => _load();

  /// Cor de texto/ícone legível sobre uma cor de fundo (preto/branco).
  static Color onColor(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  /// Cor do texto do menu — automática, sempre contrastando com o fundo.
  Color get onMenu => onColor(menu);

  /// Cor de destaque do menu (item selecionado / "Sair"): usa a cor
  /// principal se ela contrastar com o menu; senão, a cor de contraste.
  Color get menuAccent {
    final diff = (primary.computeLuminance() - menu.computeLuminance()).abs();
    return diff > 0.25 ? primary : onMenu;
  }
}
