class ItemSize {
  ItemSize({
    this.name = '',
    this.price = 0,
    this.stock = 0,
  });

  ItemSize.fromMap(Map<String, dynamic> map) {
    name = (map['name'] ?? '') as String;
    price = (map['price'] ?? 0) as num;
    stock = (map['stock'] ?? 0) as int;
  }

  late String name;
  late num price;
  late int stock;

  bool get hasStock => stock > 0;

  ItemSize clone() {
    return ItemSize(
      name: name,
      price: price,
      stock: stock,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'stock': stock,
    };
  }

  @override
  String toString() {
    return 'ItemSize{name: $name, price: $price, stock: $stock}';
  }
}
