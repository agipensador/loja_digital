import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const List<String> _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Relatório financeiro'),
        centerTitle: true,
      ),
      body: Consumer<OrdersManager>(
        builder: (_, ordersManager, __) {
          final orders = ordersManager.ordersForMonth(_month)
            ..sort((a, b) {
              final da = a.date?.millisecondsSinceEpoch ?? 0;
              final db = b.date?.millisecondsSinceEpoch ?? 0;
              return da.compareTo(db);
            });
          final revenue = ordersManager.monthRevenue(_month);
          final products = ordersManager.monthProductsRevenue(_month);
          final delivery = ordersManager.monthDeliveryRevenue(_month);
          final count = orders.length;

          final Map<int, num> byDay = {};
          for (final order in orders) {
            final day = order.date?.toDate().day;
            if (day == null) continue;
            byDay[day] = (byDay[day] ?? 0) +
                order.productsPrice +
                order.deliveryPrice;
          }
          final days = byDay.keys.toList()..sort();

          return Column(
            children: <Widget>[
              Container(
                color: primaryColor.withAlpha(15),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      '${_monthNames[_month.month - 1]} de ${_month.year}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _SummaryCard(
                        label: 'Receita do mês',
                        value: Br.money(revenue),
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pedidos',
                        value: '$count',
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Produtos ${Br.money(products)} · '
                  'Frete ${Br.money(delivery)}\n'
                  'Valores brutos, antes das tarifas do meio de pagamento.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Expanded(
                child: days.isEmpty
                    ? const Center(child: Text('Nenhum pedido neste mês.'))
                    : ListView.builder(
                        itemCount: days.length,
                        itemBuilder: (_, i) {
                          final day = days[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withAlpha(30),
                              child: Text('$day'),
                            ),
                            title: Text(
                                'Dia $day/${_month.month.toString().padLeft(2, '0')}'),
                            trailing: Text(
                              Br.money(byDay[day]!),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
