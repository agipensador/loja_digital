import 'dart:io';

import 'package:app_loja_digital/models/section_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class Section extends ChangeNotifier {
  Section({
    this.id,
    this.name = '',
    this.type = 'Staggered',
    List<SectionItem>? items,
  }) {
    this.items = items ?? [];
    _originalItems = List.from(this.items);
  }

  Section.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    id = document.id;
    final data = document.data()!;
    name = (data['name'] ?? '') as String;
    type = (data['type'] ?? 'Staggered') as String;
    items = (data['items'] as List<dynamic>? ?? [])
        .map((i) => SectionItem.fromMap(i as Map<String, dynamic>))
        .toList();
    _originalItems = List.from(items);
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  String? id;
  late String name;
  late String type; // 'List' | 'Staggered'
  late List<SectionItem> items;

  List<SectionItem> _originalItems = [];

  String? _error;
  String? get error => _error;
  set error(String? value) {
    _error = value;
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      firestore.collection('home').doc(id);

  Reference get storageRef => storage.ref().child('home').child(id!);

  void addItem(SectionItem item) {
    items.add(item);
    notifyListeners();
  }

  void removeItem(SectionItem item) {
    items.remove(item);
    notifyListeners();
  }

  void setItemProduct(SectionItem item, String? productId) {
    item.product = productId;
    notifyListeners();
  }

  bool valid() {
    if (items.isEmpty) {
      error = 'Adicione ao menos uma imagem';
    } else {
      error = null;
    }
    return error == null;
  }

  Future<void> save(int pos) async {
    final Map<String, dynamic> data = {
      'name': name,
      'type': type,
      'pos': pos,
    };

    if (id == null) {
      final doc = await firestore.collection('home').add(data);
      id = doc.id;
    } else {
      await firestoreRef.update(data);
    }

    // Upload de imagens novas (File) e coleta das URLs mantidas.
    for (final item in items) {
      if (item.image is File) {
        final Reference ref = storageRef.child(
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
        final UploadTask task = ref.putFile(item.image as File);
        final TaskSnapshot snapshot = await task;
        item.image = await snapshot.ref.getDownloadURL();
      }
    }

    // Remove imagens descartadas do Storage.
    for (final original in _originalItems) {
      if (!items.contains(original) &&
          original.image is String &&
          (original.image as String)
              .contains('firebasestorage.googleapis.com')) {
        try {
          await storage.refFromURL(original.image as String).delete();
        } catch (e) {
          debugPrint('Falha ao apagar imagem de seção: $e');
        }
      }
    }

    await firestoreRef.update({
      'items': items.map((i) => i.toMap()).toList(),
    });

    _originalItems = List.from(items);
  }

  Future<void> delete() async {
    await firestoreRef.delete();
    for (final item in items) {
      if (item.image is String &&
          (item.image as String)
              .contains('firebasestorage.googleapis.com')) {
        try {
          await storage.refFromURL(item.image as String).delete();
        } catch (e) {
          debugPrint('Falha ao apagar imagem de seção: $e');
        }
      }
    }
  }

  Section clone() {
    return Section(
      id: id,
      name: name,
      type: type,
      items: items.map((i) => i.clone()).toList(),
    );
  }

  @override
  String toString() {
    return 'Section{id: $id, name: $name, type: $type, items: $items}';
  }
}
