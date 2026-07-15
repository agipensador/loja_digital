import 'package:app_loja_digital/models/section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HomeManager extends ChangeNotifier {
  HomeManager() {
    _loadSections();
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final List<Section> _sections = [];

  /// Cópia de trabalho usada enquanto o admin edita.
  final List<Section> _editingSections = [];

  bool editing = false;
  bool loading = false;
  String? error;

  /// Na visualização, ignora seções sem imagens (evita "buracos" na home).
  List<Section> get sections => editing
      ? _editingSections
      : _sections.where((s) => s.items.isNotEmpty).toList();

  Future<void> _loadSections() async {
    final snap = await firestore
        .collection('home')
        .orderBy('pos')
        .get();

    _sections
      ..clear()
      ..addAll(snap.docs.map((d) => Section.fromDocument(d)));

    notifyListeners();
  }

  void addSection(Section section) {
    _editingSections.add(section);
    notifyListeners();
  }

  void removeSection(Section section) {
    _editingSections.remove(section);
    notifyListeners();
  }

  void enterEditing() {
    editing = true;
    _editingSections
      ..clear()
      ..addAll(_sections.map((s) => s.clone()));
    notifyListeners();
  }

  Future<void> saveEditing() async {
    error = null;

    // Valida: toda seção precisa de ao menos uma imagem.
    for (final section in _editingSections) {
      if (!section.valid()) {
        error = 'Cada seção precisa de ao menos uma imagem.';
        notifyListeners();
        return;
      }
    }

    loading = true;
    notifyListeners();

    try {
      // Salva/atualiza cada seção com sua nova posição.
      for (final section in _editingSections) {
        await section.save(_editingSections.indexOf(section));
      }

      // Remove do Firestore as seções apagadas na edição.
      for (final section in List<Section>.from(_sections)) {
        if (!_editingSections.any((s) => s.id == section.id)) {
          await section.delete();
        }
      }

      _sections
        ..clear()
        ..addAll(_editingSections);

      editing = false; // volta para a home normal (não editável)
    } catch (e) {
      // Mantém em modo de edição para o admin tentar de novo.
      error = 'Não foi possível salvar: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void discardEditing() {
    editing = false;
    notifyListeners();
  }
}
