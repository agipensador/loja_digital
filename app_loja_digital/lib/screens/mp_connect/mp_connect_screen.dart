import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/services/payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Conecta a conta Mercado Pago da LOJA (admin-master) via OAuth, para o
/// split marketplace: o cliente paga, o dinheiro cai direto na conta da
/// loja, e o app retém a taxa automaticamente (application_fee).
///
/// O app nunca vê o Access Token da loja — só a Cloud Function
/// `oauthConnectStore` (a construir, depende do Firebase Blaze) grava e lê
/// isso. Esta tela só lê/mostra o booleano público `mpConnected` em
/// `stores/{storeId}`. Ver docs/PAGAMENTOS.md.
class MpConnectScreen extends StatelessWidget {
  const MpConnectScreen({super.key});

  String get _oauthUrl {
    // URL de autorização OAuth do Mercado Pago (client_id é público).
    // A Cloud Function `oauthConnectStore` troca o `code` retornado por um
    // access_token e grava `mpConnected: true` na loja.
    // O redirect_uri precisa ser IDÊNTICO ao cadastrado no app do MP; a loja
    // vai no `state` (a Function deve validá-lo contra o master logado).
    const clientId = String.fromEnvironment('MP_CLIENT_ID', defaultValue: '');
    final redirectUri = Uri.encodeComponent(
        '${MercadoPagoConfig.backendUrl}/oauthConnectStore');
    return 'https://auth.mercadopago.com.br/authorization'
        '?client_id=$clientId&response_type=code&platform_id=mp'
        '&state=${Uri.encodeComponent(Tenant.storeId)}'
        '&redirect_uri=$redirectUri';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final tenant = context.watch<TenantManager>();

    if (!tenant.isMaster) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mercado Pago')),
        body: const Center(
            child: Text('Somente o admin-master conecta o Mercado Pago.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mercado Pago'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: Tenant.storeRef.snapshots(),
        builder: (_, snap) {
          final connected =
              (snap.data?.data()?['mpConnected'] ?? false) as bool;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            connected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: connected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            connected ? 'Conta conectada' : 'Não conectado',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Conecte a conta Mercado Pago da sua loja para '
                        'receber o pagamento dos pedidos diretamente. O '
                        'valor do produto cai na sua conta; o app retém '
                        'automaticamente só a taxa de serviço.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => launchUrl(
                            Uri.parse(_oauthUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Text(connected
                              ? 'Reconectar conta Mercado Pago'
                              : 'Conectar conta Mercado Pago'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Observação: a conexão real depende do backend (Cloud '
                  'Functions) do Mercado Pago, publicado junto com a '
                  'liberação do pagamento automático. Até lá, o botão abre '
                  'o fluxo, mas a confirmação final só funciona após essa '
                  'etapa estar no ar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
