import 'package:app_loja_digital/services/image_service.dart';
import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

/// Reconhece a rede social a partir da URL informada pelo admin.
class Social {
  static FaIconData iconFor(String url) {
    final u = url.toLowerCase();
    if (u.contains('instagram') || u.contains('instagr.am')) {
      return FontAwesomeIcons.instagram;
    }
    if (u.contains('facebook') || u.contains('fb.com') || u.contains('fb.me')) {
      return FontAwesomeIcons.facebookF;
    }
    if (u.contains('tiktok')) return FontAwesomeIcons.tiktok;
    if (u.contains('wa.me') || u.contains('whatsapp')) {
      return FontAwesomeIcons.whatsapp;
    }
    if (u.contains('youtube') || u.contains('youtu.be')) {
      return FontAwesomeIcons.youtube;
    }
    if (u.contains('twitter') || u.contains('x.com')) {
      return FontAwesomeIcons.xTwitter;
    }
    if (u.contains('t.me') || u.contains('telegram')) {
      return FontAwesomeIcons.telegram;
    }
    if (u.contains('linkedin')) return FontAwesomeIcons.linkedin;
    return FontAwesomeIcons.globe;
  }

  static String labelFor(String url) {
    final u = url.toLowerCase();
    if (u.contains('instagram')) return 'Instagram';
    if (u.contains('facebook') || u.contains('fb.')) return 'Facebook';
    if (u.contains('tiktok')) return 'TikTok';
    if (u.contains('wa.me') || u.contains('whatsapp')) return 'WhatsApp';
    if (u.contains('youtube') || u.contains('youtu.be')) return 'YouTube';
    if (u.contains('twitter') || u.contains('x.com')) return 'X';
    if (u.contains('t.me') || u.contains('telegram')) return 'Telegram';
    if (u.contains('linkedin')) return 'LinkedIn';
    return 'Site';
  }

  /// Garante que a URL tenha esquema para o url_launcher abrir.
  static String normalize(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://$u';
  }
}

/// Unidade FÍSICA da loja (endereço, telefone, horário) — exibida na página
/// "Lojas". Vive em stores/{storeId}/locations. Não confundir com o tenant
/// em si (StoreAccount, doc raiz stores/{storeId}).
class Store extends ChangeNotifier {
  Store({
    this.id,
    this.name = '',
    this.image,
    this.street = '',
    this.number = '',
    this.district = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.legacyAddress = '',
    this.phone = '',
    this.hours = '',
    this.open = true,
    this.offersPickup = true,
    this.offersShipping = true,
    this.offersOwnDelivery = false,
    this.shippingFee = 0,
    this.offersUber = false,
    this.uberFee = 0,
    this.uberBaseFee = 7,
    this.uberPerKm = 1.8,
    List<String>? socials,
  }) {
    this.socials = socials ?? [];
  }

  Store.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    id = doc.id;
    final data = doc.data()!;
    name = (data['name'] ?? '') as String;
    image = data['image'] as String?;
    street = (data['street'] ?? '') as String;
    number = (data['number'] ?? '') as String;
    district = (data['district'] ?? '') as String;
    city = (data['city'] ?? '') as String;
    state = (data['state'] ?? '') as String;
    zipCode = (data['zipCode'] ?? '') as String;
    legacyAddress = (data['address'] ?? '') as String;
    phone = (data['phone'] ?? '') as String;
    hours = (data['hours'] ?? '') as String;
    open = (data['open'] ?? true) as bool;
    offersPickup = (data['offersPickup'] ?? true) as bool;
    offersShipping = (data['offersShipping'] ?? true) as bool;
    offersOwnDelivery = (data['offersOwnDelivery'] ?? false) as bool;
    shippingFee = (data['shippingFee'] ?? 0) as num;
    offersUber = (data['offersUber'] ?? false) as bool;
    uberFee = (data['uberFee'] ?? 0) as num;
    uberBaseFee = (data['uberBaseFee'] ?? 7) as num;
    uberPerKm = (data['uberPerKm'] ?? 1.8) as num;
    socials = List<String>.from(data['socials'] as List<dynamic>? ?? []);
  }

  FirebaseStorage get storage => FirebaseStorage.instance;

  String? id;
  late String name;

  /// URL (String) já salva ou XFile recém-escolhido durante a edição.
  dynamic image;

  late String street;
  late String number;
  late String district;
  late String city;

  /// UF com 2 letras — junto com [city], decide qual unidade atende o
  /// cliente (comparado com o endereço dele, que vem do ViaCEP).
  late String state;
  late String zipCode;

  /// Endereço em texto livre do formato antigo (antes de cidade/UF).
  late String legacyAddress;

  late String phone;
  late String hours;
  late bool open;
  late List<String> socials;

  // Formas de entrega que ESTA unidade oferece.
  late bool offersPickup;
  late bool offersShipping; // Correios/transportadora

  /// Valor fixo do envio pelos Correios (por enquanto; cotação real depois).
  late num shippingFee;

  /// Entrega própria por área — locais, dias e valor ficam em cada zona.
  late bool offersOwnDelivery;

  /// Motoboy por Uber: a loja chama a corrida; valor fixo estimado.
  late bool offersUber;

  /// Valor fixo de reserva (quando não dá para calcular pela distância).
  late num uberFee;

  /// Estimativa: saída + R\$/km × distância (ver ShippingQuoteService).
  late num uberBaseFee;
  late num uberPerKm;

  bool get hasStructuredAddress => city.isNotEmpty && state.isNotEmpty;

  /// Endereço completo de uma linha (mapa, Uber, retirada).
  String get address {
    if (!hasStructuredAddress) return legacyAddress;
    final line1 = [street, number].where((p) => p.isNotEmpty).join(', ');
    return [line1, district, '$city/$state', zipCode]
        .where((p) => p.isNotEmpty)
        .join(' - ');
  }

  /// A unidade fica na mesma cidade/UF do endereço informado?
  bool servesCity(String otherCity, String otherState) {
    String norm(String v) => v.trim().toLowerCase();
    return hasStructuredAddress &&
        norm(city) == norm(otherCity) &&
        norm(state) == norm(otherState);
  }

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      Tenant.col('locations').doc(id);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'street': street,
      'number': number,
      'district': district,
      'city': city,
      'state': state.toUpperCase(),
      'zipCode': zipCode,
      'phone': phone,
      'hours': hours,
      'open': open,
      'offersPickup': offersPickup,
      'offersShipping': offersShipping,
      'offersOwnDelivery': offersOwnDelivery,
      'shippingFee': shippingFee,
      'offersUber': offersUber,
      'uberFee': uberFee,
      'uberBaseFee': uberBaseFee,
      'uberPerKm': uberPerKm,
      'socials': socials.where((s) => s.trim().isNotEmpty).toList(),
    };
  }

  /// [isFirst]: a 1ª unidade da loja usa o id fixo [kDefaultLocationId], para
  /// casar com o estoque gravado antes de existir qualquer unidade.
  Future<void> save({bool isFirst = false}) async {
    final Map<String, dynamic> data = toMap();

    if (id == null) {
      if (isFirst) {
        id = kDefaultLocationId;
        await firestoreRef.set(data);
      } else {
        final doc = await Tenant.col('locations').add(data);
        id = doc.id;
      }
    } else {
      await firestoreRef.update(data);
    }

    // Upload da nova imagem, se houver.
    if (image is XFile) {
      final uploaded = await ImageService.upload(
          Tenant.storageFolder('locations').child(id!), image as XFile);
      image = uploaded.url;
      await firestoreRef.update({'image': image});
    }
  }

  Future<void> delete() async {
    await firestoreRef.delete();
  }

  Store clone() {
    return Store(
      id: id,
      name: name,
      image: image,
      street: street,
      number: number,
      district: district,
      city: city,
      state: state,
      zipCode: zipCode,
      legacyAddress: legacyAddress,
      phone: phone,
      hours: hours,
      open: open,
      offersPickup: offersPickup,
      offersShipping: offersShipping,
      offersOwnDelivery: offersOwnDelivery,
      shippingFee: shippingFee,
      offersUber: offersUber,
      uberFee: uberFee,
      uberBaseFee: uberBaseFee,
      uberPerKm: uberPerKm,
      socials: List.from(socials),
    );
  }
}
