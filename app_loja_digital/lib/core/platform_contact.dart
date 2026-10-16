import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/helpers/br_format.dart';

/// Contatos da plataforma (Inforizz): suporte aos lojistas, venda dos planos
/// e reserva quando a loja ainda não cadastrou o próprio WhatsApp.
class PlatformContact {
  PlatformContact._();

  static const String name = 'Inforizz';

  /// WhatsApp da Inforizz: (11) 96706-4898.
  static const String whatsapp = '5511967064898';
  static const String whatsappLabel = '(11) 96706-4898';

  static const String email = 'mail.inforizz@gmail.com';

  /// Loja da própria Inforizz (vitrine que vende os planos).
  static const String storeId = 'inforizz';

  static bool get isPlatformStore => Tenant.storeId == storeId;

  /// Link do WhatsApp com a mensagem já escrita.
  static String waLink(String number, [String text = '']) {
    final d = Br.digits(number);
    final full = d.length <= 11 ? '55$d' : d;
    return text.isEmpty
        ? 'https://wa.me/$full'
        : 'https://wa.me/$full?text=${Uri.encodeComponent(text)}';
  }

  static String support([String text = '']) => waLink(whatsapp, text);
}
