import 'package:app_loja_digital/models/payment_manager.dart';
import 'package:app_loja_digital/screens/payment_methods/components/brand_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Formas de pagamento'),
        centerTitle: true,
      ),
      body: Consumer<PaymentManager>(
        builder: (_, payment, __) {
          if (!payment.isLoggedIn) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Entre para cadastrar formas de pagamento.',
                    textAlign: TextAlign.center),
              ),
            );
          }

          return ListView(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('Cartões',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final card in payment.cards)
                RadioListTile<String>(
                  value: card.id!,
                  groupValue: payment.selectedMethod,
                  onChanged: (v) => payment.selectMethod(v!),
                  title: Row(
                    children: <Widget>[
                      BrandIcon(card.brand, color: primaryColor, size: 28),
                      const SizedBox(width: 8),
                      Expanded(child: Text(card.masked)),
                    ],
                  ),
                  subtitle: Text(
                    '${card.holder} · ${card.expiry}'
                    '${card.debit ? ' · Débito' : ' · Crédito'}',
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => payment.removeCard(card),
                  ),
                ),
              ListTile(
                leading: Icon(Icons.add_card, color: primaryColor),
                title: const Text('Adicionar cartão de crédito/débito'),
                onTap: () =>
                    Navigator.of(context).pushNamed('/add_card'),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child:
                    Text('Pix', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              RadioListTile<String>(
                value: kPixMethod,
                groupValue: payment.selectedMethod,
                onChanged: (v) => payment.selectMethod(v!),
                secondary: Icon(Icons.pix, color: primaryColor),
                title: const Text('Pix'),
                subtitle: const Text('QR e copia-e-cola gerados no pagamento'),
              ),
            ],
          );
        },
      ),
    );
  }
}
