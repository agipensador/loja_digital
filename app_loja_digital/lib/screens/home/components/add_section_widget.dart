import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddSectionWidget extends StatelessWidget {
  const AddSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final homeManager = context.read<HomeManager>();
    final onBg =
        ThemeManager.onColor(context.watch<ThemeManager>().background);

    Widget option(IconData icon, String label, String type) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: onBg,
          side: BorderSide(color: onBg),
        ),
        icon: Icon(icon),
        label: Text(label),
        onPressed: () => homeManager.addSection(Section(type: type)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Adicionar seção como:',
              style: TextStyle(color: onBg.withAlpha(200), fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              option(Icons.view_carousel, 'Carrossel', 'Carousel'),
              option(Icons.dashboard, 'Grade', 'Staggered'),
              option(Icons.grid_view, 'Mosaico', 'Grid'),
              option(Icons.view_day, 'Lista', 'List'),
            ],
          ),
        ],
      ),
    );
  }
}
