import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/models/page_manager.dart';
import 'package:app_loja_digital/models/theme_manager.dart';

class DrawerTile extends StatelessWidget {
  const DrawerTile({
    super.key,
    required this.iconData,
    required this.title,
    this.page,
    this.route,
  }) : assert(page != null || route != null,
            'Informe page (aba) ou route (rota empilhada)');

  final IconData iconData;
  final String title;

  /// Navegação por aba do PageView.
  final int? page;

  /// Navegação por rota (ex: '/favorites', '/profile').
  final String? route;

  @override
  Widget build(BuildContext context) {
    final int currentPage = context.watch<PageManager>().currentPage;
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool selected = page != null && currentPage == page;
    // Cor legível conforme a cor do menu escolhida pelo admin.
    final Color onMenu = context.watch<ThemeManager>().onMenu;
    final Color color = selected ? primaryColor : onMenu;

    return InkWell(
      onTap: () {
        final pageManager = context.read<PageManager>();
        // Fecha o drawer e volta para a BaseScreen, descartando qualquer
        // rota empilhada, antes de navegar.
        Navigator.of(context).popUntil((r) => r.isFirst);
        if (route != null) {
          Navigator.of(context).pushNamed(route!);
        } else {
          pageManager.setPage(page!);
        }
      },
      child: SizedBox(
        height: 60,
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Icon(iconData, size: 32, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: color),
            )
          ],
        ),
      ),
    );
  }
}
