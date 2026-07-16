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
    final theme = context.watch<ThemeManager>();

    // A tela atual: se for rota empilhada (ex: /favorites), o nome bate com
    // 'route'; se estivermos na BaseScreen, vale a aba (page) atual.
    final String? routeName = ModalRoute.of(context)?.settings.name;
    final bool onBase =
        routeName == null || routeName == '/' || routeName == '/base';
    final bool selected = route != null
        ? routeName == route
        : (onBase && currentPage == page);

    final Color accent = theme.menuAccent;
    final Color color = selected ? accent : theme.onMenu;

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
      child: Container(
        height: 60,
        decoration: selected
            ? BoxDecoration(
                color: accent.withAlpha(28),
                border: Border(left: BorderSide(color: accent, width: 4)),
              )
            : null,
        child: Row(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(
                  left: selected ? 28 : 32, right: 32),
              child: Icon(iconData, size: 32, color: color),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            )
          ],
        ),
      ),
    );
  }
}
