import 'package:app_loja_digital/common/store_image.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreCard extends StatelessWidget {
  const StoreCard(this.store, {super.key});

  final Store store;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final adminEnabled = context.watch<UserManager>().adminEnabled;
    final imageUrl = store.image is String ? store.image as String : null;

    return Card(
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: StoreImage(imageUrl),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    store.open ? 'Aberta' : 'Fechada',
                    style: TextStyle(
                      color: store.open ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (adminEnabled)
                Positioned(
                  top: 8,
                  left: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => Navigator.of(context)
                          .pushNamed('/edit_store', arguments: store),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  store.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: Text(store.address)),
                    if (store.address.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.map, color: primaryColor),
                        tooltip: 'Ver no mapa',
                        onPressed: () => _open(
                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(store.address)}',
                        ),
                      ),
                  ],
                ),
                if (store.hours.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(store.hours,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87)),
                      ),
                      if (store.phone.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.phone, color: primaryColor),
                          tooltip: 'Ligar',
                          onPressed: () => _open('tel:${store.phone}'),
                        ),
                    ],
                  ),
                if (store.socials.isNotEmpty) ...[
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    children: store.socials.map((url) {
                      return IconButton(
                        icon: FaIcon(Social.iconFor(url), color: primaryColor),
                        tooltip: Social.labelFor(url),
                        onPressed: () => _open(Social.normalize(url)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
