/**
 * Erros de negócio do checkout.
 *
 * Mensagem em pt-BR, porque é ela que o app mostra ao cliente — o app ainda
 * não tem os textos nos `.arb` (ver docs/ARQUITETURA_SAAS.md, "Idiomas").
 * O [code] é estável e serve para o app decidir o que fazer (ex.: mandar o
 * lojista conectar o Mercado Pago).
 */
export class CheckoutError extends Error {
  constructor(
    readonly code: CheckoutErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'CheckoutError';
  }
}

export type CheckoutErrorCode =
  | 'loja-indisponivel'
  | 'mp-nao-conectado'
  | 'carrinho-vazio'
  | 'produto-indisponivel'
  | 'tamanho-indisponivel'
  | 'estoque-insuficiente'
  | 'entrega-invalida'
  | 'pedido-invalido'
  | 'pagamento-recusado'
  | 'provedor-indisponivel';

export function erroDeNegocio(
  code: CheckoutErrorCode,
  message: string,
): CheckoutError {
  return new CheckoutError(code, message);
}
