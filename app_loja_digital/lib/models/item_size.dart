/// Id da unidade física padrão: a 1ª unidade cadastrada recebe este id, e
/// lojas sem nenhuma unidade cadastrada usam-no como unidade virtual. Assim
/// a loja de uma unidade só nunca precisa pensar em "multi-lojas".
const String kDefaultLocationId = 'principal';

class ItemSize {
  ItemSize({
    this.name = '',
    this.price = 0,
    Map<String, int>? stockByLocation,
  }) : stockByLocation = stockByLocation ?? {};

  ItemSize.fromMap(Map<String, dynamic> map)
      : name = (map['name'] ?? '') as String,
        price = (map['price'] ?? 0) as num,
        stockByLocation = map['stockByLocation'] is Map
            ? (map['stockByLocation'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toInt()))
            // Formato antigo (estoque único) vira estoque da unidade padrão.
            : {kDefaultLocationId: ((map['stock'] ?? 0) as num).toInt()};

  String name;
  num price;

  /// Quantidade por unidade física (locationId -> quantidade).
  Map<String, int> stockByLocation;

  /// Estoque total somando todas as unidades.
  int get stock => stockByLocation.values.fold(0, (a, b) => a + b);

  int stockAt(String locationId) => stockByLocation[locationId] ?? 0;

  void setStockAt(String locationId, int value) {
    stockByLocation[locationId] = value < 0 ? 0 : value;
  }

  bool get hasStock => stock > 0;

  bool hasStockAt(String locationId) => stockAt(locationId) > 0;

  ItemSize clone() {
    return ItemSize(
      name: name,
      price: price,
      stockByLocation: Map.of(stockByLocation),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'stockByLocation': stockByLocation,
    };
  }

  @override
  String toString() {
    return 'ItemSize{name: $name, price: $price, stock: $stockByLocation}';
  }
}
