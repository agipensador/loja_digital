import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  assinarParaTeste,
  verificarAssinatura,
} from '../src/domain/signature';

/**
 * Esta é a trava que impede alguém de postar "pagamento aprovado" na URL do
 * webhook e levar produto sem pagar. Cada caso abaixo é uma forma de tentar.
 */

const segredo = 'segredo-do-painel-do-mp';
const dataId = '1234567890';
const requestId = 'req-abc-123';
const tsSegundos = 1795000000;
const agoraMs = tsSegundos * 1000;

function cabecalhoValido(): string {
  return assinarParaTeste({ dataId, requestId, secret: segredo, tsSegundos });
}

describe('verificarAssinatura', () => {
  it('aceita a assinatura que o Mercado Pago montaria', () => {
    const r = verificarAssinatura({
      signature: cabecalhoValido(),
      requestId,
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, true);
  });

  it('aceita quando o MP não mandou request-id', () => {
    const r = verificarAssinatura({
      signature: assinarParaTeste({ dataId, secret: segredo, tsSegundos }),
      requestId: undefined,
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, true);
  });

  it('aceita o v1 em letra maiúscula', () => {
    const header = cabecalhoValido().toUpperCase().replace('TS=', 'ts=');
    const r = verificarAssinatura({
      signature: header.replace('V1=', 'v1='),
      requestId,
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, true);
  });

  it('recusa hmac de outro segredo', () => {
    const r = verificarAssinatura({
      signature: assinarParaTeste({
        dataId,
        requestId,
        secret: 'segredo-errado',
        tsSegundos,
      }),
      requestId,
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'hmac-diferente');
  });

  it('recusa quando o data.id não é o que foi assinado (troca de pagamento)', () => {
    const r = verificarAssinatura({
      signature: cabecalhoValido(),
      requestId,
      dataId: '999',
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'hmac-diferente');
  });

  it('recusa quando o request-id não é o que foi assinado', () => {
    const r = verificarAssinatura({
      signature: cabecalhoValido(),
      requestId: 'outro-request',
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'hmac-diferente');
  });

  it('recusa sem o cabeçalho x-signature', () => {
    const r = verificarAssinatura({
      signature: undefined,
      requestId,
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'cabecalho-ausente');
  });

  it('recusa cabeçalho sem ts ou sem v1', () => {
    for (const header of ['v1=abc', 'ts=1795000000', 'lixo', '']) {
      const r = verificarAssinatura({
        signature: header,
        requestId,
        dataId,
        secret: segredo,
        agoraMs,
      });
      assert.equal(r.valida, false, `aceitou "${header}"`);
    }
  });

  it('recusa aviso antigo reenviado fora da janela', () => {
    const r = verificarAssinatura({
      signature: cabecalhoValido(),
      requestId,
      dataId,
      secret: segredo,
      agoraMs: agoraMs + 10 * 60 * 1000,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'ts-fora-da-janela');
  });

  it('aceita dentro da janela de tolerância', () => {
    const r = verificarAssinatura({
      signature: cabecalhoValido(),
      requestId,
      dataId,
      secret: segredo,
      agoraMs: agoraMs + 4 * 60 * 1000,
    });
    assert.equal(r.valida, true);
  });

  it('recusa ts que não é número', () => {
    const r = verificarAssinatura({
      signature: 'ts=agora,v1=abc',
      requestId,
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'ts-invalido');
  });

  it('recusa sem data.id', () => {
    const r = verificarAssinatura({
      signature: cabecalhoValido(),
      requestId,
      dataId: undefined,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'sem-data-id');
  });

  it('sem segredo configurado NÃO aceita nada (falha fechada)', () => {
    const r = verificarAssinatura({
      signature: cabecalhoValido(),
      requestId,
      dataId,
      secret: '',
      agoraMs,
    });
    assert.equal(r.valida, false);
    assert.equal(r.motivo, 'sem-segredo');
  });

  it('entende ts em milissegundos (aviso de formato antigo)', () => {
    const molde = assinarParaTeste({
      dataId,
      requestId,
      secret: segredo,
      tsSegundos: agoraMs,
    });
    const r = verificarAssinatura({
      signature: molde,
      requestId,
      dataId,
      secret: segredo,
      agoraMs,
    });
    assert.equal(r.valida, true);
  });
});
