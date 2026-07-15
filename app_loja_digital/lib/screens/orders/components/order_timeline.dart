import 'package:app_loja_digital/models/order.dart';
import 'package:flutter/material.dart';

/// Mostra ao cliente o andamento do pedido, da separação até a entrega.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline(this.status, {super.key});

  final Status status;

  static const _steps = <_Step>[
    _Step(Status.preparing, Icons.inventory_2_outlined, 'Em separação'),
    _Step(Status.transporting, Icons.local_shipping_outlined, 'A caminho'),
    _Step(Status.delivered, Icons.check_circle_outline, 'Entregue'),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

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

    // preparing(1) -> 0, transporting(2) -> 1, delivered(3) -> 2
    final int currentIndex = status.index - 1;

    final List<Widget> row = [];
    for (int i = 0; i < _steps.length; i++) {
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
              child: Icon(_steps[i].icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 72,
              child: Text(
                _steps[i].label,
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

      if (i < _steps.length - 1) {
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
