#!/usr/bin/env node
// Provisiona (ou encerra) a loja no Firestore com o Admin SDK.
//
// Requer uma chave de conta de serviço (Console Firebase → Configurações do
// projeto → Contas de serviço → Gerar nova chave). NUNCA commitar a chave:
//   export GOOGLE_APPLICATION_CREDENTIALS=~/chaves/loja-digital-admin.json
//
// Uso:
//   node tool/provision_store.js create  <storeId> "<Nome>" <email-do-dono> [plano]
//   node tool/provision_store.js deactivate <storeId>
//   node tool/provision_store.js purge <storeId>      (APAGA dados e fotos)
const admin = require('firebase-admin');

const [, , action, storeId, name, ownerEmail, plan = 'unica'] = process.argv;
if (!action || !storeId) {
  console.error('Uso: provision_store.js create|deactivate|purge <storeId> ...');
  process.exit(1);
}
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Defina GOOGLE_APPLICATION_CREDENTIALS com a chave da conta de serviço.');
  process.exit(1);
}

admin.initializeApp({
  projectId: process.env.FIREBASE_PROJECT || 'loja-digital-ju0714',
  storageBucket: process.env.FIREBASE_BUCKET,
});
const db = admin.firestore();
const storeRef = db.collection('stores').doc(storeId);

async function create() {
  if (!name || !ownerEmail) throw new Error('Informe nome e e-mail do dono.');
  const snap = await storeRef.get();
  if (snap.exists) {
    console.log(`Loja ${storeId} já existe — nada a fazer.`);
    return;
  }
  const now = admin.firestore.Timestamp.now();
  const trialEnds = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 90 * 24 * 60 * 60 * 1000);
  await storeRef.set({
    name,
    slug: storeId,
    active: true,
    ownerUid: '',
    masters: [],
    // O dono vira admin ao entrar no app com este e-mail (ver rules).
    pendingOwnerEmail: ownerEmail.trim().toLowerCase(),
    plan,
    subscription: {
      startedAt: now,
      trialEndsAt: trialEnds,
      paidUntil: null,
      lastPaymentAt: null,
      lastPaymentMethod: '',
      paidCycles: 0,
    },
    serviceFee: { amount: 0.99, paidBy: 'store' },
    createdAt: now,
  });
  console.log(`Loja ${storeId} criada (trial até ${trialEnds.toDate().toISOString().slice(0, 10)}).`);
  console.log(`O dono deve criar a conta no app com ${ownerEmail} para assumir a loja.`);
}

async function deactivate() {
  await storeRef.update({
    active: false,
    closedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Loja ${storeId} desativada (dados preservados).`);
}

async function purge() {
  await db.recursiveDelete(storeRef);
  if (process.env.FIREBASE_BUCKET) {
    await admin.storage().bucket().deleteFiles({ prefix: `stores/${storeId}/` });
    console.log('Fotos apagadas do Storage.');
  } else {
    console.log('FIREBASE_BUCKET não definido: fotos NÃO foram apagadas.');
  }
  console.log(`Dados da loja ${storeId} apagados do Firestore.`);
}

const actions = { create, deactivate, purge };
if (!actions[action]) {
  console.error(`Ação desconhecida: ${action}`);
  process.exit(1);
}
actions[action]().then(() => process.exit(0)).catch((e) => {
  console.error('Erro:', e.message);
  process.exit(1);
});
