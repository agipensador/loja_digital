import 'package:app_loja_digital/core/platform_contact.dart';
import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BrandColor {
  const BrandColor(this.name, this.value);
  final String name;
  final int value;

  Color get color => Color(value);
  String get hex =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// "Quero minha loja": plano + nome + cores + o que a pessoa já tem, e
/// abre o WhatsApp da Inforizz com a mensagem pronta (lá ela manda o
/// logotipo e a planilha de produtos).
class StartStoreScreen extends StatefulWidget {
  const StartStoreScreen({super.key, this.planId});

  final String? planId;

  static const List<BrandColor> palette = [
    BrandColor('Vermelho', 0xFFE53935),
    BrandColor('Laranja', 0xFFFB8C00),
    BrandColor('Amarelo', 0xFFFDD835),
    BrandColor('Verde', 0xFF43A047),
    BrandColor('Turquesa', 0xFF00ACC1),
    BrandColor('Azul', 0xFF1E88E5),
    BrandColor('Azul-marinho', 0xFF1A237E),
    BrandColor('Roxo', 0xFF8E24AA),
    BrandColor('Rosa', 0xFFD81B60),
    BrandColor('Marrom', 0xFF6D4C41),
    BrandColor('Dourado', 0xFFC9A227),
    BrandColor('Preto', 0xFF212121),
  ];

  /// Mensagem enviada no WhatsApp (pública para teste).
  static String message({
    required Plan plan,
    required BillingPeriod period,
    required String storeName,
    required String city,
    required List<BrandColor> colors,
    required String customColors,
    required bool hasLogo,
    required bool hasCatalog,
    required bool hasMercadoPago,
  }) {
    final colorText = [
      ...colors.map((c) => '${c.name} (${c.hex})'),
      if (customColors.trim().isNotEmpty) customColors.trim(),
    ];
    final willSend = [
      if (hasLogo) 'logotipo',
      if (hasCatalog) 'planilha de produtos',
    ];
    return [
      'Olá, Inforizz! Quero este plano: *${plan.name}* '
          '(${Br.money(plan.priceForPeriod(0, period))} ${period.label.toLowerCase()}).',
      if (storeName.trim().isNotEmpty) 'Loja: ${storeName.trim()}',
      if (city.trim().isNotEmpty) 'Cidade: ${city.trim()}',
      'Cores: ${colorText.isEmpty ? 'quero ajuda para escolher' : colorText.join(' + ')}',
      if (willSend.isNotEmpty) 'Vou enviar aqui: ${willSend.join(' e ')}.',
      if (!hasLogo) 'Ainda não tenho logotipo.',
      'Conta Mercado Pago: ${hasMercadoPago ? 'já tenho' : 'ainda não tenho'}.',
    ].join('\n');
  }

  @override
  State<StartStoreScreen> createState() => _StartStoreScreenState();
}

class _StartStoreScreenState extends State<StartStoreScreen> {
  late Plan _plan = PlanCatalog.byId(widget.planId ?? PlanCatalog.unica.id);
  BillingPeriod _period = BillingPeriod.monthly;
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _custom = TextEditingController();
  final List<BrandColor> _colors = [];
  bool _hasLogo = true;
  bool _hasCatalog = false;
  bool _hasMp = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _toggleColor(BrandColor c) => setState(() {
        if (_colors.contains(c)) {
          _colors.remove(c);
        } else if (_colors.length < 3) {
          _colors.add(c);
        }
      });

  Future<void> _send() async {
    final text = StartStoreScreen.message(
      plan: _plan,
      period: _period,
      storeName: _name.text,
      city: _city.text,
      colors: _colors,
      customColors: _custom.text,
      hasLogo: _hasLogo,
      hasCatalog: _hasCatalog,
      hasMercadoPago: _hasMp,
    );
    await launchUrl(Uri.parse(PlatformContact.support(text)),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Montar minha loja')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('1. Escolha o plano', style: theme.textTheme.titleMedium),
          for (final p in PlanCatalog.all)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: p.id == _plan.id
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2),
              ),
              child: ListTile(
                onTap: () => setState(() => _plan = p),
                leading: Icon(p.id == _plan.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text('${p.name}: ${Br.money(p.price)}/mês'),
                subtitle: Text(p.description),
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final per in BillingPeriod.values)
                ChoiceChip(
                  label: Text(per.label),
                  selected: per == _period,
                  onSelected: (_) => setState(() => _period = per),
                ),
            ],
          ),
          Text(
            '${PlatformBilling.trialDays ~/ 30} meses grátis para começar. '
            'Taxa de ${Br.money(PlatformBilling.serviceFee)} por pedido pago.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Text('2. Sua loja', style: theme.textTheme.titleMedium),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome da loja'),
          ),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Cidade / UF'),
          ),
          const SizedBox(height: 20),
          Text('3. Cores da marca (até 3)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in StartStoreScreen.palette)
                Semantics(
                  button: true,
                  selected: _colors.contains(c),
                  label: c.name,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _toggleColor(c),
                    child: Column(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: c.color,
                          child: _colors.contains(c)
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 2),
                        Text(c.name, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          TextField(
            controller: _custom,
            decoration: const InputDecoration(
              labelText: 'Já sei as cores (opcional)',
              hintText: 'Ex.: #E53935 e branco',
            ),
          ),
          const SizedBox(height: 20),
          Text('4. O que você já tem', style: theme.textTheme.titleMedium),
          CheckboxListTile(
            value: _hasLogo,
            onChanged: (v) => setState(() => _hasLogo = v ?? false),
            title: const Text('Logotipo'),
            subtitle: const Text('Vira o ícone do app no celular e no site'),
          ),
          CheckboxListTile(
            value: _hasCatalog,
            onChanged: (v) => setState(() => _hasCatalog = v ?? false),
            title: const Text('Planilha de produtos'),
            subtitle: const Text('Excel, Google Planilhas, CSV ou JSON'),
          ),
          CheckboxListTile(
            value: _hasMp,
            onChanged: (v) => setState(() => _hasMp = v ?? false),
            title: const Text('Conta Mercado Pago'),
            subtitle: const Text('Para receber as vendas'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const FaIcon(FontAwesomeIcons.whatsapp),
            label: const Text('Quero este plano: enviar no WhatsApp'),
            onPressed: _send,
          ),
          const SizedBox(height: 8),
          Text(
            'Abre o WhatsApp da Inforizz (${PlatformContact.whatsappLabel}) '
            'com tudo escrito. Lá você manda o logotipo e a planilha, e a '
            'gente te acompanha no primeiro acesso.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
