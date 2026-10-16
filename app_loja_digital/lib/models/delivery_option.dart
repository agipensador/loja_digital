import 'package:app_loja_digital/models/delivery_zone.dart';
import 'package:app_loja_digital/models/store.dart';

/// Chaves gravadas em `OrderShipping.method` — não renomear.
class DeliveryMethods {
  DeliveryMethods._();
  static const ownDelivery = 'entrega_propria';
  static const pickup = 'retirada';
  static const uber = 'uber';
  static const correios = 'correios';
}

/// Uma forma de receber o pedido que a unidade oferece para este endereço.
class DeliveryOption {
  const DeliveryOption({
    required this.method,
    required this.fee,
    required this.title,
    required this.detail,
    this.zone,
  });

  final String method;
  final num fee;
  final String title;
  final String detail;

  /// Área da entrega própria (datas disponíveis), quando [method] é ela.
  final DeliveryZone? zone;

  /// Opções da [location] para o endereço do cliente. A entrega própria só
  /// aparece se alguma área da unidade cobrir o endereço ([zone]).
  static List<DeliveryOption> forLocation(Store location, DeliveryZone? zone,
      {num? uberEstimate}) {
    return [
      if (location.offersOwnDelivery && zone != null)
        DeliveryOption(
          method: DeliveryMethods.ownDelivery,
          fee: zone.fee,
          title: 'Entrega da loja (${zone.name})',
          detail: 'A loja entrega no seu endereço no dia combinado.',
          zone: zone,
        ),
      if (location.offersPickup)
        DeliveryOption(
          method: DeliveryMethods.pickup,
          fee: 0,
          title: 'Retirada: ${location.name}',
          detail: location.address,
        ),
      if (location.offersUber)
        DeliveryOption(
          method: DeliveryMethods.uber,
          fee: uberEstimate ?? location.uberFee,
          title: 'Motoboy (Uber)',
          detail: 'Estimativa pela distância; a loja confirma o valor.',
        ),
      if (location.offersShipping)
        DeliveryOption(
          method: DeliveryMethods.correios,
          fee: location.shippingFee,
          title: 'Correios',
          detail: 'Envio com código de rastreio.',
        ),
    ];
  }
}
