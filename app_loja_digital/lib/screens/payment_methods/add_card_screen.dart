import 'package:app_loja_digital/models/payment_manager.dart';
import 'package:app_loja_digital/screens/payment_methods/components/credit_card_widget.dart';
import 'package:app_loja_digital/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _cvvFocus = FocusNode();

  bool _debit = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Vira o cartão quando o CVV recebe foco.
    _cvvFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final parts = _expiry.text.split('/');
    setState(() => _loading = true);
    try {
      await context.read<PaymentManager>().addCard(
            RawCard(
              number: _number.text,
              holder: _holder.text.trim(),
              expMonth: int.tryParse(parts[0]) ?? 0,
              expYear: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
              cvv: _cvv.text,
            ),
            debit: _debit,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Adicionar cartão'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: CreditCardWidget(
                  number: _number.text,
                  holder: _holder.text,
                  expiry: _expiry.text,
                  cvv: _cvv.text,
                  showBack: _cvvFocus.hasFocus,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _number,
              decoration: const InputDecoration(
                  labelText: 'Número do cartão', counterText: ''),
              keyboardType: TextInputType.number,
              maxLength: 19,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return d.length < 13 ? 'Número inválido' : null;
              },
            ),
            TextFormField(
              controller: _holder,
              decoration: const InputDecoration(labelText: 'Nome no cartão'),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Informe o nome' : null,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _expiry,
                    decoration: const InputDecoration(
                        labelText: 'Validade', hintText: 'MM/AA'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ExpiryFormatter()],
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        RegExp(r'^\d{2}/\d{2}$').hasMatch(v ?? '')
                            ? null
                            : 'MM/AA',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvv,
                    focusNode: _cvvFocus,
                    decoration: const InputDecoration(
                        labelText: 'CVV', counterText: ''),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        (v == null || v.length < 3) ? 'CVV' : null,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('É cartão de débito'),
              value: _debit,
              onChanged: (v) => setState(() => _debit = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white))
                    : const Text('Salvar cartão',
                        style: TextStyle(fontSize: 18)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Guardamos apenas os últimos 4 dígitos e a bandeira. '
                'O número completo é tokenizado pelo provedor de pagamento.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formata a validade como MM/AA automaticamente.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    String out = limited;
    if (limited.length >= 3) {
      out = '${limited.substring(0, 2)}/${limited.substring(2)}';
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}
