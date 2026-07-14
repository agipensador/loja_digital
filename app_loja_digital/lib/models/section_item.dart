class SectionItem {
  SectionItem({this.image, this.product});

  SectionItem.fromMap(Map<String, dynamic> map) {
    image = map['image'] as String?;
    product = map['product'] as String?;
  }

  /// Pode ser uma URL (String) já salva ou um File novo em edição.
  dynamic image;

  /// Id do produto vinculado (opcional).
  String? product;

  SectionItem clone() {
    return SectionItem(image: image, product: product);
  }

  Map<String, dynamic> toMap() {
    return {
      'image': image,
      'product': product,
    };
  }
}
