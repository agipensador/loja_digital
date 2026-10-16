import 'package:app_loja_digital/common/notify_prompt.dart';
import 'package:app_loja_digital/models/item_size.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/services/catalog_import.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

/// Importa o catálogo de uma planilha CSV (exportação da Shopify/Nuvemshop
/// ou o modelo do app), para não cadastrar produto por produto.
class ImportCatalogScreen extends StatefulWidget {
  const ImportCatalogScreen({super.key});

  @override
  State<ImportCatalogScreen> createState() => _ImportCatalogScreenState();
}

class _ImportCatalogScreenState extends State<ImportCatalogScreen> {
  CatalogImportResult? _result;
  String? _fileName;
  String? _locationId;
  bool _importing = false;
  int _done = 0;

  final _link = TextEditingController();
  final _pasted = TextEditingController();
  bool _loadingLink = false;

  @override
  void dispose() {
    _link.dispose();
    _pasted.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'json', 'xlsx', 'xls'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _fileName = file.name;
      _result = CatalogImport.parseFile(file.name, bytes);
    });
  }

  /// Link do Google Planilhas (ou de um CSV/JSON publicado).
  Future<void> _fromLink() async {
    final link = _link.text.trim();
    if (link.isEmpty) return;
    setState(() => _loadingLink = true);
    try {
      final res = await http.get(Uri.parse(CatalogImport.sheetCsvUrl(link)));
      if (res.statusCode != 200 || res.body.trimLeft().startsWith('<')) {
        throw Exception('status ${res.statusCode}');
      }
      setState(() {
        _fileName = 'Planilha do link';
        _result = CatalogImport.parseText(res.body);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não consegui abrir o link. No Google Planilhas, '
            'compartilhe como "Qualquer pessoa com o link" ou baixe como '
            'CSV e escolha o arquivo.'),
      ));
    } finally {
      if (mounted) setState(() => _loadingLink = false);
    }
  }

  void _fromPasted() {
    if (_pasted.text.trim().isEmpty) return;
    setState(() {
      _fileName = 'Texto colado';
      _result = CatalogImport.parseText(_pasted.text);
    });
  }

  Future<void> _import(List<ImportedProduct> products, String locationId) async {
    final manager = context.read<ProductManager>();
    setState(() {
      _importing = true;
      _done = 0;
    });
    for (final p in products) {
      final product = Product(
        name: p.name,
        description: p.description,
        category: p.category,
        sizes: [
          for (final v in p.variants.entries)
            ItemSize(
              name: v.key.isEmpty ? 'Único' : v.key,
              price: v.value.price,
              stockByLocation: {locationId: v.value.stock},
            ),
        ],
      );
      // Fotos entram como link (sem ocupar o armazenamento da loja).
      product.newImages = List<dynamic>.from(p.images);
      await product.save();
      manager.update(product);
      if (mounted) setState(() => _done++);
    }
    if (!mounted) return;
    setState(() => _importing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$_done produtos importados!'),
      backgroundColor: Colors.green,
    ));
    if (_done > 0) {
      await NotifyPrompt.ask(
        context,
        question: 'Deseja enviar uma notificação de novos produtos?',
        title: 'Novidades na loja!',
        body: _done == 1
            ? '${products.first.name} acabou de chegar. Confira no app!'
            : '$_done produtos novos acabaram de chegar. Confira no app!',
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final locations = context
        .watch<UserManager>()
        .allowedLocations(context.watch<StoresManager>());
    final locationId = locations.any((l) => l.id == _locationId)
        ? _locationId!
        : (locations.isEmpty ? kDefaultLocationId : locations.first.id!);

    final plan = context.watch<TenantManager>().store?.plan;
    final existing = context.watch<ProductManager>().allProducts.length;
    final r = _result;
    final room = plan == null ? 1 << 30 : plan.maxProducts - existing;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar catálogo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Traga todos os produtos de uma vez, em vez de cadastrar um a '
            'um. Funciona com:\n'
            '• planilha do Excel (.xlsx) ou CSV;\n'
            '• link do Google Planilhas;\n'
            '• arquivo JSON;\n'
            '• exportação da Shopify ou Nuvemshop;\n'
            '• o modelo do app (colunas: nome, descricao, categoria, '
            'variante, preco, estoque, imagem).\n'
            'Se preferir, mande a planilha no WhatsApp da Inforizz que a '
            'gente importa para você.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar modelo de planilha'),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: '${CatalogImport.templateHeader}\n'
                      '${CatalogImport.templateExample}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Modelo copiado — cole numa planilha.')));
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.upload_file),
            label: const Text('Escolher arquivo (Excel, CSV ou JSON)'),
            onPressed: _importing ? null : _pick,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Ou cole o link do Google Planilhas',
              hintText: 'https://docs.google.com/spreadsheets/d/...',
              suffixIcon: _loadingLink
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: 'Ler planilha do link',
                      icon: const Icon(Icons.download),
                      onPressed: _importing ? null : _fromLink,
                    ),
            ),
            onSubmitted: (_) => _fromLink(),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ou cole o conteúdo (CSV ou JSON)'),
            children: <Widget>[
              TextField(
                controller: _pasted,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: CatalogImport.jsonExample,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Ler conteúdo'),
                  onPressed: _importing ? null : _fromPasted,
                ),
              ),
            ],
          ),
          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Lido: $_fileName',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (r != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Formato: ${r.format}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${r.products.length} produtos, '
                        '${r.products.fold<int>(0, (t, p) => t + p.variants.length)} '
                        'variantes, '
                        '${r.products.fold<int>(0, (t, p) => t + p.images.length)} '
                        'fotos (por link)'),
                    for (final w in r.warnings.take(5))
                      Text('⚠ $w',
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12)),
                    if (r.products.length > room)
                      Text(
                        'Seu plano permite mais $room produtos: os '
                        '${r.products.length - room} excedentes não serão '
                        'importados (ou mude de plano).',
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ),
            ),
            if (locations.length > 1)
              DropdownButtonFormField<String>(
                initialValue: locationId,
                decoration: const InputDecoration(
                    labelText: 'O estoque da planilha vai para a unidade'),
                items: locations
                    .map((l) =>
                        DropdownMenuItem(value: l.id, child: Text(l.name)))
                    .toList(),
                onChanged: (v) => setState(() => _locationId = v),
              ),
            const SizedBox(height: 16),
            if (_importing)
              Column(
                children: <Widget>[
                  LinearProgressIndicator(
                      value: r.products.isEmpty
                          ? null
                          : _done / r.products.length),
                  const SizedBox(height: 8),
                  Text('Importando $_done de ${r.products.length}...'),
                ],
              )
            else if (r.products.isNotEmpty && room > 0)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _import(
                    r.products.take(room).toList(), locationId),
                child: Text(
                    'Importar ${r.products.length > room ? room : r.products.length} produtos'),
              ),
          ],
        ],
      ),
    );
  }
}
