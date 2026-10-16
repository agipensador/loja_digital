import 'package:flutter/material.dart';

/// terms/privacy: para o CONSUMIDOR (quem compra na loja).
/// storeTerms: contrato da plataforma com o LOJISTA (planos, taxas, limites).
enum LegalDocument { terms, privacy, storeTerms }

/// Tela estática de Termos de Uso / Política de Privacidade.
/// Conteúdo placeholder — ajustar o texto final com um advogado antes de
/// publicar nas lojas (exigência LGPD + Google Play/App Store).
class LegalScreen extends StatelessWidget {
  const LegalScreen(this.document, {super.key});

  final LegalDocument document;

  String get _title {
    switch (document) {
      case LegalDocument.terms:
        return 'Termos de Uso';
      case LegalDocument.privacy:
        return 'Política de Privacidade';
      case LegalDocument.storeTerms:
        return 'Termos para Lojistas';
    }
  }

  String get _body {
    switch (document) {
      case LegalDocument.terms:
        return _termsText;
      case LegalDocument.privacy:
        return _privacyText;
      case LegalDocument.storeTerms:
        return _storeTermsText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(_body, style: const TextStyle(fontSize: 14, height: 1.5)),
      ),
    );
  }
}

const String _termsText = '''
Última atualização: 2026.

1. Aceitação dos termos
Ao criar uma conta ou usar este aplicativo, você concorda com estes Termos
de Uso e com a Política de Privacidade.

2. Cadastro
Você é responsável por manter a confidencialidade da sua senha e por todas
as atividades realizadas na sua conta.

3. Pedidos e pagamentos
Os preços, formas de pagamento e prazos de entrega são informados antes da
confirmação do pedido. O pagamento é processado por um provedor de
pagamentos parceiro; a loja é responsável pelo produto vendido.

4. Entrega
Os prazos e métodos de entrega (Correios, motoboy, transportadora ou
retirada) são definidos pela loja e informados no acompanhamento do
pedido.

5. Cancelamento e devolução
Pedidos podem ser cancelados conforme a política da loja e a legislação
do consumidor aplicável.

6. Encerramento de conta
Você pode solicitar a exclusão da sua conta a qualquer momento, pela tela
de Perfil. Pedidos já realizados permanecem no histórico da loja.

7. Alterações
Estes termos podem ser atualizados; alterações relevantes serão
comunicadas no aplicativo.
''';

const String _privacyText = '''
Última atualização: 2026.

1. Dados coletados
Coletamos nome, e-mail, endereços de entrega e histórico de pedidos
necessários para operar sua conta e processar suas compras.

2. Uso dos dados
Os dados são usados para processar pedidos, entregas, pagamentos e
comunicação sobre o status da sua compra.

3. Compartilhamento
Compartilhamos apenas os dados necessários com o provedor de pagamentos e
com o responsável pela entrega do seu pedido. Não vendemos seus dados a
terceiros.

4. Armazenamento
Os dados são armazenados em infraestrutura do Firebase (Google Cloud) com
controles de acesso restritos à loja onde você possui conta.

5. Seus direitos (LGPD)
Você pode solicitar acesso, correção ou exclusão dos seus dados pessoais
a qualquer momento. A exclusão de conta está disponível na tela de
Perfil.

6. Contato
Em caso de dúvidas sobre esta política, utilize os canais de contato
disponíveis na loja.
''';

const String _storeTermsText = '''
Última atualização: 2026. Contrato entre a plataforma Inforizz e a loja
(lojista) que usa o aplicativo e o site.

1. Planos e mensalidade
• Loja única (1 unidade física): R\$ 29,90/mês.
• Multilojas (até 2 unidades): R\$ 59,90/mês.
• Multilojas Plus (de 3 a 5 unidades): R\$ 119,90/mês.
• O limite da plataforma é de 5 unidades físicas por empresa.
• Toda loja nova começa com 3 meses grátis. A primeira cobrança é enviada
  por Pix ao fim desse período.
• Pagamento mensal, ou 6 meses de uma vez com 10% de desconto, ou 12 meses
  de uma vez com 15% de desconto.
• A loja pode trocar de plano a qualquer momento pelo app.
• Formas: Pix (inclusive Pix Automático) ou cartão de crédito recorrente.

2. Taxa de serviço por pedido
A plataforma retém R\$ 0,99 por pedido pago, em todos os pedidos, no próprio
pagamento (split do Mercado Pago). Por padrão a loja absorve essa taxa; a
loja pode optar por repassá-la ao consumidor, somada ao total do pedido.

3. Recebimento das vendas
O valor das vendas cai diretamente na conta Mercado Pago da loja. As tarifas
do Mercado Pago (Pix, cartão, parcelamento) são cobradas pelo Mercado Pago
da loja e descontadas do valor recebido; o app informa essas tarifas no
relatório financeiro. A plataforma não guarda nem repassa o dinheiro das
vendas.

4. Limites de uso incluídos no plano
Cada plano inclui um volume de uso compatível com o seu valor:
• Loja única: até 10.000 visitas/mês, 500 produtos e 2 GB de imagens.
• Multilojas: até 25.000 visitas/mês, 1.500 produtos e 5 GB de imagens.
• Multilojas Plus: até 60.000 visitas/mês, 3.000 produtos e 10 GB.
(2 GB equivalem a cerca de 7.000 fotos: o app comprime cada foto ao
enviar, sem perda visível na tela.)
Se o app e o site passarem desses limites, é cobrado um valor de serviço
adicional, porque mais clientes ativos geram mais custo de servidor:
R\$ 5,00 a cada 1.000 visitas, 100 produtos ou 1 GB a mais, junto com a
mensalidade seguinte. Esse adicional nunca passa de R\$ 50,00 por mês. Ao
chegar nesse teto, novos produtos e fotos ficam pausados (as vendas e as
visitas continuam) até a loja mudar de plano. O uso do mês fica visível
para o dono na tela de Assinatura.

5. Período gratuito, avisos, atraso e suspensão
Lojas novas têm 3 meses grátis. Quando o pagamento não for automático,
avisamos 10 dias antes do vencimento e, nos 3 últimos dias, também por
WhatsApp. Em caso de atraso, há 5 dias de carência; depois disso o app e o
site da loja saem do ar para os clientes (não é possível fazer pedidos)
até a regularização, e voltam automaticamente após o pagamento.

6. Entregas e trocas
A loja define suas formas de entrega, áreas, dias e valores, e é
responsável por cumpri-las. Se a loja propuser outra forma de entrega e o
cliente aceitar, a diferença de valor deve ser devolvida ao cliente (ou
cobrada dele, se maior).

7. Equipe
O dono da loja pode cadastrar gerentes e funcionários e definir o que cada
um pode fazer. Gerentes e funcionários não podem alterar nem remover o
dono.

8. Encerramento
O dono não exclui a loja diretamente: solicita o encerramento pelo app, e a
plataforma confirma com ele antes de tirar a loja do ar.

9. Propriedade do software
O aplicativo, o site, o painel e todo o código-fonte, o design e a
estrutura de dados e servidores são de propriedade exclusiva da Inforizz,
que os desenvolve e mantém. A loja recebe uma licença de uso, pessoal e
não exclusiva, enquanto a assinatura estiver ativa. A assinatura não
transfere nem vende o código, e não é permitido copiá-lo, revendê-lo ou
fazer engenharia reversa.
A loja continua dona da sua marca, logotipo, fotos, textos, produtos e da
relação com os seus clientes. No encerramento, a loja pode pedir a
exportação do seu catálogo e dos seus pedidos.

10. Publicação dos apps
O app com a marca da loja é publicado e atualizado pela Inforizz no Google
Play e na App Store, e o site fica em endereço da Inforizz ou em domínio
da loja. A aprovação e os prazos dependem do Google e da Apple. Quando a
Apple exigir, a publicação no iPhone é feita em conta de desenvolvedor da
própria loja, com a Inforizz como responsável técnica.
''';
