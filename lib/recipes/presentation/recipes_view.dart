import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/language_service.dart';
import '../../inventory/infrastructure/inventory_api.dart';
import '../../shared/presentation/components/ui.dart';
import '../../shared/presentation/theme/app_theme.dart';
import '../domain/recipe_model.dart';
import '../infrastructure/recipes_api.dart';

const _maxRecommended = 6;
const _defaultFoodImage =
    'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=960&h=720&dpr=1';

/// Equivalente a `recipes/presentation/recipes.view.ts`
/// (recomendaciones según el inventario + generación con IA).
class RecipesView extends StatefulWidget {
  const RecipesView({super.key});

  @override
  State<RecipesView> createState() => _RecipesViewState();
}

class _RecipesViewState extends State<RecipesView> {
  List<Recipe> recipes = [];
  List<Recipe> filteredRecipes = [];
  List<Recipe> recommended = [];
  bool showAll = false;
  final Map<int, int> _matchCount = {};

  String searchTerm = '';
  String selectedLevel = 'All';
  String selectedType = 'All';
  bool loading = true;
  bool generating = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final recipesApi = context.read<RecipesApi>();
    final inventoryApi = context.read<InventoryApi>();
    final results = await Future.wait([
      recipesApi.getAll().catchError((_) => <Recipe>[]),
      inventoryApi.getProducts().then((p) => p.map((e) => e.name).toList()).catchError((_) => <String>[]),
    ]);
    if (!mounted) return;
    setState(() {
      recipes = results[0] as List<Recipe>;
      _matchCount.clear();
      _buildRecommendations(results[1] as List<String>);
      showAll = recommended.isEmpty;
      filterRecipes();
      loading = false;
    });
  }

  /// Genera un catálogo nuevo con IA y recarga la vista.
  Future<void> generateNewRecipes() async {
    setState(() => generating = true);
    try {
      await context.read<RecipesApi>().generateBatch();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      generating = false;
      loading = true;
    });
    _loadRecipes();
  }

  String _normalize(String text) {
    const from = 'áàäâéèëêíìïîóòöôúùüû';
    const to = 'aaaaeeeeiiiioooouuuu';
    var s = text.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s;
  }

  /// Iguala plural/singular simple: "manzanas" y "manzana" cuentan igual.
  String _singular(String w) => w.endsWith('s') && w.length > 3 ? w.substring(0, w.length - 1) : w;

  /// Puntúa cada receta por cuántos alimentos del inventario aparecen en sus ingredientes.
  void _buildRecommendations(List<String> productNames) {
    final tokens = <String>{};
    for (final name in productNames) {
      for (final word in _normalize(name).split(RegExp(r'\s+'))) {
        if (word.length >= 3) tokens.add(_singular(word));
      }
    }
    recommended = [];
    if (tokens.isEmpty) return;
    for (final r in recipes) {
      final words = _normalize(r.ingredients.join(' ')).split(RegExp(r'\s+')).map(_singular).toSet();
      final count = tokens.where(words.contains).length;
      if (count > 0) _matchCount[r.id] = count;
    }
    recommended = recipes.where((r) => _matchCount.containsKey(r.id)).toList()
      ..sort((a, b) => (_matchCount[b.id] ?? 0).compareTo(_matchCount[a.id] ?? 0));
    if (recommended.length > _maxRecommended) recommended = recommended.sublist(0, _maxRecommended);
  }

  void filterRecipes() {
    final term = searchTerm.trim().toLowerCase();
    filteredRecipes = recipes.where((r) {
      final matchesText =
          term.isEmpty || r.title.toLowerCase().contains(term) || (r.description ?? '').toLowerCase().contains(term);
      final matchesLevel = selectedLevel == 'All' || (r.level ?? '').toLowerCase() == selectedLevel.toLowerCase();
      final matchesType = selectedType == 'All' || (r.type ?? '').toLowerCase() == selectedType.toLowerCase();
      return matchesText && matchesLevel && matchesType;
    }).toList();
  }

  List<Recipe> get visibleRecipes => showAll ? filteredRecipes : recommended;

  String imageFor(Recipe r) => (r.image ?? '').trim().isNotEmpty ? r.image! : _defaultFoodImage;

  void openModal(Recipe r) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: NetImage(imageFor(r), fallback: Image.network(_defaultFoodImage, fit: BoxFit.cover)),
          ),
          Padding(
            padding: const EdgeInsets.all(FsSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (r.level != null) _meta(Icons.bar_chart, r.level!),
                    if (r.time != null) _meta(Icons.schedule, r.time!),
                    if (r.type != null) _meta(Icons.restaurant, r.type!),
                    if (r.rating != null) _meta(Icons.star, '${r.rating}', color: FsColors.warning),
                  ],
                ),
                if ((r.description ?? '').isNotEmpty) ...[const SizedBox(height: 12), Text(r.description!)],
                const SizedBox(height: 18),
                Text(context.tr('recipes.ingredients'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                for (final i in r.ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(top: 7), child: StatusDot(FsStatus.ok, size: 6)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(i)),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Text(context.tr('recipes.steps'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                for (final (idx, s) in r.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: FsColors.primaryLight,
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(fontSize: 12, color: FsColors.primaryDark, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _meta(IconData icon, String text, {Color color = FsColors.textMuted}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(text),
    ],
  );

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _loadRecipes,
    child: ListView(
      padding: const EdgeInsets.all(FsSpace.s4),
      children: [
        PageHeader(
          eyebrow: context.tr('nav.recipes'),
          title: context.tr('recipes.title'),
          subtitle: context.tr('recipes.subtitle'),
          actions: [
            FilledButton.icon(
              onPressed: generating ? null : generateNewRecipes,
              icon: generating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(context.tr(generating ? 'recipes.generating' : 'recipes.generate')),
            ),
          ],
        ),
        if (generating)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(context.tr('recipes.generatingHint'), style: const TextStyle(color: FsColors.textMuted)),
          ),
        FsCard(
          color: FsColors.primaryLight,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('recipes.recommended.title'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      context.tr('recipes.recommended.subtitle'),
                      style: const TextStyle(color: FsColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => showAll = !showAll),
                child: Text(
                  showAll
                      ? context.tr('recipes.recommended.back')
                      : '${context.tr('recipes.recommended.showAll')} (${recipes.length})',
                ),
              ),
            ],
          ),
        ),
        if (showAll) ...[
          const SizedBox(height: FsSpace.s3),
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('recipes.searchPlaceholder')),
            onChanged: (v) => setState(() {
              searchTerm = v;
              filterRecipes();
            }),
          ),
          const SizedBox(height: FsSpace.s3),
          Row(
            children: [
              Expanded(
                child: FilterDropdown<String>(
                  label: context.tr('recipes.level'),
                  value: selectedLevel,
                  items: {
                    'All': context.tr('recipes.filters.allLevels'),
                    'Easy': context.tr('recipes.filters.easy'),
                    'Intermediate': context.tr('recipes.filters.intermediate'),
                    'Advanced': context.tr('recipes.filters.advanced'),
                  },
                  onChanged: (v) => setState(() {
                    selectedLevel = v;
                    filterRecipes();
                  }),
                ),
              ),
              const SizedBox(width: FsSpace.s3),
              Expanded(
                child: FilterDropdown<String>(
                  label: context.tr('recipes.type'),
                  value: selectedType,
                  items: {
                    'All': context.tr('recipes.filters.allTypes'),
                    'Breakfast': context.tr('recipes.filters.breakfast'),
                    'Meals': context.tr('recipes.filters.meals'),
                    'Snacks': context.tr('recipes.filters.snacks'),
                  },
                  onChanged: (v) => setState(() {
                    selectedType = v;
                    filterRecipes();
                  }),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: FsSpace.s4),
        if (loading)
          const SkeletonList(count: 3, height: 220)
        else if (visibleRecipes.isEmpty)
          FsCard(
            child: EmptyState(icon: Icons.menu_book_outlined, title: context.tr('recipes.empty')),
          )
        else
          for (final r in visibleRecipes)
            Padding(
              padding: const EdgeInsets.only(bottom: FsSpace.s3),
              child: FsCard(
                padding: EdgeInsets.zero,
                onTap: () => openModal(r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 8,
                          child: NetImage(imageFor(r), fallback: Image.network(_defaultFoodImage, fit: BoxFit.cover)),
                        ),
                        if (r.level != null) Positioned(top: 10, left: 10, child: FsBadge(r.level!, status: FsStatus.ok)),
                        if ((_matchCount[r.id] ?? 0) > 0)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: FsBadge(
                              '${_matchCount[r.id]} ${context.tr('recipes.recommended.matches')}',
                              status: FsStatus.warn,
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(FsSpace.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if ((r.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              r.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: FsColors.textSecondary),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 14,
                            children: [
                              if (r.time != null) _meta(Icons.schedule, r.time!),
                              if (r.type != null) _meta(Icons.restaurant, r.type!),
                              if (r.rating != null) _meta(Icons.star, '${r.rating}', color: FsColors.warning),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}
