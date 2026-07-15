import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

/// Reconhece a rede social a partir da URL informada pelo admin.
class Social {
  static IconData iconFor(String url) {
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

class Store extends ChangeNotifier {
  Store({
    this.id,
    this.name = '',
    this.image,
    this.address = '',
    this.phone = '',
    this.hours = '',
    this.open = true,
    List<String>? socials,
  }) {
    this.socials = socials ?? [];
  }

  Store.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    id = doc.id;
    final data = doc.data()!;
    name = (data['name'] ?? '') as String;
    image = data['image'] as String?;
    address = (data['address'] ?? '') as String;
    phone = (data['phone'] ?? '') as String;
    hours = (data['hours'] ?? '') as String;
    open = (data['open'] ?? true) as bool;
    socials = List<String>.from(data['socials'] as List<dynamic>? ?? []);
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  String? id;
  late String name;

  /// URL (String) já salva ou XFile recém-escolhido durante a edição.
  dynamic image;

  late String address;
  late String phone;
  late String hours;
  late bool open;
  late List<String> socials;

  DocumentReference<Map<String, dynamic>> get firestoreRef =>
      firestore.collection('stores').doc(id);

  Future<void> save() async {
    final Map<String, dynamic> data = {
      'name': name,
      'address': address,
      'phone': phone,
      'hours': hours,
      'open': open,
      'socials': socials.where((s) => s.trim().isNotEmpty).toList(),
    };

    if (id == null) {
      final doc = await firestore.collection('stores').add(data);
      id = doc.id;
    } else {
      await firestoreRef.update(data);
    }

    // Upload da nova imagem, se houver.
    if (image is XFile) {
      final ref = storage.ref().child('stores').child(id!).child(
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
      final bytes = await (image as XFile).readAsBytes();
      final task =
          ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await task;
      image = await snapshot.ref.getDownloadURL();
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
      address: address,
      phone: phone,
      hours: hours,
      open: open,
      socials: List.from(socials),
    );
  }
}
