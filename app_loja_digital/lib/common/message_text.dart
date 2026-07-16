import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Mensagem centralizada (ex.: listas vazias) com cor que sempre contrasta
/// com o fundo escolhido pelo admin.
class MessageText extends StatelessWidget {
  const MessageText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final onBg =
        ThemeManager.onColor(context.watch<ThemeManager>().background);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: onBg, fontSize: 16),
        ),
      ),
    );
  }
}
