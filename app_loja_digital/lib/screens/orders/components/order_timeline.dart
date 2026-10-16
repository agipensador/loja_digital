import 'package:app_loja_digital/models/order.dart';
import 'package:flutter/material.dart';

/// Mostra ao cliente o andamento do pedido, da separação até a entrega.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline(this.status, {super.key, this.pickup = false});

  final Status status;

  /// Retirada na loja: "Pronto para retirada" no lugar de "A caminho".
  final bool pickup;

  List<_Step> get _steps => <_Step>[
        const _Step(
            Status.pendingPayment, Icons.payments_outlined, 'Pagamento'),
        const _Step(Status.preparing, Icons.inventory_2_outlined, 'Em separação'),
        pickup
            ? const _Step(
                Status.readyForPickup, Icons.storefront, 'Pronto p/ retirar')
            : const _Step(
                Status.transporting, Icons.local_shipping_outlined, 'A caminho'),
        _Step(Status.delivered, Icons.check_circle_outline,
            pickup ? 'Retirado' : 'Entregue'),
      ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final steps = _steps;

    if (status == Status.canceled) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Pedido cancelado',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final int currentIndex = steps.indexWhere((s) => s.status == status);

    final List<Widget> row = [];
    for (int i = 0; i < steps.length; i++) {
      final bool reached = i <= currentIndex;
      final Color color = reached ? primaryColor : Colors.grey.shade300;
      final Color textColor = reached ? primaryColor : Colors.grey;

      row.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: color,
              child: Icon(steps[i].icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 72,
              child: Text(
                steps[i].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontWeight:
                      i == currentIndex ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );

      if (i < steps.length - 1) {
        row.add(
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 24),
              color: i < currentIndex ? primaryColor : Colors.grey.shade300,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: row),
    );
  }
}

class _Step {
  const _Step(this.status, this.icon, this.label);
  final Status status;
  final IconData icon;
  final String label;
}
