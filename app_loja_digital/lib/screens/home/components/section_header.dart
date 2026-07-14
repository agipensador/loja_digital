import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final homeManager = context.watch<HomeManager>();
    final section = context.watch<Section>();

    if (homeManager.editing) {
      return Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              initialValue: section.name,
              decoration: const InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: Colors.white54),
                isDense: true,
                border: InputBorder.none,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              onChanged: (value) => section.name = value,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    }
  }
}
