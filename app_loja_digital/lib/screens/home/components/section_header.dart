import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final homeManager = context.watch<HomeManager>();
    final section = context.watch<Section>();
    // Título legível sobre o fundo escolhido pelo admin.
    final onBg =
        ThemeManager.onColor(context.watch<ThemeManager>().background);

    if (homeManager.editing) {
      return Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              initialValue: section.name,
              decoration: InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: onBg.withAlpha(120)),
                isDense: true,
                border: InputBorder.none,
              ),
              style: TextStyle(
                color: onBg,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              onChanged: (value) => section.name = value,
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove, color: onBg),
            tooltip: 'Remover seção',
            onPressed: () {
              homeManager.removeSection(section);
            },
          ),
        ],
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          section.name,
          style: TextStyle(
            color: onBg,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    }
  }
}
