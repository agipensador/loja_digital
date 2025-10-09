import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:flutter/material.dart';

class Product extends ChangeNotifier {
  Product.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    id = document.id;
    final data = document.data()!;
    name = data['name'] as String;
    description = data['description'] as String;
    images = List<String>.from(data['images'] as List<dynamic>);
    sizes = (data['sizes'] as List<dynamic>? ?? [])
        .map((s) => ItemSize.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  late String id;
  late String name;
  late String description;
  late List<String> images;
  late List<ItemSize> sizes;

  ItemSize? _selectedSize;
  ItemSize? get selectedSize => _selectedSize;
  set selectedSize(ItemSize? value) {
    _selectedSize = value;
    notifyListeners();
  }

  int get totalStock {
    int stock = 0;
    for(final size in sizes){
      stock += size.stock;
    }
    return stock;
  }

  bool get hasStock {
    return totalStock > 0;
  }

  ItemSize? findSize(String name){
    try{
      return sizes.firstWhere((s) => s.name == name);
    } catch (e){
      return null;
    }
  }
}
