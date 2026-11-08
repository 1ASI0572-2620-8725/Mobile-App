import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/i18n/language_service.dart';
import '../../../../shared/application/toast_service.dart';
import '../../../../shared/presentation/components/ui.dart';
import '../../../../shared/presentation/theme/app_theme.dart';
import '../../../domain/catalog_item_model.dart';
import '../../../infrastructure/inventory_api.dart';
import '../../../infrastructure/inventory_response.dart';

/// Las 7 categorías de umbrales del Edge: cualquier otra no tendría semáforo.
const _categories = ['Frutas', 'Verduras', 'Lácteos', 'Carnes', 'Proteínas', 'Panadería', 'Snacks'];

class _PartialProduct {
  const _PartialProduct({this.name, this.quantity, this.category});
  final String? name;
  final int? quantity;
  final String? category;
}

/// Equivalente a `inventory/presentation/view/form/inventory-form.ts`
/// (catálogo + formulario manual + dictado por voz).
class InventoryAddView extends StatefulWidget {
  const InventoryAddView({super.key});

  @override
  State<InventoryAddView> createState() => _InventoryAddViewState();
}

class _InventoryAddViewState extends State<InventoryAddView> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '0');
  final _imageUrl = TextEditingController();
  String category = '';
  DateTime? expirationDate;

  String mode = 'catalog'; // 'catalog' | 'manual'
  List<CatalogItem> catalog = [];
  bool catalogLoading = true;
  String catalogSearch = '';
  String catalogCategory = 'All';
  String pickedFrom = '';
  bool submitted = false;

  final _speech = SpeechToText();
  bool recording = false;
  String voiceHint = '';

  @override
  void initState() {
    super.initState();
    context
        .read<InventoryApi>()
        .getCatalog()
        .then((items) {
          if (mounted) {
            setState(() {
              catalog = items;
              catalogLoading = false;
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() {
              catalogLoading = false;
              mode = 'manual';
            });
          }
        });
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _quantity, _imageUrl]) {
      c.dispose();
    }
    _speech.cancel();
    super.dispose();
  }

  String _normalize(String text) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    var s = text.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s;
  }

  List<CatalogItem> get filteredCatalog {
    final term = _normalize(catalogSearch.trim());
    return catalog
        .where(
          (i) =>
              (term.isEmpty || _normalize(i.name).contains(term)) && (catalogCategory == 'All' || i.category == catalogCategory),
        )
        .toList();
  }

  void pick(CatalogItem item) => setState(() {
    _name.text = item.name;
    _description.text = item.description ?? '';
    category = item.category;
    _quantity.text = '1';
    _imageUrl.text = item.imageUrl ?? '';
    expirationDate = null;
    pickedFrom = item.name;
    mode = 'manual';
  });

  void setMode(String m) => setState(() {
    mode = m;
    if (m == 'catalog') pickedFrom = '';
  });

  // ---- Voz (equivale a la Web Speech API del front web) ----
  Future<void> startVoice() async {
    final ok = await _speech.initialize(
      onError: (_) => setState(() {
        voiceHint = context.trNow('inventory.form.speechError');
        recording = false;
      }),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') setState(() => recording = false);
      },
    );
    if (!ok) {
      setState(() => voiceHint = context.trNow('inventory.form.speechNotSupported'));
      return;
    }
    setState(() {
      voiceHint = context.trNow('inventory.form.listening');
      recording = true;
    });
    await _speech.listen(
      localeId: 'es_PE', // ignore: deprecated_member_use
      onResult: (r) {
        if (!r.finalResult) return;
        setState(() => voiceHint = '"${r.recognizedWords}"');
        _applyVoice(_parseVoiceCommand(r.recognizedWords));
      },
    );
  }

  Future<void> stopVoice() async {
    await _speech.stop();
    setState(() => recording = false);
  }

  _PartialProduct _parseVoiceCommand(String text) {
    final t = text.toLowerCase().trim();
    const numbers = {
      'uno': 1,
      'una': 1,
      'un': 1,
      'dos': 2,
      'tres': 3,
      'cuatro': 4,
      'cinco': 5,
      'seis': 6,
      'siete': 7,
      'ocho': 8,
      'nueve': 9,
      'diez': 10,
    };
    var qty = 0;
    final mNum = RegExp(r'\b(\d+)\b').firstMatch(t);
    if (mNum != null) {
      qty = int.parse(mNum.group(1)!);
    } else {
      for (final e in numbers.entries) {
        if (RegExp('\\b${e.key}\\b').hasMatch(t)) {
          qty = e.value;
          break;
        }
      }
    }
    const catMap = {
      'fruta': 'Frutas',
      'frutas': 'Frutas',
      'fruit': 'Frutas',
      'vegetal': 'Verduras',
      'verdura': 'Verduras',
      'verduras': 'Verduras',
      'vegetable': 'Verduras',
      'lácteos': 'Lácteos',
      'lacteos': 'Lácteos',
      'yogurt': 'Lácteos',
      'queso': 'Lácteos',
      'leche': 'Lácteos',
      'carne': 'Carnes',
      'pollo': 'Carnes',
      'res': 'Carnes',
      'pavo': 'Carnes',
      'pescado': 'Carnes',
      'huevo': 'Proteínas',
      'huevos': 'Proteínas',
      'pan': 'Panadería',
      'panadería': 'Panadería',
      'panaderia': 'Panadería',
      'snack': 'Snacks',
      'snacks': 'Snacks',
    };
    String? cat;
    for (final k in catMap.keys) {
      if (t.contains(k)) {
        cat = catMap[k];
        break;
      }
    }
    var name = t
        .replaceAll(RegExp(r'\b(\d+|uno|una|un|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez)\b'), '')
        .replaceAll(RegExp(r'\b(fruta|frutas|fruit|vegetal|verdura|vegetable|lácteos|lacteos|carne|grano|snack|category)\b'), '')
        .trim();
    if (name.isEmpty) name = t.split(RegExp(r'\s+')).last;
    return _PartialProduct(name: name, quantity: qty == 0 ? null : qty, category: cat);
  }

  void _applyVoice(_PartialProduct pp) => setState(() {
    if (pp.name != null && pp.name!.isNotEmpty) {
      _name.text = pp.name!.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
    }
    if (pp.quantity != null) _quantity.text = '${pp.quantity}';
    if (pp.category != null) category = pp.category!;
    mode = 'manual';
  });

  Future<void> pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: expirationDate ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => expirationDate = d);
  }

  Future<void> onSubmit() async {
    final toast = context.read<ToastService>();
    final lang = context.read<LanguageService>();
    setState(() => submitted = true);
    if (_name.text.trim().isEmpty || category.isEmpty || expirationDate == null) {
      return toast.error(lang.t('inventory.form.requiredFields'));
    }
    try {
      await context.read<InventoryApi>().createProduct(
        CreateProductRequest(
          name: _name.text.trim(),
          description: _description.text.trim(),
          category: category,
          quantity: int.tryParse(_quantity.text) ?? 0,
          imageUrl: _imageUrl.text.trim(),
          expirationDate: DateFormat('yyyy-MM-dd').format(expirationDate!),
        ),
      );
      toast.success(lang.t('inventory.form.addSuccess'));
      if (mounted) context.pop();
    } catch (_) {
      toast.error(lang.t('inventory.form.addError'));
    }
  }

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 12),
    child: Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: FsColors.danger),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final missing = submitted;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('inventory.add.title'))),
      body: ListView(
        padding: const EdgeInsets.all(FsSpace.s4),
        children: [
          PageHeader(
            eyebrow: context.tr('nav.inventory'),
            title: context.tr('inventory.add.title'),
            subtitle: context.tr('inventory.add.subtitle'),
          ),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'catalog', icon: const Icon(Icons.list_alt), label: Text(context.tr('inventory.catalog.tab'))),
              ButtonSegment(
                value: 'manual',
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.tr('inventory.catalog.manualTab')),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setMode(s.first),
          ),
          const SizedBox(height: FsSpace.s4),
          if (mode == 'catalog') ...[
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.tr('inventory.catalog.searchPlaceholder'),
              ),
              onChanged: (v) => setState(() => catalogSearch = v),
            ),
            const SizedBox(height: FsSpace.s3),
            FilterDropdown<String>(
              label: context.tr('inventory.category'),
              value: catalogCategory,
              items: {'All': context.tr('inventory.catalog.allCategories'), for (final c in _categories) c: c},
              onChanged: (v) => setState(() => catalogCategory = v),
            ),
            const SizedBox(height: FsSpace.s3),
            if (catalogLoading)
              Text(context.tr('inventory.catalog.loading'), style: const TextStyle(color: FsColors.textMuted))
            else if (filteredCatalog.isEmpty)
              EmptyState(
                icon: Icons.search_off,
                title: context.tr('inventory.catalog.empty'),
                action: OutlinedButton(
                  onPressed: () => setMode('manual'),
                  child: Text(context.tr('inventory.catalog.addManually')),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: FsSpace.s2,
                crossAxisSpacing: FsSpace.s2,
                childAspectRatio: .95,
                children: [
                  for (final item in filteredCatalog)
                    FsCard(
                      padding: EdgeInsets.zero,
                      onTap: () => pick(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(width: double.infinity, child: NetImage(item.imageUrl)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                FsBadge(item.category),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ] else ...[
            if (pickedFrom.isNotEmpty)
              FsCard(
                color: FsColors.primaryLight,
                padding: const EdgeInsets.all(FsSpace.s3),
                child: Text(context.tr('inventory.catalog.pickedHint', {'name': pickedFrom})),
              ),
            _label(context.tr('inventory.add.name'), required: true),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                errorText: missing && _name.text.trim().isEmpty ? context.tr('inventory.form.requiredFields') : null,
                suffixIcon: IconButton(
                  tooltip: context.tr(recording ? 'inventory.add.voiceStop' : 'inventory.add.voiceStart'),
                  icon: Icon(recording ? Icons.stop_circle : Icons.mic, color: recording ? FsColors.danger : FsColors.primary),
                  onPressed: recording ? stopVoice : startVoice,
                ),
              ),
            ),
            if (voiceHint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(voiceHint, style: const TextStyle(color: FsColors.textMuted, fontSize: 12)),
              ),
            _label(context.tr('inventory.add.description')),
            TextField(controller: _description, maxLines: 3),
            _label(context.tr('inventory.add.category'), required: true),
            DropdownButtonFormField<String>(
              initialValue: category.isEmpty ? null : category,
              hint: Text(context.tr('inventory.add.selectCategory')),
              items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => category = v ?? ''),
              decoration: InputDecoration(
                errorText: missing && category.isEmpty ? context.tr('inventory.form.requiredFields') : null,
              ),
            ),
            _label(context.tr('inventory.add.quantity')),
            TextField(controller: _quantity, keyboardType: TextInputType.number),
            _label(context.tr('inventory.add.expiration'), required: true),
            InkWell(
              onTap: pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                  errorText: missing && expirationDate == null ? context.tr('inventory.form.requiredFields') : null,
                  helperText: context.tr('inventory.add.expirationHint'),
                ),
                child: Text(expirationDate == null ? 'dd/mm/aaaa' : DateFormat('dd/MM/yyyy').format(expirationDate!)),
              ),
            ),
            _label(context.tr('inventory.add.image')),
            TextField(
              controller: _imageUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://example.com/product.jpg'),
            ),
            const SizedBox(height: FsSpace.s5),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => context.pop(), child: Text(context.tr('common.cancel'))),
                ),
                const SizedBox(width: FsSpace.s3),
                Expanded(
                  child: FilledButton(onPressed: onSubmit, child: Text(context.tr('inventory.add.cta'))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
