import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Paleta de cores sugeridas (o admin toca para escolher).
const List<Color> _palette = [
  Color(0xFF047D8D), Color(0xFFB98A82), Color(0xFFCBECF1),
  Color(0xFF1976D2), Color(0xFF0288D1), Color(0xFF00897B),
  Color(0xFF43A047), Color(0xFF7CB342), Color(0xFFFB8C00),
  Color(0xFFF4511E), Color(0xFFE53935), Color(0xFFD81B60),
  Color(0xFF8E24AA), Color(0xFF5E35B1), Color(0xFF3949AB),
  Color(0xFF6D4C41), Color(0xFF546E7A), Color(0xFF212121),
  Color(0xFFF5F5F5), Color(0xFFFFFFFF),
];

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Aparência do app'), centerTitle: true),
      body: Consumer<ThemeManager>(
        builder: (_, theme, __) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'Personalize sua loja. As mudanças aparecem na hora; toque em '
                'Salvar para valer para todos.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Pré-visualização
              _Preview(theme: theme),
              const SizedBox(height: 20),

              const Text('Nome do app / título',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                initialValue: theme.storeName,
                decoration: const InputDecoration(hintText: 'Ex: Loja da Ju'),
                onChanged: theme.setStoreName,
              ),
              const SizedBox(height: 20),

              _ColorRow(
                label: 'Cor principal (botões, topo)',
                current: theme.primary,
                onPick: theme.setPrimary,
              ),
              _ColorRow(
                label: 'Cor de fundo das páginas',
                current: theme.background,
                onPick: theme.setBackground,
              ),
              _ColorRow(
                label: 'Cor do menu lateral',
                current: theme.menu,
                onPick: theme.setMenu,
              ),

              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => theme.discard(),
                      child: const Text('Descartar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await theme.save();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Aparência salva!')),
                          );
                        }
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.theme});
  final ThemeManager theme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: theme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              color: theme.primary,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.menu, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(theme.storeName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 70,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.menu,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text('Menu',
                        style: TextStyle(color: theme.onMenu, fontSize: 12)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Botão'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.current,
    required this.onPick,
  });

  final String label;
  final Color current;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: current,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _palette.map((c) {
              final selected = c.toARGB32() == current.toARGB32();
              return GestureDetector(
                onTap: () => onPick(c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black : Colors.grey.shade300,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 18, color: ThemeManager.onColor(c))
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
