import 'package:app_loja_digital/core/platform_contact.dart';
import 'package:app_loja_digital/core/tenant.dart';
import 'package:app_loja_digital/helpers/br_format.dart';
import 'package:app_loja_digital/models/delivery_zone.dart';
import 'package:app_loja_digital/models/order.dart';
import 'package:app_loja_digital/models/plan.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Contexto da LOJA DESTE APP (flavor): tudo que o chat sabe vem daqui, então
/// ele nunca fala de outra loja — o STORE_ID é fixo no build.
class ChatContext {
  const ChatContext({
    required this.storeName,
    required this.locations,
    required this.zones,
    required this.isTeam,
    this.plan,
    this.isPlatformStore = false,
    this.attendingLocationId,
  });

  final String storeName;
  final List<Store> locations;
  final List<DeliveryZone> zones;
  final bool isTeam;
  final Plan? plan;

  /// App/site da própria Inforizz: mostra as perguntas de quem quer ter
  /// uma loja.
  final bool isPlatformStore;

  /// Unidade que atende o cliente agora (escolhida pela cidade do endereço).
  final String? attendingLocationId;

  /// Aviso quando nenhuma unidade cadastrou WhatsApp.
  static const String whatsappUnavailable =
      'No momento o WhatsApp da loja não está disponível.';

  static bool _hasWhatsapp(Store l) => Br.digits(l.phone).length >= 10;

  /// Unidade cujo WhatsApp atende o cliente: a que está atendendo; se ela
  /// não tem número, a unidade que tem. Nenhuma com número: `null`.
  Store? get whatsappLocation {
    for (final l in locations) {
      if (l.id == attendingLocationId && _hasWhatsapp(l)) return l;
    }
    for (final l in locations) {
      if (_hasWhatsapp(l)) return l;
    }
    return null;
  }

  String? get storeWhatsapp {
    final l = whatsappLocation;
    return l == null ? null : Br.digits(l.phone);
  }

  /// A equipe da loja e quem quer ter uma loja falam com a Inforizz. O
  /// cliente fala SÓ com a loja — sem WhatsApp cadastrado, fica sem canal,
  /// em vez de cair na Inforizz, que não sabe nada do pedido dele.
  bool get talksToPlatform => isTeam || isPlatformStore;

  /// Existe alguém para quem passar a conversa?
  bool get hasHuman => talksToPlatform || storeWhatsapp != null;

  /// Com mais de uma unidade, diz qual: "Loja Ju (Centro)".
  String get humanName {
    if (talksToPlatform) return PlatformContact.name;
    final l = whatsappLocation;
    if (l == null || locations.length < 2 || l.name.isEmpty) return storeName;
    return '$storeName (${l.name})';
  }

  /// Link do WhatsApp com a mensagem pronta; `null` quando a loja não tem
  /// WhatsApp — aí a tela mostra [whatsappUnavailable].
  String? humanUrl([String text = '']) {
    if (talksToPlatform) {
      final prefix = isPlatformStore
          ? ''
          : (isTeam ? '[Loja $storeName — suporte] ' : '[App $storeName] ');
      return PlatformContact.support(text.isEmpty ? '' : '$prefix$text');
    }
    final number = storeWhatsapp;
    return number == null ? null : PlatformContact.waLink(number, text);
  }
}

enum ChatAudience { customer, team, prospect }

class ChatAnswer {
  const ChatAnswer(
    this.text, {
    this.related = const [],
    this.whatsappText,
    this.route,
    this.routeLabel,
  });

  final String text;

  /// Perguntas sugeridas em seguida (ids de [ChatIntent]).
  final List<String> related;

  /// Quando presente, mostra o botão do WhatsApp com esta mensagem pronta.
  final String? whatsappText;

  /// Tela do app para abrir (ex.: '/start_store').
  final String? route;
  final String? routeLabel;
}

class ChatIntent {
  const ChatIntent({
    required this.id,
    required this.question,
    required this.keywords,
    required this.answer,
    this.category = 'Geral',
    this.audience = ChatAudience.customer,
  });

  final String id;
  final String question;
  final List<String> keywords;
  final ChatAnswer Function(ChatContext c) answer;
  final String category;
  final ChatAudience audience;
}

/// Resultado de uma mensagem digitada.
class ChatReply {
  const ChatReply({this.intent, this.toHuman = false});
  final ChatIntent? intent;

  /// Dúvida específica (pedido, problema, cobrança...) ou sem resposta:
  /// vai para o WhatsApp com a pergunta já escrita.
  final bool toHuman;
}

/// Atendimento v1: menu com as perguntas mais tocadas, respostas montadas
/// com as configurações desta loja, texto livre por palavras-chave e
/// passagem para o WhatsApp quando a dúvida é específica.
///
/// v2 (planejado): o que o menu não cobre vai para uma Cloud Function com
/// IA, que recebe SÓ o [ChatContext] desta loja e o manual do app — nunca
/// dados de outras lojas nem código.
class Chatbot {
  Chatbot._();

  /// Tamanho do menu inicial (as mais tocadas).
  static const int topSize = 5;

  static String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  static String _weekdays(List<int> days) {
    const names = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  static String _deliveryText(ChatContext c) {
    if (c.locations.isEmpty) {
      return 'A ${c.storeName} ainda está configurando as formas de entrega. '
          'Fale com a loja para combinar.';
    }
    final lines = <String>[];
    for (final l in c.locations) {
      final opts = <String>[
        if (l.offersPickup) 'retirada na loja (grátis)',
        if (l.offersOwnDelivery) 'entrega da própria loja',
        if (l.offersUber)
          'motoboy (a partir de ${Br.money(l.uberBaseFee)}, pela distância)',
        if (l.offersShipping) 'Correios (${Br.money(l.shippingFee)})',
      ];
      final prefix = c.locations.length > 1 ? '• ${l.name}: ' : '';
      lines.add(
          '$prefix${opts.isEmpty ? 'combinar com a loja' : opts.join(', ')}');
    }
    return 'Formas de receber:\n${lines.join('\n')}\n\n'
        'No checkout aparecem só as opções que atendem o seu endereço, já '
        'com o valor.';
  }

  static String _zonesText(ChatContext c) {
    final active = c.zones.where((z) => z.active).toList();
    if (active.isEmpty) {
      return 'A ${c.storeName} não tem entrega própria por região no '
          'momento. Veja as outras formas de entrega no checkout.';
    }
    return 'A loja entrega nestas regiões:\n${active.map((z) =>
        '• ${z.districts.join(', ')}: ${_weekdays(z.weekdays)}'
        '${z.fee > 0 ? ', ${Br.money(z.fee)}' : ', grátis'}').join('\n')}'
        '\n\nNo checkout você escolhe o dia preferido e a loja confirma a '
        'data final.';
  }

  static String _pickupText(ChatContext c) {
    final pickup = c.locations.where((l) => l.offersPickup).toList();
    if (pickup.isEmpty) return 'No momento a loja não oferece retirada.';
    return 'Você pode retirar em:\n${pickup.map((l) => '• ${l.name}: '
        '${l.address}${l.hours.isNotEmpty ? '\n  Horário: ${l.hours}' : ''}').join('\n')}'
        '\n\nEscolha "Retirada" no checkout. Quando o pedido estiver pronto, '
        'ele aparece como "Pronto para retirada".';
  }

  static String _plansText() {
    final lines = PlanCatalog.all.map((p) =>
        '• ${p.name} (${p.maxLocations == 1 ? '1 unidade' : 'até ${p.maxLocations} unidades'}): '
        '${Br.money(p.price)}/mês');
    return 'Planos (app Android + iPhone + site com a sua marca):\n'
        '${lines.join('\n')}\n\n'
        '• ${PlatformBilling.trialDays ~/ 30} meses grátis para começar.\n'
        '• Pagando 6 meses: 10% de desconto. 12 meses: 15%.\n'
        '• Taxa de ${Br.money(PlatformBilling.serviceFee)} por pedido pago '
        '(a loja escolhe se absorve ou repassa ao cliente).';
  }

  static final List<ChatIntent> intents = [
    // ================= Cliente da loja =================
    ChatIntent(
      id: 'como_comprar',
      category: 'Pedidos',
      question: 'Como faço um pedido?',
      keywords: ['comprar', 'pedido', 'pedir', 'carrinho', 'como compro', 'finalizar'],
      answer: (c) => const ChatAnswer(
          '1. Toque no produto e escolha o tamanho/variante.\n'
          '2. "Adicionar ao carrinho" → "Continuar para entrega".\n'
          '3. Digite o CEP: o endereço é preenchido sozinho.\n'
          '4. Escolha como quer receber e a forma de pagamento.\n'
          '5. "Finalizar pedido". Pronto! Acompanhe em "Meus pedidos".',
          related: ['pagamento', 'entrega']),
    ),
    ChatIntent(
      id: 'entrega',
      category: 'Entrega',
      question: 'Como funciona a entrega e quanto custa?',
      keywords: ['entrega', 'frete', 'envio', 'correios', 'motoboy', 'uber', 'valor da entrega', 'entregam'],
      answer: (c) =>
          ChatAnswer(_deliveryText(c), related: ['dias_entrega', 'retirada']),
    ),
    ChatIntent(
      id: 'dias_entrega',
      category: 'Entrega',
      question: 'Em quais dias vocês entregam no meu bairro?',
      keywords: ['dia', 'dias', 'bairro', 'cidade', 'regiao', 'quando chega', 'prazo', 'demora'],
      answer: (c) => ChatAnswer(_zonesText(c), related: ['entrega']),
    ),
    ChatIntent(
      id: 'retirada',
      category: 'Entrega',
      question: 'Posso retirar na loja?',
      keywords: ['retirar', 'retirada', 'buscar', 'endereco da loja', 'onde fica', 'endereco de voces'],
      answer: (c) => ChatAnswer(_pickupText(c), related: ['horario']),
    ),
    ChatIntent(
      id: 'pagamento',
      category: 'Pagamento',
      question: 'Quais as formas de pagamento?',
      keywords: ['pagar', 'pagamento', 'pix', 'cartao', 'credito', 'debito', 'boleto'],
      answer: (c) => const ChatAnswer(
          'Você pode pagar com Pix ou cartão de crédito, com a segurança do '
          'Mercado Pago. O dinheiro vai direto para a loja e o pedido é '
          'confirmado assim que o pagamento é aprovado.',
          related: ['parcelamento', 'seguranca']),
    ),
    ChatIntent(
      id: 'parcelamento',
      category: 'Pagamento',
      question: 'Posso parcelar?',
      keywords: ['parcel', 'vezes', 'prestacao', 'sem juros'],
      answer: (c) => const ChatAnswer(
          'No cartão de crédito, o Mercado Pago mostra as opções de '
          'parcelamento na hora de pagar. Juros e número de parcelas dependem '
          'da loja e do seu cartão.',
          related: ['pagamento']),
    ),
    ChatIntent(
      id: 'pagamento_recusado',
      category: 'Pagamento',
      question: 'Meu pagamento não foi aprovado / o Pix expirou',
      keywords: ['recusado', 'nao aprovado', 'negado', 'expirou', 'pix venceu', 'nao passou', 'erro no pagamento'],
      answer: (c) => const ChatAnswer(
          'Se o Pix expirou ou o cartão foi recusado, nada foi cobrado e os '
          'produtos voltam para o estoque. Faça o pedido de novo e tente '
          'outra forma de pagamento. Se apareceu cobrança, fale com a gente '
          'no WhatsApp com o comprovante.',
          whatsappText: 'Olá! Tive um problema com o pagamento do meu pedido.',
          related: ['pagamento']),
    ),
    ChatIntent(
      id: 'seguranca',
      category: 'Pagamento',
      question: 'É seguro comprar por aqui?',
      keywords: ['seguro', 'seguranca', 'confiavel', 'golpe', 'fraude', 'dados do cartao'],
      answer: (c) => const ChatAnswer(
          'Sim. O pagamento é processado pelo Mercado Pago: o app não guarda '
          'os dados do seu cartão. Seus dados ficam protegidos e você pode '
          'pedir a exclusão da conta a qualquer momento em "Perfil".',
          related: ['privacidade']),
    ),
    ChatIntent(
      id: 'rastrear',
      category: 'Pedidos',
      question: 'Como acompanho meu pedido?',
      keywords: ['acompanhar', 'rastrear', 'rastreio', 'onde esta', 'status', 'codigo de rastreio'],
      answer: (c) => const ChatAnswer(
          'Abra "Meus pedidos". A linha do tempo mostra cada etapa: pagamento, '
          'separação, a caminho ou pronto para retirada, entregue. Se for '
          'pelos Correios, o código de rastreio aparece no pedido com o botão '
          '"Rastrear".',
          related: ['troca_entrega', 'atrasado']),
    ),
    ChatIntent(
      id: 'troca_entrega',
      category: 'Entrega',
      question: 'A loja mudou a forma de entrega do meu pedido',
      keywords: ['mudou', 'proposta', 'trocar entrega', 'diferenca', 'devolucao da diferenca'],
      answer: (c) => const ChatAnswer(
          'Às vezes a loja sugere outra forma de entrega (por exemplo, '
          'entregar ela mesma em vez dos Correios). O aviso aparece no seu '
          'pedido com "Aceitar" ou "Recusar". Se ficar mais barato, a '
          'diferença é devolvida; se ficar mais caro, você decide se aceita.',
          related: ['rastrear']),
    ),
    ChatIntent(
      id: 'alterar_endereco',
      category: 'Entrega',
      question: 'Errei o endereço, como altero?',
      keywords: ['alterar endereco', 'mudar endereco', 'endereco errado', 'errei o endereco', 'trocar endereco'],
      answer: (c) => const ChatAnswer(
          'Seus endereços ficam em "Perfil" → "Meus endereços". Se o pedido já '
          'foi feito, fale com a loja agora pelo WhatsApp para corrigir antes '
          'do envio.',
          whatsappText: 'Olá! Preciso corrigir o endereço do meu pedido.'),
    ),
    ChatIntent(
      id: 'troca_devolucao',
      category: 'Trocas e cancelamento',
      question: 'Como troco ou devolvo um produto?',
      keywords: ['trocar produto', 'troca', 'devolver', 'devolucao', 'arrependimento', 'tamanho errado', 'nao serviu', 'defeito'],
      answer: (c) => const ChatAnswer(
          'Compras pela internet podem ser devolvidas em até 7 dias após o '
          'recebimento (direito de arrependimento, Código de Defesa do '
          'Consumidor). Produto com defeito tem garantia. Para começar a '
          'troca, fale com a loja pelo WhatsApp com o número do pedido.',
          whatsappText: 'Olá! Quero trocar/devolver um produto do meu pedido nº ',
          related: ['cancelar']),
    ),
    ChatIntent(
      id: 'cancelar',
      category: 'Trocas e cancelamento',
      question: 'Como cancelo um pedido?',
      keywords: ['cancelar', 'cancelamento', 'desistir', 'estornar'],
      answer: (c) => const ChatAnswer(
          'Fale com a loja o quanto antes. Enquanto o pedido está "Em '
          'separação" o cancelamento é mais simples, e o valor é estornado '
          'pelo Mercado Pago na mesma forma de pagamento.',
          whatsappText: 'Olá! Quero cancelar meu pedido nº ',
          related: ['troca_devolucao']),
    ),
    ChatIntent(
      id: 'esgotado',
      category: 'Produtos',
      question: 'O produto que eu quero está esgotado',
      keywords: ['esgotado', 'sem estoque', 'acabou', 'nao tem', 'vai chegar', 'repor', 'disponivel'],
      answer: (c) => const ChatAnswer(
          'Quando a loja tem mais de uma unidade, o produto pode estar '
          'disponível em outra: veja "Disponível em..." na página do produto. '
          'Para saber quando volta, pergunte à loja pelo WhatsApp.',
          whatsappText: 'Olá! Quando volta o produto: '),
    ),
    ChatIntent(
      id: 'tamanho',
      category: 'Produtos',
      question: 'Como escolho o tamanho/medida certa?',
      keywords: ['tamanho', 'medida', 'numeracao', 'veste', 'tabela de medidas', 'cabe'],
      answer: (c) => const ChatAnswer(
          'As medidas e variantes ficam na descrição de cada produto. Se ficar '
          'em dúvida, mande o nome do produto para a loja no WhatsApp.',
          whatsappText: 'Olá! Tenho dúvida sobre o tamanho do produto: '),
    ),
    ChatIntent(
      id: 'nota_fiscal',
      category: 'Pedidos',
      question: 'Vocês emitem nota fiscal?',
      keywords: ['nota fiscal', 'nf', 'nfe', 'cupom fiscal', 'recibo'],
      answer: (c) => const ChatAnswer(
          'A nota fiscal é emitida pela loja. Peça pelo WhatsApp informando o '
          'número do pedido e o CPF/CNPJ.',
          whatsappText: 'Olá! Preciso da nota fiscal do pedido nº '),
    ),
    ChatIntent(
      id: 'cupom',
      category: 'Produtos',
      question: 'Tem cupom ou promoção?',
      keywords: ['cupom', 'desconto', 'promocao', 'oferta', 'liquidacao', 'black friday'],
      answer: (c) => const ChatAnswer(
          'As promoções aparecem na página inicial e em "Notificações". Ative '
          'as notificações do app para saber primeiro.',
          related: ['notificacoes']),
    ),
    ChatIntent(
      id: 'atrasado',
      category: 'Pedidos',
      question: 'Meu pedido está atrasado',
      keywords: ['atrasado', 'atraso', 'nao chegou', 'ainda nao chegou', 'demorando'],
      answer: (c) => const ChatAnswer(
          'Confira a data confirmada em "Meus pedidos". Se já passou, fale com '
          'a loja: o WhatsApp já vai com a mensagem pronta, é só colocar o '
          'número do pedido.',
          whatsappText: 'Olá! Meu pedido nº  está atrasado.'),
    ),
    ChatIntent(
      id: 'horario',
      category: 'A loja',
      question: 'Qual o horário de funcionamento?',
      keywords: ['horario', 'abre', 'fecha', 'aberto', 'funcionamento'],
      answer: (c) {
        final withHours = c.locations.where((l) => l.hours.isNotEmpty);
        return ChatAnswer(withHours.isEmpty
            ? 'A loja ainda não informou o horário. Pergunte pelo WhatsApp.'
            : withHours.map((l) => '• ${l.name}: ${l.hours}').join('\n'));
      },
    ),
    ChatIntent(
      id: 'conta',
      category: 'Conta e app',
      question: 'Esqueci minha senha / minha conta',
      keywords: ['senha', 'login', 'entrar', 'conta', 'email', 'cadastro'],
      answer: (c) => const ChatAnswer(
          'Na tela "Entrar", toque em "Esqueci minha senha" e informe seu '
          'e-mail: enviamos um link para criar uma nova. Seus dados, '
          'endereços e a exclusão da conta ficam em "Perfil".'),
    ),
    ChatIntent(
      id: 'notificacoes',
      category: 'Conta e app',
      question: 'Como recebo avisos de promoções?',
      keywords: ['notificacao', 'notificacoes', 'avisos', 'novidades', 'push'],
      answer: (c) => const ChatAnswer(
          'Permita as notificações quando o app pedir (ou nas configurações '
          'do celular). Os avisos da loja também ficam no menu '
          '"Notificações".'),
    ),
    ChatIntent(
      id: 'privacidade',
      category: 'Conta e app',
      question: 'Como meus dados são usados?',
      keywords: ['dados', 'privacidade', 'lgpd', 'excluir conta', 'apagar conta'],
      answer: (c) => const ChatAnswer(
          'Usamos seus dados só para entregar e acompanhar seus pedidos. A '
          'Política de Privacidade fica no Perfil, e lá você também pode '
          'excluir sua conta.'),
    ),
    ChatIntent(
      id: 'falar_loja',
      category: 'A loja',
      question: 'Falar com uma pessoa',
      keywords: ['falar', 'atendente', 'humano', 'pessoa', 'whatsapp', 'telefone', 'contato', 'suporte'],
      answer: (c) => c.hasHuman
          ? ChatAnswer(
              'Claro! Toque abaixo para falar com a ${c.humanName} no '
              'WhatsApp.',
              whatsappText: 'Olá! Vim pelo atendimento do app.',
            )
          : const ChatAnswer(ChatContext.whatsappUnavailable),
    ),

    // ================= Equipe da loja (como usar o sistema) =================
    ChatIntent(
      id: 't_produto',
      audience: ChatAudience.team,
      category: 'Produtos',
      question: 'Como cadastro um produto?',
      keywords: ['cadastrar produto', 'novo produto', 'adicionar produto', 'foto do produto'],
      answer: (c) => const ChatAnswer(
          'Em "Produtos", toque no "+". Adicione fotos (câmera, galeria ou '
          'link), nome, categoria, descrição e as variantes com preço e '
          'estoque. As fotos são comprimidas sozinhas, sem perder qualidade. '
          'Ao salvar um produto novo, o app pergunta se você quer avisar os '
          'clientes.',
          related: ['t_importar', 't_estoque']),
    ),
    ChatIntent(
      id: 't_importar',
      audience: ChatAudience.team,
      category: 'Produtos',
      question: 'Como trago todos os produtos de uma vez?',
      keywords: ['importar', 'planilha', 'csv', 'json', 'excel', 'shopify', 'nuvemshop', 'catalogo', 'de uma vez', 'google sheets'],
      answer: (c) => const ChatAnswer(
          'Perfil → "Importar catálogo". Você pode:\n'
          '• escolher um arquivo CSV ou JSON;\n'
          '• colar o link de uma planilha do Google (compartilhada para '
          '"qualquer pessoa com o link");\n'
          '• usar a exportação da Shopify ou Nuvemshop.\n'
          'No Excel, salve como CSV. Se preferir, mande a planilha no WhatsApp '
          'da Inforizz que a gente importa para você.',
          related: ['t_suporte']),
    ),
    ChatIntent(
      id: 't_estoque',
      audience: ChatAudience.team,
      category: 'Produtos',
      question: 'Como controlo o estoque e peço reposição?',
      keywords: ['estoque', 'reposicao', 'fornecedor', 'acabando'],
      answer: (c) => const ChatAnswer(
          'Perfil → "Controle de estoque" (por unidade). Quando um produto '
          'fica baixo, aparece um alerta no Perfil. Em "Pedir reposição" o '
          'app monta a mensagem e abre o WhatsApp do fornecedor.'),
    ),
    ChatIntent(
      id: 't_pedidos',
      audience: ChatAudience.team,
      category: 'Pedidos',
      question: 'Como gerencio os pedidos?',
      keywords: ['gerenciar pedidos', 'pedidos da loja', 'avancar pedido', 'despachar', 'status do pedido'],
      answer: (c) => const ChatAnswer(
          'Menu "Pedidos": filtre por situação, defina a data de entrega, '
          'avance as etapas (separação → transporte/pronto para retirada → '
          'entregue) e informe o código de rastreio. Para mudar a forma de '
          'entrega, use "Propor outra entrega": o cliente aceita ou recusa.'),
    ),
    ChatIntent(
      id: 't_entrega',
      audience: ChatAudience.team,
      category: 'Entrega',
      question: 'Como configuro as entregas?',
      keywords: ['configurar entrega', 'zona', 'area de entrega', 'valor do frete'],
      answer: (c) => const ChatAnswer(
          'Em "Lojas", edite a unidade: ligue retirada, Correios (valor), '
          'motoboy (saída + valor por km) e entrega própria. As áreas da '
          'entrega própria (cidades/bairros, dias e valor) ficam em Perfil → '
          '"Zonas de entrega".'),
    ),
    ChatIntent(
      id: 't_mp',
      audience: ChatAudience.team,
      category: 'Pagamentos',
      question: 'Como recebo o dinheiro das vendas?',
      keywords: ['receber', 'mercado pago', 'dinheiro', 'repasse', 'saque', 'conta bancaria'],
      answer: (c) => ChatAnswer(
          'As vendas caem direto na conta Mercado Pago da loja (Perfil → '
          '"Conectar Mercado Pago"). O Mercado Pago desconta as tarifas dele, e '
          'a plataforma retém ${Br.money(PlatformBilling.serviceFee)} por '
          'pedido. O relatório financeiro mostra tudo por mês.'),
    ),
    ChatIntent(
      id: 't_equipe',
      audience: ChatAudience.team,
      category: 'Equipe',
      question: 'Como adiciono funcionários?',
      keywords: ['funcionario', 'gerente', 'equipe', 'permissao'],
      answer: (c) => const ChatAnswer(
          'A pessoa cria uma conta no app. Depois, em Perfil → "Equipe da '
          'loja", informe o e-mail, escolha Gerente ou Funcionário e ajuste '
          'o que ela pode fazer e em quais unidades.'),
    ),
    ChatIntent(
      id: 't_visual',
      audience: ChatAudience.team,
      category: 'Aparência',
      question: 'Como mudo cores, logo e página inicial?',
      keywords: ['cor', 'cores', 'logo', 'logotipo', 'aparencia', 'tema', 'banner', 'pagina inicial', 'icone'],
      answer: (c) => const ChatAnswer(
          'Cores e banners: menu "Aparência" e a página inicial (botão de '
          'editar). O logotipo e o ícone do app instalado no celular são '
          'trocados pela Inforizz: mande o arquivo no WhatsApp.',
          whatsappText: 'Olá! Quero trocar o logotipo/ícone do meu app.'),
    ),
    ChatIntent(
      id: 't_plano',
      audience: ChatAudience.team,
      category: 'Plano',
      question: 'Como funciona meu plano e o uso?',
      keywords: ['plano', 'assinatura', 'mensalidade', 'limite', 'visitas', 'cobranca', 'trocar de plano'],
      answer: (c) => ChatAnswer(
          'Em Perfil → "Assinatura" você vê o plano'
          '${c.plan == null ? '' : ' (${c.plan!.name}, ${c.plan!.priceLabel})'}, '
          'o uso do mês (visitas, produtos e fotos) e pode trocar de plano. '
          'Se passar do incluído, há um adicional com teto de '
          '${Br.money(UsageReport.maxExtraCharge)}/mês.'),
    ),
    ChatIntent(
      id: 't_avisos',
      audience: ChatAudience.team,
      category: 'Notificações',
      question: 'Como envio avisos aos clientes?',
      keywords: ['enviar aviso', 'notificar', 'campanha', 'notificacao para clientes'],
      answer: (c) => ChatAnswer(
          'Em "Notificações", toque em "Enviar aviso". O app também sugere '
          'avisar quando você cadastra produtos novos. Seu plano permite '
          '${c.plan?.maxCampaigns ?? 0} avisos por mês.'),
    ),
    ChatIntent(
      id: 't_suporte',
      audience: ChatAudience.team,
      category: 'Suporte',
      question: 'Falar com o suporte da Inforizz',
      keywords: ['suporte', 'inforizz', 'ajuda', 'bug', 'erro', 'nao funciona', 'problema no app'],
      answer: (c) => const ChatAnswer(
          'Toque abaixo para falar com a Inforizz no WhatsApp. Se for um erro, '
          'mande um print da tela.',
          whatsappText: 'Olá! Preciso de ajuda com o app da minha loja.'),
    ),

    // ================= Quem quer ter uma loja (app da Inforizz) =================
    ChatIntent(
      id: 'p_o_que_e',
      audience: ChatAudience.prospect,
      category: 'Sua loja',
      question: 'O que é a loja com app próprio?',
      keywords: ['o que e', 'como funciona', 'app proprio', 'loja virtual', 'loja online'],
      answer: (c) => const ChatAnswer(
          'Sua loja ganha um app com a sua marca no Android e no iPhone, e um '
          'site. Seus clientes compram, pagam com Pix ou cartão (o dinheiro cai '
          'na sua conta Mercado Pago) e escolhem entrega ou retirada. Você '
          'controla produtos, estoque, entregas e equipe pelo próprio app.',
          related: ['p_precos', 'p_comecar']),
    ),
    ChatIntent(
      id: 'p_precos',
      audience: ChatAudience.prospect,
      category: 'Sua loja',
      question: 'Quanto custa?',
      keywords: ['preco', 'quanto custa', 'valor', 'planos', 'mensalidade', 'gratis'],
      answer: (c) => ChatAnswer(_plansText(), related: ['p_comecar']),
    ),
    ChatIntent(
      id: 'p_comecar',
      audience: ChatAudience.prospect,
      category: 'Sua loja',
      question: 'Quero montar minha loja',
      keywords: ['quero', 'montar', 'contratar', 'assinar', 'comecar', 'criar minha loja', 'ter uma loja'],
      answer: (c) => const ChatAnswer(
          'Ótimo! Escolha o plano e as cores na próxima tela. Ela abre o '
          'WhatsApp da Inforizz já com tudo escrito, e lá você manda o logo e '
          'a planilha de produtos.',
          route: '/start_store',
          routeLabel: 'Montar minha loja'),
    ),
    ChatIntent(
      id: 'p_o_que_preciso',
      audience: ChatAudience.prospect,
      category: 'Sua loja',
      question: 'O que eu preciso enviar?',
      keywords: ['preciso enviar', 'o que mandar', 'documentos', 'logo', 'cores', 'planilha'],
      answer: (c) => const ChatAnswer(
          'Pelo WhatsApp:\n'
          '• nome da loja e cidade(s);\n'
          '• logotipo (PNG ou JPG, de preferência quadrado). Ele vira o ícone '
          'do app;\n'
          '• cores da marca (código como #E53935 ou só "vermelho e '
          'branco");\n'
          '• produtos em planilha (Excel, Google Planilhas, CSV ou JSON), se '
          'tiver;\n'
          '• conta Mercado Pago da loja (para receber as vendas).\n'
          'No primeiro acesso, a gente te acompanha na configuração.',
          route: '/start_store',
          routeLabel: 'Montar minha loja'),
    ),
    ChatIntent(
      id: 'p_prazo',
      audience: ChatAudience.prospect,
      category: 'Sua loja',
      question: 'Em quanto tempo minha loja fica pronta?',
      keywords: ['prazo', 'quanto tempo', 'quando fica pronto', 'demora'],
      answer: (c) => const ChatAnswer(
          'O site fica pronto em até 2 dias úteis depois de recebermos o '
          'material. O app Android costuma ser aprovado pelo Google em 1 a 7 '
          'dias, e o iPhone depende da revisão da Apple (geralmente 1 a 3 '
          'dias, depois que a conta estiver pronta).'),
    ),
    ChatIntent(
      id: 'p_dominio',
      audience: ChatAudience.prospect,
      category: 'Sua loja',
      question: 'Posso usar meu próprio endereço (domínio)?',
      keywords: ['dominio', 'endereco do site', 'url', '.com.br', 'site proprio'],
      answer: (c) => const ChatAnswer(
          'Sim. Sem custo, sua loja fica em um endereço da Inforizz. Se você '
          'tiver (ou comprar no registro.br) um domínio como sualoja.com.br, '
          'a gente conecta com cadeado de segurança (HTTPS).'),
    ),
    ChatIntent(
      id: 'p_exemplos',
      audience: ChatAudience.prospect,
      category: 'Inforizz',
      question: 'Quais apps a Inforizz já fez?',
      keywords: ['exemplos', 'portfolio', 'jesus', 'chaveiro', 'outros apps'],
      answer: (c) => const ChatAnswer(
          'A Inforizz desenvolve apps como o Jesus.ai e o App do Chaveiro, que '
          'estão nas lojas Google Play e App Store. A loja com app próprio usa '
          'a mesma equipe e tecnologia.'),
    ),
  ];

  static ChatIntent? byId(String id) {
    for (final i in intents) {
      if (i.id == id) return i;
    }
    return null;
  }

  static List<ChatIntent> forContext(ChatContext c) => intents
      .where((i) =>
          i.audience == ChatAudience.customer ||
          (i.audience == ChatAudience.team && c.isTeam) ||
          (i.audience == ChatAudience.prospect && c.isPlatformStore))
      .toList();

  /// Ordem usada enquanto a loja ainda não tem cliques suficientes.
  static const List<String> defaultCustomerTop = [
    'como_comprar', 'entrega', 'pagamento', 'rastrear', 'troca_devolucao',
  ];
  static const List<String> defaultTeamTop = [
    't_produto', 't_importar', 't_pedidos', 't_mp', 't_suporte',
  ];
  static const List<String> defaultProspectTop = [
    'p_precos', 'p_comecar', 'p_o_que_e', 'p_o_que_preciso', 'p_prazo',
  ];

  /// As [topSize] perguntas mais tocadas nesta loja (com a ordem padrão
  /// como desempate).
  static List<ChatIntent> top(ChatContext c, Map<String, int> popularity) {
    final defaults = c.isPlatformStore
        ? defaultProspectTop
        : c.isTeam
            ? defaultTeamTop
            : defaultCustomerTop;
    final pool = c.isPlatformStore
        ? forContext(c)
            .where((i) => i.audience != ChatAudience.customer)
            .toList()
        : c.isTeam
            ? forContext(c)
                .where((i) => i.audience == ChatAudience.team)
                .toList()
            : forContext(c);
    int rank(ChatIntent i) {
      final d = defaults.indexOf(i.id);
      return d < 0 ? 999 : d;
    }

    pool.sort((a, b) {
      final byClicks =
          (popularity[b.id] ?? 0).compareTo(popularity[a.id] ?? 0);
      return byClicks != 0 ? byClicks : rank(a).compareTo(rank(b));
    });
    return pool.take(topSize).toList();
  }

  /// Todas as perguntas desta conversa, agrupadas por categoria.
  static Map<String, List<ChatIntent>> byCategory(ChatContext c) {
    final map = <String, List<ChatIntent>>{};
    for (final i in forContext(c)) {
      final label = switch (i.audience) {
        ChatAudience.team => 'Para a equipe: ${i.category}',
        ChatAudience.prospect => 'Quero minha loja',
        ChatAudience.customer => i.category,
      };
      map.putIfAbsent(label, () => []).add(i);
    }
    return map;
  }

  /// Palavras que indicam dúvida específica (pedido, problema, cobrança):
  /// melhor uma pessoa responder.
  static const List<String> _humanSignals = [
    'meu pedido', 'nao chegou', 'veio errado',
    'veio quebrado', 'quebrado', 'danificado', 'faltando', 'faltou',
    'cobrado', 'cobranca indevida', 'cobraram', 'duas vezes', 'reembolso',
    'estorno', 'reclamacao', 'reclamar', 'procon', 'urgente', 'falar com',
    'atendente', 'pessoa', 'humano', 'ninguem responde', 'orcamento',
    'atacado', 'encomenda', 'personaliz', 'sob medida',
  ];

  /// Interpreta o texto digitado: pergunta conhecida, ou WhatsApp.
  static ChatReply reply(String text, ChatContext c) {
    final t = norm(text);
    final specific = _humanSignals.any(t.contains) ||
        RegExp(r'#\d+|pedido\s*(n[o.]?\s*)?\d').hasMatch(t);
    ChatIntent? best;
    var bestScore = 0;
    for (final i in forContext(c)) {
      var score = 0;
      for (final k in i.keywords) {
        if (t.contains(norm(k))) score += k.contains(' ') ? 2 : 1;
      }
      if (score > bestScore) {
        best = i;
        bestScore = score;
      }
    }
    // Pergunta longa com pouca correspondência também é específica.
    final weak = bestScore < 2 && t.split(' ').length > 18;
    // Dúvida específica com correspondência fraca: melhor não chutar uma
    // resposta pronta, só passar para uma pessoa.
    if (specific && bestScore < 2) best = null;
    return ChatReply(intent: best, toHuman: specific || weak || best == null);
  }

  // ---- Consulta de pedido ("em que pé está o pedido 123?") ----

  static final _orderNumber =
      RegExp(r'#\s*(\d+)|pedido\s*(?:n\s*[o.º°]*\s*|numero\s*)?(\d+)');

  /// Fala de um pedido do próprio usuário (com ou sem número)?
  ///
  /// Sem número, só "meu/minha pedido" + palavra de situação: "qual a forma
  /// de pagamento do pedido?" continua indo para a resposta de pagamento.
  static bool _asksAboutOrder(String t) =>
      _orderNumber.hasMatch(t) ||
      (RegExp(r'\b(meu|meus|minha|minhas) (pedido|compra)s?\b').hasMatch(t) &&
          RegExp(r'status|onde|chega|chegou|cade|situacao|andamento|'
                  r'como esta|saiu|pronto|nivel|pe esta|acompanh')
              .hasMatch(t));

  /// Responde sobre um pedido a partir dos pedidos que o app já carregou
  /// (as rules garantem que o cliente só recebe os dele). Devolve `null`
  /// quando a mensagem não é sobre um pedido — aí segue o fluxo normal.
  ///
  /// [loggedIn] falso: pede para entrar, sem chutar.
  static String? orderAnswer(String text, List<Order> orders,
      {required bool loggedIn}) {
    final t = norm(text);
    if (!_asksAboutOrder(t)) return null;
    if (!loggedIn) {
      return 'Para eu consultar seus pedidos, entre na sua conta primeiro '
          '(menu → "Entrar").';
    }

    final m = _orderNumber.firstMatch(t);
    final wanted = m == null ? null : int.tryParse(m.group(1) ?? m.group(2)!);
    if (wanted != null) {
      for (final o in orders) {
        if (int.tryParse(o.orderId) == wanted) return describeOrder(o);
      }
      return 'Não achei o pedido #${'$wanted'.padLeft(6, '0')} entre os seus '
          'pedidos. Confira o número em "Meus pedidos" e me mande de novo — '
          'por exemplo: "pedido 123".';
    }

    if (orders.isEmpty) {
      return 'Você ainda não tem pedidos nesta loja.';
    }
    if (orders.length == 1) return describeOrder(orders.first);
    final last = orders.take(3).map((o) =>
        '• ${o.formattedId} — ${o.statusText}${_dateSuffix(o.date)}');
    return 'Seus pedidos mais recentes:\n${last.join('\n')}\n\n'
        'Me mande o número para ver os detalhes — por exemplo: '
        '"pedido ${int.tryParse(orders.first.orderId) ?? orders.first.orderId}".';
  }

  static final _day = DateFormat('dd/MM');

  static String _dateSuffix(Timestamp? ts) =>
      ts == null ? '' : ' (feito em ${_day.format(ts.toDate())})';

  /// Situação de um pedido em linguagem de cliente.
  static String describeOrder(Order o) {
    final s = o.shipping;
    final lines = <String>[
      'Pedido ${o.formattedId}: ${o.statusText}.',
      if (o.date != null) 'Feito em ${_day.format(o.date!.toDate())}, '
          'total ${Br.money(o.price)}.',
      if (s.methodLabel.isNotEmpty) 'Forma de entrega: ${s.methodLabel}.',
    ];

    switch (o.status) {
      case Status.pendingPayment:
        lines.add('O pagamento ainda não foi confirmado. Se você pagou por '
            'Pix, a confirmação costuma levar alguns minutos.');
      case Status.preparing:
        lines.add('A loja está separando os seus produtos.');
      case Status.readyForPickup:
        lines.add('Já pode retirar! Leve o número do pedido.');
      case Status.transporting:
        lines.add('Seu pedido já saiu para entrega.');
      case Status.delivered:
        lines.add('Consta como entregue. Se não recebeu, fale com a loja.');
      case Status.canceled:
        lines.add('Este pedido foi cancelado.');
    }

    final active = o.status != Status.delivered && o.status != Status.canceled;
    if (active && s.scheduledDate != null) {
      lines.add('Data confirmada pela loja: '
          '${_day.format(s.scheduledDate!.toDate())}.');
    } else if (active && s.preferredDate != null) {
      lines.add('Data que você escolheu: '
          '${_day.format(s.preferredDate!.toDate())} (a loja ainda confirma).');
    }
    if (s.trackingCode.isNotEmpty) {
      final who = s.carrier.isEmpty ? '' : ' (${s.carrier})';
      lines.add('Rastreio$who: ${s.trackingCode}.');
    }
    if (o.deliveryChange?.isPending == true) {
      lines.add('A loja propôs outra forma de entrega: responda em '
          '"Meus pedidos".');
    }
    return lines.join('\n');
  }

  static DocumentReference<Map<String, dynamic>> get _statsRef =>
      Tenant.col('stats').doc('chat');

  static Future<Map<String, int>> popularity() async {
    try {
      final snap = await _statsRef.get();
      final counts = (snap.data()?['counts'] as Map?) ?? const {};
      return counts.map((k, v) => MapEntry('$k', (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> countClick(String intentId) async {
    try {
      await _statsRef.set({
        'counts': {intentId: FieldValue.increment(1)}
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Falha ao contar pergunta do chat: $e');
    }
  }
}
