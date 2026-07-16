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

  Future<void> save() async {
    await _ref.set({
      'storeName': storeName,
      'primary': primary.toARGB32(),
      'background': background.toARGB32(),
      'menu': menu.toARGB32(),
    });
  }

  Future<void> discard() => _load();

  /// Cor de texto/ícone legível sobre uma cor de fundo.
  static Color onColor(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  Color get onMenu => onColor(menu);
}
