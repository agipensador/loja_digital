/// Monta o deep-link do Uber com origem/destino preenchidos, para o motoboy
/// (ou o cliente) abrir o app/site do Uber e solicitar a corrida. Sem API
/// paga — é só a URL de "Request a ride" do Uber com endereços em texto.
/// Doc: https://developer.uber.com/docs/riders/ride-requests/tutorials/deep-links/introduction
class UberLinkHelper {
  UberLinkHelper._();

  /// `uber://` abre o app nativo quando instalado; o site
  /// `m.uber.com` serve de fallback automático quando não está.
  static String buildWebFallbackLink({
    required String pickupAddress,
    required String dropoffAddress,
  }) {
    final params = {
      'action': 'setPickup',
      'pickup[formatted_address]': pickupAddress,
      'dropoff[formatted_address]': dropoffAddress,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://m.uber.com/ul/?$query';
  }
}
