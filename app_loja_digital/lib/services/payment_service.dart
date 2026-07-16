/// Camada de pagamento — abstrai o provedor para permitir plugar o
/// Mercado Pago depois sem tocar nas telas.
///
/// COMO PLUGAR O MERCADO PAGO (passos futuros):
/// 1. Adicionar a dependência do SDK (ex.: `mercado_pago_...`) no pubspec.
/// 2. Definir a Public Key do MP em [MercadoPagoConfig.publicKey] (via
///    --dart-define, nunca commitada) e o Access Token SÓ no backend
///    (Cloud Functions) — nunca no app.
/// 3. Implementar [MercadoPagoService] usando o SDK:
///    - createCardToken: tokeniza o cartão no dispositivo (o número real
///      NUNCA sai tokenizado para o nosso banco).
///    - createCardPayment / createPixPayment: chamam uma Cloud Function que
///      usa o Access Token e retorna o resultado (e o QR/copia-e-cola do Pix).
/// 4. Trocar o provider em main.dart de [FakePaymentService] para
///    [MercadoPagoService].
///
/// MODELO MARKETPLACE (cliente paga a loja, o app retém a taxa):
/// - Cada loja conecta a PRÓPRIA conta Mercado Pago via OAuth (split).
/// - Na cobrança, o dinheiro vai para a conta da loja ([sellerId]) e o app
///   retém automaticamente a taxa ([feeAmount] = application_fee).
/// - A taxa vem de [MercadoPagoConfig.marketplaceFeePercent].
///
/// IMPORTANTE (Google Play): produtos FÍSICOS NÃO podem usar In-App Purchase
/// do Google — a política exige gateway externo (Mercado Pago/Pix/cartão).
/// IAP só serve para conteúdo/serviços DIGITAIS consumidos no próprio app.
library;

enum PaymentType { credit, debit, pix }

/// Dados brutos do cartão, usados APENAS em memória para tokenizar.
/// Nunca persistir estes campos (número completo / CVV).
class RawCard {
  RawCard({
    required this.number,
    required this.holder,
    required this.expMonth,
    required this.expYear,
    required this.cvv,
  });

  final String number;
  final String holder;
  final int expMonth;
  final int expYear;
  final String cvv;
}

class PaymentResult {
  PaymentResult({
    required this.approved,
    this.message,
    this.transactionId,
    this.pixCopyPaste,
    this.pixQrBase64,
  });

  final bool approved;
  final String? message;
  final String? transactionId;
  final String? pixCopyPaste; // Pix "copia e cola"
  final String? pixQrBase64; // imagem do QR em base64
}

class MercadoPagoConfig {
  /// Defina via: flutter run --dart-define=MP_PUBLIC_KEY=APP_USR-xxxx
  static const String publicKey =
      String.fromEnvironment('MP_PUBLIC_KEY', defaultValue: '');

  /// URL do backend (Cloud Functions) que fala com o Access Token do MP.
  /// --dart-define=MP_BACKEND_URL=https://us-central1-<proj>.cloudfunctions.net
  static const String backendUrl =
      String.fromEnvironment('MP_BACKEND_URL', defaultValue: '');

  /// Taxa de serviço do app (marketplace), em %, retida a cada venda.
  /// --dart-define=MP_MARKETPLACE_FEE=5
  static const String _feePercent =
      String.fromEnvironment('MP_MARKETPLACE_FEE', defaultValue: '5');

  static double get marketplaceFeePercent =>
      double.tryParse(_feePercent) ?? 0;

  /// Valor da taxa do app para um pedido (split marketplace).
  static num feeFor(num amount) =>
      (amount * marketplaceFeePercent / 100);

  static bool get isConfigured => publicKey.isNotEmpty;
}

abstract class PaymentService {
  /// Tokeniza o cartão (dados brutos -> token). O token é o que segue para
  /// o backend; o número real não é persistido.
  Future<String> createCardToken(RawCard card);

  /// Cobra no cartão (via token) o valor informado.
  /// [sellerId] = conta MP da loja (split marketplace); [feeAmount] = taxa
  /// do app retida na transação.
  Future<PaymentResult> payWithCard({
    required String cardToken,
    required num amount,
    required String orderId,
    String? sellerId,
    num feeAmount,
  });

  /// Gera uma cobrança Pix (retorna QR + copia-e-cola).
  Future<PaymentResult> payWithPix({
    required num amount,
    required String orderId,
    required String payerEmail,
    String? sellerId,
    num feeAmount,
  });
}

/// Implementação temporária (sem provedor real): aprova tudo localmente,
/// para o app funcionar de ponta a ponta antes do Mercado Pago entrar.
class FakePaymentService implements PaymentService {
  @override
  Future<String> createCardToken(RawCard card) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 'fake_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<PaymentResult> payWithCard({
    required String cardToken,
    required num amount,
    required String orderId,
    String? sellerId,
    num feeAmount = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return PaymentResult(
      approved: true,
      message: 'Pagamento simulado aprovado',
      transactionId: 'fake_$orderId',
    );
  }

  @override
  Future<PaymentResult> payWithPix({
    required num amount,
    required String orderId,
    required String payerEmail,
    String? sellerId,
    num feeAmount = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return PaymentResult(
      approved: true,
      message: 'Pix simulado gerado',
      transactionId: 'fake_pix_$orderId',
      pixCopyPaste:
          '00020126...FAKE-PIX-COPIA-E-COLA...5204000053039865802BR',
    );
  }
}

/// Esqueleto do provedor real — implementar quando plugar o SDK do MP.
class MercadoPagoService implements PaymentService {
  @override
  Future<String> createCardToken(RawCard card) {
    throw UnimplementedError(
        'Integrar SDK do Mercado Pago (createCardToken). '
        'Public Key configurada: ${MercadoPagoConfig.isConfigured}');
  }

  @override
  Future<PaymentResult> payWithCard({
    required String cardToken,
    required num amount,
    required String orderId,
    String? sellerId,
    num feeAmount = 0,
  }) {
    // TODO: POST ${MercadoPagoConfig.backendUrl}/payWithCard com
    // {cardToken, amount, orderId, sellerId, feeAmount(application_fee)}.
    throw UnimplementedError('Chamar Cloud Function do Mercado Pago (cartão).');
  }

  @override
  Future<PaymentResult> payWithPix({
    required num amount,
    required String orderId,
    required String payerEmail,
    String? sellerId,
    num feeAmount = 0,
  }) {
    // TODO: POST ${MercadoPagoConfig.backendUrl}/payWithPix com
    // {amount, orderId, payerEmail, sellerId, feeAmount(application_fee)}.
    throw UnimplementedError('Chamar Cloud Function do Mercado Pago (Pix).');
  }
}
