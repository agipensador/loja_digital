import 'package:image_picker/image_picker.dart';

import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/services/image_service.dart';
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
    List<String>? thumbs,
    List<ItemSize>? sizes,
    this.deleted = false,
    this.lowStockThreshold = 5,
    this.supplierId,
    this.weightGrams = 0,
    this.heightCm = 0,
    this.widthCm = 0,
    this.lengthCm = 0,
  }) {
    this.images = images ?? [];
    this.thumbs = thumbs ?? [];
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
    supplierId = data['supplierId'] as String?;
    weightGrams = ((data['weightGrams'] ?? 0) as num).toInt();
    heightCm = ((data['heightCm'] ?? 0) as num).toInt();
    widthCm = ((data['widthCm'] ?? 0) as num).toInt();
    lengthCm = ((data['lengthCm'] ?? 0) as num).toInt();
    images = List<String>.from(data['images'] as List<dynamic>? ?? []);
    thumbs = List<String>.from(data['thumbs'] as List<dynamic>? ?? []);
    updatedAt = data['updatedAt'] as Timestamp?;
    sizes = (data['sizes'] as List<dynamic>? ?? [])
        .map((s) => ItemSize.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  FirebaseStorage get storage => FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      Tenant.col('products').doc(id);

  Reference get storageRef => Tenant.storageFolder('products').child(id!);

  String? id;
  late String name;
  late String description;
  late String category;
  late List<String> images;

  /// Miniaturas (mesma ordem de [images]) para listas e grades.
  late List<String> thumbs;

  /// Última alteração — base da sincronização incremental do catálogo.
  Timestamp? updatedAt;

  /// Miniatura da foto [i] (cai na foto grande se não houver).
  String? thumbAt(int i) {
    if (i >= images.length) return null;
    return i < thumbs.length && thumbs[i].isNotEmpty ? thumbs[i] : images[i];
  }

  String? get coverThumb => thumbAt(0);
  late List<ItemSize> sizes;
  bool deleted = false;

  /// Alerta o admin quando o estoque total fica <= este valor.
  int lowStockThreshold = 5;

  /// Fornecedor de reposição (pedido pelo WhatsApp).
  String? supplierId;

  /// Peso e medidas da embalagem — usados na cotação dos Correios (Melhor
  /// Envio). 0 = não informado (usa o padrão da loja).
  int weightGrams = 0;
  int heightCm = 0;
  int widthCm = 0;
  int lengthCm = 0;

  bool get hasShippingInfo =>
      weightGrams > 0 && heightCm > 0 && widthCm > 0 && lengthCm > 0;

  /// Imagens em edição: String (URL salva ou link externo) ou XFile (nova).
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

  int stockAt(String locationId) =>
      sizes.fold(0, (total, s) => total + s.stockAt(locationId));

  bool hasStockAt(String locationId) => stockAt(locationId) > 0;

  bool isLowStockAt(String locationId) {
    final s = stockAt(locationId);
    return s > 0 && s <= lowStockThreshold;
  }

  /// Precisa repor na unidade: baixo OU esgotado (vale para alertas e
  /// pedido ao fornecedor).
  bool needsRestockAt(String locationId) =>
      stockAt(locationId) <= lowStockThreshold;

  /// Unidades físicas que têm ao menos uma variante em estoque.
  Set<String> get locationsWithStock => {
        for (final size in sizes)
          for (final e in size.stockByLocation.entries)
            if (e.value > 0) e.key,
      };

  /// Atualiza somente os estoques/variantes no Firestore (sem tocar imagens).
  Future<void> updateStock() async {
    await firestoreRef.update(
        {'sizes': exportSizeList(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Define o limite de alerta de estoque baixo.
  Future<void> setLowStockThreshold(int value) async {
    lowStockThreshold = value < 0 ? 0 : value;
    await firestoreRef.update({
      'lowStockThreshold': lowStockThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      'supplierId': supplierId,
      'weightGrams': weightGrams,
      'heightCm': heightCm,
      'widthCm': widthCm,
      'lengthCm': lengthCm,
      'sizes': exportSizeList(),
      'deleted': deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      final doc = await Tenant.col('products').add(data);
      id = doc.id;
    } else {
      await firestoreRef.update(data);
    }

    // Fotos novas são comprimidas no aparelho (versão grande + miniatura);
    // URLs mantidas ou links externos (ex.: Shopee) seguem como estão.
    final List<String> updatedImages = [];
    final List<String> updatedThumbs = [];
    for (final newImage in newImages) {
      if (newImage is String) {
        final old = images.indexOf(newImage);
        updatedImages.add(newImage);
        updatedThumbs.add(old >= 0 ? (thumbAt(old) ?? newImage) : newImage);
      } else if (newImage is XFile) {
        final uploaded = await ImageService.upload(storageRef, newImage);
        updatedImages.add(uploaded.url);
        updatedThumbs.add(uploaded.thumbUrl);
      }
    }

    // Remove do Storage as fotos descartadas (e suas miniaturas).
    for (var i = 0; i < images.length; i++) {
      if (newImages.contains(images[i])) continue;
      await ImageService.delete(images[i]);
      final thumb = thumbAt(i);
      if (thumb != null && thumb != images[i]) await ImageService.delete(thumb);
    }

    await firestoreRef.update({
      'images': updatedImages,
      'thumbs': updatedThumbs,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    images = updatedImages;
    thumbs = updatedThumbs;

    loading = false;
  }

  Future<void> delete() async {
    // Soft-delete: mantém o histórico de pedidos íntegro.
    await firestoreRef
        .update({'deleted': true, 'updatedAt': FieldValue.serverTimestamp()});
    deleted = true;
  }

  Product clone() {
    return Product(
      id: id,
      name: name,
      description: description,
      category: category,
      images: List.from(images),
      thumbs: List.from(thumbs),
      sizes: sizes.map((size) => size.clone()).toList(),
      deleted: deleted,
      lowStockThreshold: lowStockThreshold,
      supplierId: supplierId,
      weightGrams: weightGrams,
      heightCm: heightCm,
      widthCm: widthCm,
      lengthCm: lengthCm,
    );
  }

  @override
  String toString() {
    return 'Product{id: $id, name: $name, category: $category, '
        'deleted: $deleted, sizes: $sizes}';
  }
}
