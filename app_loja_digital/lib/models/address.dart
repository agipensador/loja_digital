class Address {
  Address({
    this.street = '',
    this.number = '',
    this.complement = '',
    this.district = '',
    this.zipCode = '',
    this.city = '',
    this.state = '',
  });

  Address.fromMap(Map<String, dynamic> map) {
    street = (map['street'] ?? '') as String;
    number = (map['number'] ?? '') as String;
    complement = (map['complement'] ?? '') as String;
    district = (map['district'] ?? '') as String;
    zipCode = (map['zipCode'] ?? '') as String;
    city = (map['city'] ?? '') as String;
    state = (map['state'] ?? '') as String;
  }

  late String street;
  late String number;
  late String complement;
  late String district;
  late String zipCode;
  late String city;
  late String state;

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'number': number,
      'complement': complement,
      'district': district,
      'zipCode': zipCode,
      'city': city,
      'state': state,
    };
  }

  @override
  String toString() {
    return '$street, $number${complement.isNotEmpty ? ' - $complement' : ''} - '
        '$district, $city/$state - $zipCode';
  }
}
