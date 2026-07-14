import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddSectionWidget extends StatelessWidget {
  const AddSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final homeManager = context.read<HomeManager>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              icon: const Icon(Icons.view_agenda),
              label: const Text('Lista'),
              onPressed: () {
                homeManager.addSection(Section(type: 'List'));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              icon: const Icon(Icons.grid_view),
              label: const Text('Grade'),
              onPressed: () {
                homeManager.addSection(Section(type: 'Staggered'));
              },
            ),
          ),
        ],
      ),
    );
  }
}
