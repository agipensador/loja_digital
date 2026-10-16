import 'package:app_loja_digital/core/platform_contact.dart';
import 'package:app_loja_digital/models/delivery_zones_manager.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/services/chatbot.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Kind { text, hello, menu }

class _Msg {
  const _Msg(
    this.text, {
    this.fromUser = false,
    this.kind = _Kind.text,
    this.whatsappUrl,
    this.related = const [],
    this.route,
    this.routeLabel,
  });

  final String text;
  final bool fromUser;
  final _Kind kind;
  final String? whatsappUrl;
  final List<String> related;
  final String? route;
  final String? routeLabel;
}

/// Atendimento: começa com o menu das perguntas mais feitas (clicáveis),
/// aceita texto livre e passa para o WhatsApp quando a dúvida é específica.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Map<String, int> _popularity = {};

  ChatContext _context() {
    final tenant = context.read<TenantManager>();
    final name = tenant.store?.name.isNotEmpty == true
        ? tenant.store!.name
        : context.read<ThemeManager>().storeName;
    return ChatContext(
      storeName: name,
      locations: context.read<StoresManager>().stores,
      zones: context.read<DeliveryZonesManager>().zones,
      isTeam: context.read<UserManager>().adminEnabled,
      plan: tenant.store?.plan,
      isPlatformStore: PlatformContact.isPlatformStore,
      attendingLocationId: context.read<StoresManager>().currentLocationId,
    );
  }

  @override
  void initState() {
    super.initState();
    Chatbot.popularity().then((p) {
      if (mounted) setState(() => _popularity = p);
    });
    _messages.add(const _Msg('', kind: _Kind.hello));
    _messages.add(const _Msg('', kind: _Kind.menu));
  }

  /// Saudação montada na hora de desenhar: o nome da loja pode chegar do
  /// Firestore depois que a tela abriu.
  String _hello(ChatContext c) => c.isPlatformStore
      ? 'Olá! Sou o assistente da Inforizz. Posso explicar como ter a sua '
          'loja com app próprio.'
      : c.isTeam
          ? 'Olá! Sou o assistente da ${c.storeName}. Posso explicar como '
              'usar o sistema da sua loja.'
          : 'Olá! Sou o assistente da ${c.storeName}. Como posso ajudar?\n\n'
              'Para saber a situação de um pedido, escreva o número — por '
              'exemplo: "pedido 123".';

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  _Msg _answerMsg(ChatIntent intent, ChatContext c) {
    final a = intent.answer(c);
    final url = a.whatsappText == null ? null : c.humanUrl(a.whatsappText!);
    // A resposta manda falar com a loja, mas ela não tem WhatsApp: avisa.
    final noWhatsapp = a.whatsappText != null && url == null;
    return _Msg(
      noWhatsapp ? '${a.text}\n\n${ChatContext.whatsappUnavailable}' : a.text,
      related: a.related,
      whatsappUrl: url,
      route: a.route,
      routeLabel: a.routeLabel,
    );
  }

  void _ask(ChatIntent intent, {String? typed}) {
    final c = _context();
    Chatbot.countClick(intent.id);
    setState(() {
      _messages.add(_Msg(typed ?? intent.question, fromUser: true));
      _messages.add(_answerMsg(intent, c));
    });
    _scrollDown();
  }

  void _sendTyped() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final c = _context();

    // "Em que pé está o pedido 123?" — responde com o pedido de verdade.
    // A equipe consulta qualquer pedido da loja; o cliente, só os dele.
    final orders = context.read<OrdersManager>();
    final status = Chatbot.orderAnswer(
      text,
      // Sem `myOrders`: ele aplica a busca digitada na tela de pedidos.
      c.isTeam
          ? orders.orders
          : orders.orders.where((o) => o.userId == orders.userId).toList(),
      loggedIn: context.read<UserManager>().isLoggedIn,
    );
    if (status != null) {
      setState(() {
        _messages.add(_Msg(text, fromUser: true));
        _messages.add(_Msg(status));
      });
      _scrollDown();
      return;
    }

    final r = Chatbot.reply(text, c);
    setState(() {
      _messages.add(_Msg(text, fromUser: true));
      if (r.intent != null) {
        Chatbot.countClick(r.intent!.id);
        _messages.add(_answerMsg(r.intent!, c));
      }
      if (r.toHuman && !c.hasHuman) {
        _messages.add(_Msg(r.intent == null
            ? 'Não tenho uma resposta pronta para isso. '
                '${ChatContext.whatsappUnavailable} Veja os assuntos em '
                '"Perguntas frequentes", no botão ao lado do campo de texto.'
            : ChatContext.whatsappUnavailable));
      } else if (r.toHuman) {
        _messages.add(_Msg(
          r.intent == null
              ? 'Essa dúvida é melhor com uma pessoa. Toque abaixo para falar '
                  'com a ${c.humanName} no WhatsApp: sua pergunta já vai '
                  'escrita.'
              : 'Se for algo específico do seu caso, fale com a '
                  '${c.humanName} no WhatsApp: sua pergunta já vai escrita.',
          whatsappUrl: c.humanUrl(text),
        ));
      }
    });
    _scrollDown();
  }

  void _openAllTopics() {
    final c = _context();
    final top = Chatbot.top(c, _popularity);
    final groups = Chatbot.byCategory(c);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          children: <Widget>[
            const _SheetTitle('Mais perguntadas'),
            for (final i in top) _TopicTile(i, onTap: () {
              Navigator.pop(sheet);
              _ask(i);
            }),
            for (final entry in groups.entries) ...[
              _SheetTitle(entry.key),
              for (final i in entry.value)
                _TopicTile(i, onTap: () {
                  Navigator.pop(sheet);
                  _ask(i);
                }),
            ],
            if (c.humanUrl('Olá! Vim pelo atendimento do app.')
                case final url?)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.whatsapp,
                    color: Color(0xFF25D366)),
                title: Text('Falar com a ${c.humanName} no WhatsApp'),
                onTap: () {
                  Navigator.pop(sheet);
                  _launch(url);
                },
              )
            else
              const ListTile(
                enabled: false,
                leading: FaIcon(FontAwesomeIcons.whatsapp),
                title: Text(ChatContext.whatsappUnavailable),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    // Reconstrói quando login/loja mudam.
    context.watch<UserManager>();
    context.watch<TenantManager>();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Atendimento')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                if (m.kind == _Kind.menu) {
                  final c = _context();
                  return _TopMenu(
                    top: Chatbot.top(c, _popularity),
                    answerFor: (intent) => _answerMsg(intent, c),
                    onAsk: _ask,
                    onMore: _openAllTopics,
                    onLaunch: _launch,
                  );
                }
                return _Bubble(
                  m.kind == _Kind.hello ? _Msg(_hello(_context())) : m,
                  primary: primary,
                  onAsk: _ask,
                  onLaunch: _launch,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    tooltip: 'Perguntas frequentes',
                    icon: const Icon(Icons.list_alt),
                    onPressed: _openAllTopics,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendTyped(),
                      decoration: const InputDecoration(
                        hintText: 'Escreva sua dúvida...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Enviar',
                    icon: Icon(Icons.send, color: primary),
                    onPressed: _sendTyped,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu inicial: as perguntas mais feitas, num bloco que abre e fecha.
///
/// Cada pergunta é um acordeão: o toque abre a resposta NO PRÓPRIO ITEM, sem
/// virar mensagem na conversa, e fecha a que estava aberta — só uma por vez.
/// "Ver todos os assuntos" continua mandando a pergunta para a conversa.
class _TopMenu extends StatefulWidget {
  const _TopMenu({
    required this.top,
    required this.answerFor,
    required this.onAsk,
    required this.onMore,
    required this.onLaunch,
  });

  final List<ChatIntent> top;
  final _Msg Function(ChatIntent) answerFor;
  final void Function(ChatIntent) onAsk;
  final VoidCallback onMore;
  final Future<void> Function(String) onLaunch;

  @override
  State<_TopMenu> createState() => _TopMenuState();
}

class _TopMenuState extends State<_TopMenu> {
  String? _openId;

  void _toggle(ChatIntent i) {
    final opening = _openId != i.id;
    setState(() => _openId = opening ? i.id : null);
    // Abrir conta como toque: é o que ordena o menu das mais tocadas.
    if (opening) Chatbot.countClick(i.id);
  }

  /// Pergunta relacionada: se está no menu, abre ali; senão, vai para a
  /// conversa como as do "Ver todos".
  void _related(ChatIntent i) {
    if (widget.top.any((t) => t.id == i.id)) {
      _toggle(i);
    } else {
      widget.onAsk(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.local_fire_department),
        title: const Text('Perguntas mais feitas',
            style: TextStyle(fontWeight: FontWeight.w600)),
        children: <Widget>[
          for (final i in widget.top) ...[
            ListTile(
              dense: true,
              selected: _openId == i.id,
              leading: const Icon(Icons.chat_bubble_outline, size: 20),
              title: Text(i.question,
                  style: _openId == i.id
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null),
              trailing: AnimatedRotation(
                turns: _openId == i.id ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more),
              ),
              onTap: () => _toggle(i),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _openId == i.id
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.06),
                        border: Border(
                            left: BorderSide(color: primary, width: 3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _AnswerBody(
                        widget.answerFor(i),
                        onAsk: _related,
                        onLaunch: widget.onLaunch,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          TextButton.icon(
            icon: const Icon(Icons.expand_more),
            label: const Text('Ver todos os assuntos'),
            onPressed: widget.onMore,
          ),
        ],
      ),
    );
  }
}

/// Texto da resposta + botões (WhatsApp, abrir tela, perguntas relacionadas).
/// Usado na bolha da conversa e na resposta aberta no menu.
class _AnswerBody extends StatelessWidget {
  const _AnswerBody(this.m,
      {required this.onAsk, required this.onLaunch, this.textColor});

  final _Msg m;
  final void Function(ChatIntent) onAsk;
  final Future<void> Function(String) onLaunch;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SelectableText(m.text,
            style: TextStyle(color: textColor ?? Colors.black87)),
        if (m.whatsappUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366)),
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
              label: const Text('Continuar no WhatsApp'),
              onPressed: () => onLaunch(m.whatsappUrl!),
            ),
          ),
        if (m.route != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.storefront),
              label: Text(m.routeLabel ?? 'Abrir'),
              onPressed: () => Navigator.of(context).pushNamed(m.route!),
            ),
          ),
        if (m.related.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in m.related)
                  if (Chatbot.byId(id) case final intent?)
                    ActionChip(
                      label: Text(intent.question,
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () => onAsk(intent),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m,
      {required this.primary, required this.onAsk, required this.onLaunch});

  final _Msg m;
  final Color primary;
  final void Function(ChatIntent) onAsk;
  final Future<void> Function(String) onLaunch;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: m.fromUser ? primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _AnswerBody(
          m,
          onAsk: onAsk,
          onLaunch: onLaunch,
          textColor: m.fromUser ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}

class _TopicTile extends StatelessWidget {
  const _TopicTile(this.intent, {required this.onTap});
  final ChatIntent intent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        title: Text(intent.question),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
