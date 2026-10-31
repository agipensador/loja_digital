import { ProductDoc } from './documents';
import { erroDeNegocio } from './errors';
import { decrementStock, groupByProduct, ItemRequest } from './pricing';
import { PlanoDaReserva } from '../data/repository';

/**
 * A parte delicada da transação, isolada e pura: com o que foi lido DENTRO da
 * transação, decide o número do pedido e o novo estoque de cada produto.
 *
 * Fica aqui, e não dentro do `runTransaction`, porque é exatamente o trecho
 * em que uma compra simultânea pode vender a última peça duas vezes — e
 * porque assim dá para testar sem banco.
 */
export function planejarReserva(args: {
  items: ItemRequest[];
  /** Produtos relidos DENTRO da transação. */
  products: Map<string, ProductDoc | null>;
  /** `current` do contador stores/{id}/counters/ordercounter. */
  numeroAtual: number;
}): PlanoDaReserva {
  const porProduto = groupByProduct(args.items);
  const novosSizes = new Map<string, ReturnType<typeof decrementStock>>();

  for (const [pid, itens] of porProduto) {
    const product = args.products.get(pid);
    if (!product || product.deleted === true) {
      throw erroDeNegocio('produto-indisponivel', 'Produto indisponível.');
    }
    novosSizes.set(pid, decrementStock(product, itens));
  }

  return {
    proximoNumero: args.numeroAtual + 1,
    novosSizes,
  };
}
