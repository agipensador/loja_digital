import 'package:image_picker/image_picker.dart';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:flutter/material.dart';

class Product extends ChangeNotifier {
  Product({
    this.id,
    this.name = '',
    this.description = '',
    this.category = 'Outros',
    List<String>? images,
    List<ItemSize>? sizes,
    this.deleted = false,
    this.lowStockThreshold = 5,
  }) {
    this.images = images ?? [];
    this.sizes = sizes ?? [];
  }

  Product.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    id = document.id;
    final data = document.data()!;
    name = (data['name'] ?? '') as String;
    description = (data['description'] ?? '') as String;
    category = (data['category'] ?? 'Outros') as String;
    deleted = (data['deleted'] ?? false) as bool;
    lowStockThreshold = (data['lowStockThreshold'] ?? 5) as int;
    images = List<String>.from(data['images'] as List<dynamic>? ?? []);
    sizes = (data['sizes'] as List<dynamic>? ?? [])
        .map((s) => ItemSize.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  final FirebaseStorage storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      Tenant.col('products').doc(id);

  Reference get storageRef => Tenant.storageFolder('products').child(id!);

  String? id;
  late String name;
  late String description;
  late String category;
  late List<String> images;
  late List<ItemSize> sizes;
  bool deleted = false;

  /// Alerta o admin quando o estoque total fica <= este valor.
  int lowStockThreshold = 5;

  /// Imagens em edição: pode conter String (URL já salva) ou File (nova imagem).
  List<dynamic> newImages = [];

  bool _loading = false;
  bool get loading => _loading;
  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  ItemSize? _selectedSize;
  ItemSize? get selectedSize => _selectedSize;
  set selectedSize(ItemSize? value) {
    _selectedSize = value;
    notifyListeners();
  }

  int get totalStock {
    int stock = 0;
    for (final size in sizes) {
      stock += size.stock;
    }
    return stock;
  }

  bool get hasStock => totalStock > 0;

  bool get isOutOfStock => totalStock <= 0;

  /// Estoque baixo: ainda tem itens, mas <= limite de alerta.
  bool get isLowStock => totalStock > 0 && totalStock <= lowStockThreshold;

  /// Atualiza somente os estoques/variantes no Firestore (sem tocar imagens).
  Future<void> updateStock() async {
    await firestoreRef.update({'sizes': exportSizeList()});
  }

  /// Define o limite de alerta de estoque baixo.
  Future<void> setLowStockThreshold(int value) async {
    lowStockThreshold = value < 0 ? 0 : value;
    await firestoreRef.update({'lowStockThreshold': lowStockThreshold});
    notifyListeners();
  }

  /// Menor preço entre os tamanhos com estoque (ou o menor preço se nenhum tiver).
  num get basePrice {
    num lowest = double.infinity;
    for (final size in sizes) {
      if (size.price < lowest && size.hasStock) lowest = size.price;
    }
    if (lowest == double.infinity) {
      for (final size in sizes) {
        if (size.price < lowest) lowest = size.price;
      }
    }
    return lowest == double.infinity ? 0 : lowest;
  }

  ItemSize? findSize(String name) {
    try {
      return sizes.firstWhere((s) => s.name == name);
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> exportSizeList() {
    return sizes.map((size) => size.toMap()).toList();
  }

  Future<void> save() async {
    loading = true;

    final Map<String, dynamic> data = {
      'name': name,
      'description': description,
      'category': category,
      'lowStockThreshold': lowStockThreshold,
      'sizes': exportSizeList(),
      'deleted': deleted,
    };

    if (id == null) {
      final doc = await Tenant.col('products').add(data);
      id = doc.id;
    } else {
      await firestoreRef.update(data);
    }

    // Upload das novas imagens (File) e coleta das URLs mantidas.
    final List<String> updatedImages = [];

    for (final newImage in newImages) {
      if (newImage is String) {
        updatedImages.add(newImage);
      } else if (newImage is XFile) {
        final Reference ref = storageRef.child(
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
        final bytes = await newImage.readAsBytes();
        final UploadTask task =
            ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final TaskSnapshot snapshot = await task;
        final String url = await snapshot.ref.getDownloadURL();
        updatedImages.add(url);
      }
    }

    // Remove do Storage as imagens que foram descartadas na edição.
    for (final image in images) {
      if (!newImages.contains(image) &&
          image.contains('firebasestorage.googleapis.com')) {
        try {
          await storage.refFromURL(image).delete();
        } catch (e) {
          debugPrint('Falha ao apagar imagem antiga: $e');
        }
      }
    }

    await firestoreRef.update({'images': updatedImages});
    images = updatedImages;

    loading = false;
  }

  Future<void> delete() async {
    // Soft-delete: mantém o histórico de pedidos íntegro.
    await firestoreRef.update({'deleted': true});
    deleted = true;
  }

  Product clone() {
    return Product(
      id: id,
      name: name,
      description: description,
      category: category,
      images: List.from(images),
      sizes: sizes.map((size) => size.clone()).toList(),
      deleted: deleted,
      lowStockThreshold: lowStockThreshold,
    );
  }

  @override
  String toString() {
    return 'Product{id: $id, name: $name, category: $category, '
        'deleted: $deleted, sizes: $sizes}';
  }
}
