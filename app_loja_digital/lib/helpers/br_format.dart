import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatos brasileiros: dinheiro (R$ 1.234,56), CEP, CPF, telefone.
class Br {
  Br._();

  static final NumberFormat _money =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);

  /// R$ 1.234,56
  static String money(num value) => _money.format(value);

  /// Lê "1.234,56", "1234,56" ou "1234.56" (campos de preço).
  static num parseMoney(String text) {
    var t = text.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
    return num.tryParse(t) ?? 0;
  }

  /// Valor para preencher um campo de preço: "89,90".
  static String moneyInput(num value) =>
      value <= 0 ? '' : value.toStringAsFixed(2).replaceAll('.', ',');

  static String digits(String text) => text.replaceAll(RegExp(r'\D'), '');

  /// 93010-000
  static String cep(String text) {
    final d = digits(text);
    return d.length == 8 ? '${d.substring(0, 5)}-${d.substring(5)}' : text;
  }

  /// 123.456.789-09
  static String cpf(String text) {
    final d = digits(text);
    if (d.length != 11) return text;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.'
        '${d.substring(6, 9)}-${d.substring(9)}';
  }

  /// CPF válido (dígitos verificadores; rejeita 000.000.000-00 etc.).
  static bool isValidCpf(String text) {
    final d = digits(text);
    if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
    int check(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += int.parse(d[i]) * (len + 1 - i);
      }
      final r = (sum * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return check(9) == int.parse(d[9]) && check(10) == int.parse(d[10]);
  }
}

/// Máscara genérica: '#' = dígito. Ex.: '#####-###' (CEP).
class MaskFormatter extends TextInputFormatter {
  MaskFormatter(this.mask);

  final String mask;

  static final cep = MaskFormatter('#####-###');
  static final cpf = MaskFormatter('###.###.###-##');

  /// Celular com 9 dígitos; fixo cabe também (fica com um dígito a menos).
  static final phone = MaskFormatter('(##) #####-####');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    var i = 0;
    for (final ch in mask.split('')) {
      if (i >= digits.length) break;
      if (ch == '#') {
        buffer.write(digits[i++]);
      } else {
        buffer.write(ch);
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
