import {
  DocumentSnapshot,
  FieldValue,
  Firestore,
  Timestamp,
  Transaction,
} from 'firebase-admin/firestore';

import {
  LocationDoc,
  MpCredentialsDoc,
  ProductDoc,
  StoreDoc,
  ZoneDoc,
} from '../domain/documents';
import { erroDeNegocio } from '../domain/errors';
import { CheckoutStatus, OrderStatus } from '../domain/payment_status';
import { restoreStock } from '../domain/pricing';
import { planejarReserva } from '../domain/reserva';
import {
  AtualizacaoDePagamento,
  CheckoutDoc,
  CheckoutRepository,
  DadosDoCheckout,
  ReservaPedido,
  ResultadoDaReserva,
} from './repository';

/**
 * Implementação em Firestore do [CheckoutRepository]. Só cola: toda decisão
 * de negócio está em `src/domain` (puro e testado). O que vive aqui é o
 * caminho dos documentos e a transação.
 *
 * Caminhos (ver docs/ARQUITETURA_SAAS.md §2.5):
 *   stores/{storeId}                       — o tenant
 *   stores/{storeId}/private/mp            — token do MP (rules: ninguém lê)
 *   stores/{storeId}/locations/{id}        — unidade física
 *   stores/{storeId}/deliveryZones/{id}    — área de entrega própria
 *   stores/{storeId}/products/{pid}        — catálogo e estoque
 *   stores/{storeId}/counters/ordercounter — número do pedido
 *   stores/{storeId}/orders/{orderId}      — pedido
 *   stores/{storeId}/checkouts/{id}        — tentativa de pagamento
 *   mpPayments/{paymentId}                 — de pagamento do MP para o checkout
 *   platform/mpWebhookEvents/items/{id}    — avisos já processados
 */
export class FirestoreCheckoutRepository implements CheckoutRepository {
  constructor(private readonly db: Firestore) {}

  private loja(storeId: string) {
    return this.db.collection('stores').doc(storeId);
  }

  private checkoutRef(storeId: string, checkoutId: string) {
    return this.loja(storeId).collection('checkouts').doc(checkoutId);
  }

  private pedidoRef(storeId: string, orderId: string) {
    return this.loja(storeId).collection('orders').doc(orderId);
  }

  async carregar(args: {
    storeId: string;
    locationId: string;
    zoneId?: string;
    pids: string[];
  }): Promise<DadosDoCheckout> {
    const loja = this.loja(args.storeId);
    const [storeSnap, mpSnap, locationSnap, zoneSnap, ...productSnaps] =
      await this.db.getAll(
        loja,
        loja.collection('private').doc('mp'),
        loja.collection('locations').doc(args.locationId),
        // `getAll` não aceita referência nula: sem zona, lê um id impossível.
        loja.collection('deliveryZones').doc(args.zoneId ?? '__sem_zona__'),
        ...args.pids.map((pid) => loja.collection('products').doc(pid)),
      );

    if (!storeSnap.exists) {
      throw erroDeNegocio('loja-indisponivel', 'Loja não encontrada.');
    }

    const products = new Map<string, ProductDoc>();
    for (const snap of productSnaps) {
      if (snap.exists) products.set(snap.id, snap.data() as ProductDoc);
    }

    return {
      store: storeSnap.data() as StoreDoc,
      credenciais: mpSnap.exists ? (mpSnap.data() as MpCredentialsDoc) : null,
      // Loja de uma unidade só pode não ter o documento: valem os padrões
      // de `Store` no app (retirada e Correios ligados).
      location: locationSnap.exists
        ? (locationSnap.data() as LocationDoc)
        : {},
      zone: zoneSnap.exists ? (zoneSnap.data() as ZoneDoc) : null,
      products,
    };
  }

  async buscarCheckout(
    storeId: string,
    checkoutId: string,
  ): Promise<CheckoutDoc | null> {
    const snap = await this.checkoutRef(storeId, checkoutId).get();
    return snap.exists ? lerCheckout(snap) : null;
  }

  async reservar(reserva: ReservaPedido): Promise<ResultadoDaReserva> {
    const loja = this.loja(reserva.storeId);
    const counterRef = loja.collection('counters').doc('ordercounter');
    const pids = [...new Set(reserva.items.map((i) => i.pid))];

    return this.db.runTransaction(async (tx: Transaction) => {
      // ---- LEITURAS (antes de qualquer escrita, como exige o Firestore) ----
      const checkoutSnap = await tx.get(
        this.checkoutRef(reserva.storeId, reserva.checkoutId),
      );
      if (checkoutSnap.exists) {
        // Duas chamadas com a mesma chave ao mesmo tempo: a 2ª não reserva.
        const existente = lerCheckout(checkoutSnap);
        return { orderId: existente.orderId };
      }

      const counterSnap = await tx.get(counterRef);
      const productSnaps = await Promise.all(
        pids.map((pid) => tx.get(loja.collection('products').doc(pid))),
      );
      const products = new Map<string, ProductDoc | null>();
      productSnaps.forEach((snap, i) => {
        products.set(pids[i], snap.exists ? (snap.data() as ProductDoc) : null);
      });

      // ---- DECISÃO (pura, testada em test/reserva.test.ts) ----
      const plano = planejarReserva({
        items: reserva.items,
        products,
        numeroAtual: (counterSnap.data()?.current as number | undefined) ?? 0,
      });
      const orderId = String(plano.proximoNumero);

      // ---- ESCRITAS ----
      for (const [pid, sizes] of plano.novosSizes) {
        tx.update(loja.collection('products').doc(pid), {
          sizes,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      tx.set(counterRef, { current: plano.proximoNumero });

      tx.set(this.pedidoRef(reserva.storeId, orderId), {
        items: reserva.lines.map((line) => ({
          pid: line.pid,
          quantity: line.quantity,
          size: line.size,
          locationId: line.locationId,
          name: line.name,
          price: line.price,
          image: line.image,
        })),
        price: reserva.total,
        productsPrice: reserva.productsPrice,
        deliveryPrice: reserva.deliveryPrice,
        serviceFee: reserva.serviceFee,
        platformFee: reserva.platformFee,
        user: reserva.userId,
        address: reserva.address,
        // Nasce aguardando pagamento: só o webhook (ou o cartão aprovado na
        // hora) passa para "em separação".
        status: OrderStatus.pendingPayment,
        payment: reserva.paymentLabel,
        locationId: reserva.locationId,
        shipping: {
          method: reserva.shipping.method,
          carrier: '',
          trackingCode: '',
          trackingUrl: '',
          shippedAt: null,
          scheduledDate: null,
          preferredDate: reserva.shipping.preferredDate
            ? Timestamp.fromDate(reserva.shipping.preferredDate)
            : null,
          zoneId: reserva.shipping.zoneId,
        },
        date: FieldValue.serverTimestamp(),
        checkoutId: reserva.checkoutId,
      });

      tx.set(this.checkoutRef(reserva.storeId, reserva.checkoutId), {
        storeId: reserva.storeId,
        orderId,
        userId: reserva.userId,
        status: 'pending' satisfies CheckoutStatus,
        total: reserva.total,
        platformFee: reserva.platformFee,
        paymentType: reserva.paymentType,
        items: reserva.items.map((item) => ({
          pid: item.pid,
          size: item.size,
          quantity: item.quantity,
          locationId: item.locationId,
        })),
        createdAt: FieldValue.serverTimestamp(),
      });

      return { orderId };
    });
  }

  async registrarPagamento(
    storeId: string,
    checkoutId: string,
    dados: AtualizacaoDePagamento,
  ): Promise<void> {
    const batch = this.db.batch();
    batch.set(
      this.checkoutRef(storeId, checkoutId),
      {
        mpPaymentId: dados.mpPaymentId,
        mpStatus: dados.mpStatus,
        status: dados.checkoutStatus,
        pixCopyPaste: dados.pixCopyPaste ?? null,
        pixQrBase64: dados.pixQrBase64 ?? null,
        pixExpiresAt: dados.pixExpiresAt ?? null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    // Índice de ida e volta: o webhook só conhece o id do pagamento.
    if (dados.mpPaymentId) {
      batch.set(this.db.collection('mpPayments').doc(dados.mpPaymentId), {
        storeId,
        checkoutId,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  async confirmarPedido(args: {
    storeId: string;
    checkoutId: string;
    mpPaymentId: string;
    mpStatus: string;
  }): Promise<void> {
    await this.db.runTransaction(async (tx) => {
      const checkoutRef = this.checkoutRef(args.storeId, args.checkoutId);
      const checkoutSnap = await tx.get(checkoutRef);
      if (!checkoutSnap.exists) return;
      const checkout = lerCheckout(checkoutSnap);

      const pedidoRef = this.pedidoRef(args.storeId, checkout.orderId);
      const pedidoSnap = await tx.get(pedidoRef);

      tx.set(
        checkoutRef,
        {
          status: 'paid' satisfies CheckoutStatus,
          mpPaymentId: args.mpPaymentId,
          mpStatus: args.mpStatus,
          paidAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Só sai de "aguardando pagamento": se a loja já avançou o pedido
      // (separação, transporte), o aviso atrasado não anda para trás.
      if (
        pedidoSnap.exists &&
        pedidoSnap.data()?.status === OrderStatus.pendingPayment
      ) {
        tx.update(pedidoRef, {
          status: OrderStatus.preparing,
          paidAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  async liberarReserva(args: {
    storeId: string;
    checkoutId: string;
    status: CheckoutStatus;
    mpStatus?: string;
  }): Promise<void> {
    const loja = this.loja(args.storeId);
    await this.db.runTransaction(async (tx) => {
      const checkoutRef = this.checkoutRef(args.storeId, args.checkoutId);
      const checkoutSnap = await tx.get(checkoutRef);
      if (!checkoutSnap.exists) return;
      const checkout = lerCheckout(checkoutSnap);

      // Já liberado antes: não devolve estoque duas vezes.
      if (checkoutSnap.data()?.stockReleased === true) {
        tx.set(
          checkoutRef,
          { status: args.status, updatedAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
        return;
      }

      const porProduto = new Map<string, typeof checkout.items>();
      for (const item of checkout.items) {
        const lista = porProduto.get(item.pid);
        if (lista) lista.push(item);
        else porProduto.set(item.pid, [item]);
      }

      const pids = [...porProduto.keys()];
      const productSnaps = await Promise.all(
        pids.map((pid) => tx.get(loja.collection('products').doc(pid))),
      );
      const pedidoRef = this.pedidoRef(args.storeId, checkout.orderId);
      const pedidoSnap = await tx.get(pedidoRef);

      productSnaps.forEach((snap, i) => {
        if (!snap.exists) return;
        const sizes = restoreStock(
          snap.data() as ProductDoc,
          porProduto.get(pids[i])!,
        );
        tx.update(snap.ref, {
          sizes,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      tx.set(
        checkoutRef,
        {
          status: args.status,
          mpStatus: args.mpStatus ?? checkout.mpStatus ?? '',
          stockReleased: true,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // O pedido só é cancelado se ainda não foi pago/separado.
      if (
        pedidoSnap.exists &&
        pedidoSnap.data()?.status === OrderStatus.pendingPayment
      ) {
        tx.update(pedidoRef, { status: OrderStatus.canceled });
      }
    });
  }

  async checkoutPorPagamento(mpPaymentId: string): Promise<CheckoutDoc | null> {
    const indice = await this.db.collection('mpPayments').doc(mpPaymentId).get();
    const storeId = indice.data()?.storeId as string | undefined;
    const checkoutId = indice.data()?.checkoutId as string | undefined;
    if (!storeId || !checkoutId) return null;
    return this.buscarCheckout(storeId, checkoutId);
  }

  async credenciaisDaLoja(storeId: string): Promise<MpCredentialsDoc | null> {
    const snap = await this.loja(storeId).collection('private').doc('mp').get();
    return snap.exists ? (snap.data() as MpCredentialsDoc) : null;
  }

  async registrarAviso(avisoId: string): Promise<boolean> {
    const ref = this.db
      .collection('platform')
      .doc('mpWebhookEvents')
      .collection('items')
      .doc(avisoId);
    try {
      // `create` falha se o documento existe — é a trava de idempotência.
      await ref.create({
        processedAt: FieldValue.serverTimestamp(),
        // Para uma política de TTL no Firestore limpar sozinho (30 dias).
        expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 3600 * 1000),
      });
      return true;
    } catch {
      return false;
    }
  }
}

function lerCheckout(snap: DocumentSnapshot): CheckoutDoc {
  const data = snap.data() ?? {};
  return {
    id: snap.id,
    storeId: (data.storeId as string) ?? '',
    orderId: (data.orderId as string) ?? '',
    userId: (data.userId as string) ?? '',
    status: ((data.status as CheckoutStatus) ?? 'pending') as CheckoutStatus,
    total: (data.total as number) ?? 0,
    platformFee: (data.platformFee as number) ?? 0,
    paymentType: (data.paymentType as string) ?? '',
    mpPaymentId: data.mpPaymentId as string | undefined,
    mpStatus: data.mpStatus as string | undefined,
    pixCopyPaste: (data.pixCopyPaste as string | null) ?? undefined,
    pixQrBase64: (data.pixQrBase64 as string | null) ?? undefined,
    pixExpiresAt: (data.pixExpiresAt as string | null) ?? undefined,
    items: Array.isArray(data.items)
      ? (data.items as Record<string, unknown>[]).map((item) => ({
          pid: (item.pid as string) ?? '',
          size: (item.size as string) ?? '',
          quantity: (item.quantity as number) ?? 0,
          locationId: (item.locationId as string) ?? 'principal',
        }))
      : [],
  };
}
