import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/models/section.dart';
import 'package:app_loja_digital/screens/home/components/edit_section_images.dart';
import 'package:app_loja_digital/screens/home/components/section_header.dart';
import 'package:app_loja_digital/screens/home/components/section_list.dart';
import 'package:app_loja_digital/screens/home/components/section_staggered.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SectionWidget extends StatelessWidget {
  const SectionWidget(this.section, {super.key});

  final Section section;

  @override
  Widget build(BuildContext context) {
    final homeManager = context.watch<HomeManager>();

    return ChangeNotifierProvider.value(
      value: section,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SectionHeader(),
            if (homeManager.editing)
              const EditSectionImages()
            else if (section.type == 'List')
              SectionList(section)
            else
              SectionStaggered(section),
          ],
        ),
      ),
    );
  }
}
