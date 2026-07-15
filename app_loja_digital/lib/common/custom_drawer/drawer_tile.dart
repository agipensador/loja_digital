import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/models/page_manager.dart';

class DrawerTile extends StatelessWidget {
  const DrawerTile({
    super.key,
    required this.iconData,
    required this.title,
    required this.page,
  });

  final IconData iconData;
  final String title;
  final int page;

  @override
  Widget build(BuildContext context) {
    final int currentPage = context.watch<PageManager>().currentPage;
    final Color primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: () {
        final pageManager = context.read<PageManager>();
        // Fecha o drawer e volta para a BaseScreen, descartando qualquer
        // rota empilhada (ex: Favoritos), antes de trocar de página.
        Navigator.of(context).popUntil((route) => route.isFirst);
        pageManager.setPage(page);
      },
      child: SizedBox(
        height: 60,
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Icon(
                iconData,
                size: 32,
                color: currentPage == page ? primaryColor : Colors.grey[700],
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: currentPage == page ? primaryColor : Colors.grey[700],
              ),
            )
          ],
        ),
      ),
    );
  }
}
