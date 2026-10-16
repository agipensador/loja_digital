import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/usage_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Uso do mês × incluído no plano, cobrança extra estimada e o teto.
class UsageCard extends StatelessWidget {
  const UsageCard({super.key});

  static final NumberFormat _int = NumberFormat.decimalPattern('pt_BR');

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<TenantManager>().store?.plan;
    if (plan == null) return const SizedBox.shrink();
    final products = context.watch<ProductManager>().allProducts.length;
    final r = context.watch<UsageManager>().report(plan, products);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Uso deste mês',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _Meter(
              label: 'Visitas ao app e ao site',
              value: '${_int.format(r.visits)} de ${_int.format(plan.maxVisits)}',
              fraction: r.fraction(r.visits, plan.maxVisits),
            ),
            _Meter(
              label: 'Produtos',
              value:
                  '${_int.format(r.products)} de ${_int.format(plan.maxProducts)}',
              fraction: r.fraction(r.products, plan.maxProducts),
            ),
            _Meter(
              label: 'Fotos (armazenamento)',
              value: '${r.storageGb.toStringAsFixed(2).replaceAll('.', ',')} GB '
                  'de ${plan.maxStorageGb} GB '
                  '(cerca de ${_int.format(r.photosIncluded)} fotos)',
              fraction: r.fraction(r.storageGb, plan.maxStorageGb),
            ),
            const SizedBox(height: 8),
            if (r.overLimit)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.capReached
                      ? 'Sua loja passou bastante do incluído no plano. A '
                          'cobrança extra chegou ao teto de '
                          '${Br.money(UsageReport.maxExtraCharge)} e novos '
                          'produtos e fotos estão pausados — as vendas '
                          'continuam normalmente. Mude de plano para seguir '
                          'crescendo.'
                      : 'Cobrança extra estimada neste mês: '
                          '${Br.money(r.extraCharge)}.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 4),
            _HowWeSave(r: r, plan: plan),
            const SizedBox(height: 8),
            Text(
              'Se o app e o site passarem de ${_int.format(plan.maxVisits)} '
              'visitas no mês, ${_int.format(plan.maxProducts)} produtos ou '
              '${plan.maxStorageGb} GB de fotos (cerca de '
              '${_int.format(r.photosIncluded)} fotos), cobramos '
              '${Br.money(UsageReport.pricePerBlock)} a cada 1.000 visitas, '
              '100 produtos ou 1 GB a mais — porque mais clientes ativos '
              'geram mais custo de servidor. Essa cobrança nunca passa de '
              '${Br.money(UsageReport.maxExtraCharge)} por mês: ao chegar '
              'nesse teto, pausamos novos produtos e fotos até você mudar '
              'de plano.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter(
      {required this.label, required this.value, required this.fraction});

  final String label;
  final String value;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = fraction >= 1
        ? Colors.red
        : fraction >= 0.8
            ? Colors.orange
            : Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              Text(value, style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction,
            color: color,
            backgroundColor: color.withAlpha(40),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

/// Explica, em linguagem de lojista, por que 2 GB rendem tantas fotos, o que
/// a plataforma faz para gastar pouco e por que existe cobrança acima do
/// limite (e como ela funciona).
class _HowWeSave extends StatelessWidget {
  const _HowWeSave({required this.r, required this.plan});

  final UsageReport r;
  final Plan plan;

  static final NumberFormat _int = NumberFormat.decimalPattern('pt_BR');

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    Widget item(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(text, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Icon(Icons.eco_outlined, color: primary),
        title: Text(
          'Como deixamos sua loja leve: ${plan.maxStorageGb} GB ≈ '
          '${_int.format(r.photosIncluded)} fotos',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        children: <Widget>[
          item(Icons.compress, 'Fotos comprimidas, sem perder qualidade',
              'Uma foto de celular tem 3 a 5 MB. Ao enviar, o app reduz para '
                  'cerca de 250 KB no tamanho certo para a tela do celular — '
                  'a diferença não aparece, mas ocupa até 20× menos espaço.'),
          item(Icons.grid_view, 'Miniatura nas listas',
              'Na vitrine e nas buscas mostramos uma versão pequena (~40 KB) '
                  'de cada foto; a grande só abre na página do produto. A '
                  'loja abre mais rápido e gasta menos internet do cliente.'),
          item(Icons.phone_android, 'Cache no aparelho',
              'Cada foto é baixada uma vez e fica guardada no celular/'
                  'navegador do cliente. Ao voltar à loja, nada é baixado de '
                  'novo — e o catálogo só busca o que mudou.'),
          item(Icons.cloud_outlined, 'Por que existe limite',
              'Fotos e visitas ficam na nuvem (Google). Guardar fotos e '
                  'cada cliente abrindo a loja têm custo por uso. O plano '
                  'já inclui um volume generoso: '
                  '${_int.format(plan.maxVisits)} visitas, '
                  '${_int.format(plan.maxProducts)} produtos e '
                  '${plan.maxStorageGb} GB de fotos por mês.'),
          item(Icons.trending_up, 'Se a loja crescer além disso',
              'Mais clientes ativos geram mais custo de servidor, então '
                  'cobramos ${Br.money(UsageReport.pricePerBlock)} a cada '
                  '1.000 visitas, 100 produtos ou 1 GB a mais, junto da '
                  'mensalidade seguinte — com teto de '
                  '${Br.money(UsageReport.maxExtraCharge)} por mês. Você vê '
                  'o uso aqui antes de qualquer cobrança.'),
          item(Icons.lightbulb_outline, 'Para economizar espaço',
              'Apague fotos de produtos que saíram de linha ou use foto por '
                  'link (ex.: do seu anúncio na Shopee), que não ocupa '
                  'espaço da loja. Se crescer muito, o plano maior sai mais '
                  'em conta que o adicional.'),
        ],
      ),
    );
  }
}
