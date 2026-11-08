import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/language_service.dart';
import '../../../../monitoring/infrastructure/monitoring_api.dart';
import '../../../../reports/domain/history_model.dart';
import '../../../../reports/infrastructure/reports_api.dart';
import '../../../../shared/presentation/components/ui.dart';
import '../../../../shared/presentation/theme/app_theme.dart';
import '../../../domain/product_model.dart';
import '../../../infrastructure/inventory_api.dart';
import '../../../infrastructure/inventory_response.dart';

const _all = 'All';
const _states = ['In good condition', 'Regular condition', 'Bad condition', 'No sensor data'];

/// Equivalente a `inventory/presentation/view/list/inventory.view.ts`.
class FoodInventoryView extends StatefulWidget {
  const FoodInventoryView({super.key});

  @override
  State<FoodInventoryView> createState() => _FoodInventoryViewState();
}

class _FoodInventoryViewState extends State<FoodInventoryView> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  String searchTerm = '';
  List<String> categories = [_all];
  String selectedState = _all;
  String selectedCategory = _all;
  bool loading = true;

  // Frescura ya clasificada por el Edge (semáforo) en la última lectura.
  String? _lastStatus;
  String? _lastCategory;

  @override
  void initState() {
    super.initState();
    _loadLatestThenProducts();
  }

  Future<void> _loadLatestThenProducts() async {
    try {
      final r = await context.read<MonitoringApi>().getLatest();
      _lastStatus = r?.status;
      _lastCategory = r?.category;
    } catch (_) {}
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final data = await context.read<InventoryApi>().getProducts();
      products = data
          .map(
            (ProductResponse p) => Product(
              id: p.id,
              name: p.name,
              image: p.imageUrl,
              state: _computeState(p.category, p.expirationDate),
              category: p.category,
              description: p.description,
              quantity: p.quantity,
              expirationDate: p.expirationDate,
              createdAt: p.createdAt,
            ),
          )
          .toList();
    } catch (_) {
      products = [];
    }
    _rebuildCategories();
    if (mounted) {
      setState(() {
        loading = false;
        filterProducts();
      });
    }
  }

  void _rebuildCategories() {
    final unique = products.map((p) => p.category).whereType<String>().where((c) => c.isNotEmpty).toSet();
    categories = [_all, ...unique];
    if (!categories.contains(selectedCategory)) selectedCategory = _all;
  }

  /// Manda el peor entre el semáforo del Edge (si coincide la categoría) y la
  /// cercanía del vencimiento (vencido = malo; ≤2 días = al menos regular).
  String _computeState(String? category, String? expirationDate) {
    final levels = <int>[];
    if (_lastStatus != null && _lastCategory != null && (category ?? '').toLowerCase() == _lastCategory!.toLowerCase()) {
      const sensor = {'GREEN': 0, 'YELLOW': 1, 'RED': 2};
      if (sensor.containsKey(_lastStatus)) levels.add(sensor[_lastStatus]!);
    }
    final days = daysToExpiry(expirationDate);
    if (days != null) {
      levels.add(
        days < 0
            ? 2
            : days <= 2
            ? 1
            : 0,
      );
    }
    if (levels.isEmpty) return 'No sensor data';
    return switch (levels.reduce((a, b) => a > b ? a : b)) {
      0 => 'In good condition',
      1 => 'Regular condition',
      _ => 'Bad condition',
    };
  }

  /// Días hasta el vencimiento (negativo = vencido); null si no tiene fecha.
  int? daysToExpiry(String? expirationDate) {
    if (expirationDate == null) return null;
    final exp = DateTime.tryParse(expirationDate);
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(exp.year, exp.month, exp.day).difference(today).inDays;
  }

  String expiryKey(Product p) {
    final days = daysToExpiry(p.expirationDate);
    if (days == null) return 'inventory.expiry.none';
    if (days < 0) return 'inventory.expiry.expired';
    if (days == 0) return 'inventory.expiry.today';
    if (days == 1) return 'inventory.expiry.tomorrow';
    return 'inventory.expiry.inDays';
  }

  void filterProducts() {
    final term = searchTerm.trim().toLowerCase();
    filteredProducts = products.where((p) {
      final stateMatch = selectedState == _all || p.state == selectedState;
      final categoryMatch = selectedCategory == _all || p.category == selectedCategory;
      final searchMatch = term.isEmpty || p.name.toLowerCase().contains(term);
      return stateMatch && categoryMatch && searchMatch;
    }).toList();
  }

  static const _thumbColors = {
    'fruit': Color(0xFFDCEEDE),
    'vegetable': Color(0xFFE2EDDA),
    'dairy': Color(0xFFDDE8F5),
    'grain': Color(0xFFF2E9D8),
    'meat': Color(0xFFF5DEDE),
    'snack': Color(0xFFECDDF5),
  };

  Color thumbBg(String? category) => _thumbColors[(category ?? '').toLowerCase()] ?? const Color(0xFFE6EEEA);

  FsStatus _stateStatus(String? state) => switch (state) {
    'In good condition' => FsStatus.ok,
    'Regular condition' => FsStatus.warn,
    'Bad condition' => FsStatus.crit,
    _ => FsStatus.off,
  };

  Future<void> logAction(Product p, String action) async {
    final api = context.read<InventoryApi>();
    try {
      if (action == 'consume') {
        final updated = await api.updateProduct(p.id, UpdateProductRequest(quantity: (p.quantity - 1).clamp(0, 1 << 30)));
        p.quantity = updated.quantity;
        _postHistory(p, 'consume', 1);
      } else {
        await api.deleteProduct(p.id);
        _postHistory(p, 'discard', p.quantity);
        products.removeWhere((x) => x.id == p.id);
        if (mounted) Navigator.of(context).maybePop();
      }
      if (mounted) setState(filterProducts);
    } catch (_) {}
  }

  void _postHistory(Product p, String action, int quantity) {
    // El backend (y el análisis premium US17) espera CONSUMED / DISCARDED.
    context
        .read<ReportsApi>()
        .create(
          HistoryEntry(
            productId: p.id,
            productName: p.name,
            category: p.category ?? '',
            action: action == 'consume' ? 'CONSUMED' : 'DISCARDED',
            quantity: quantity,
            date: '',
          ),
        )
        .ignore();
  }

  void openProduct(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final days = daysToExpiry(p.expirationDate);
          String fmtDate(String? s, String pattern) {
            final d = s == null ? null : DateTime.tryParse(s);
            return d == null ? '—' : DateFormat(pattern).format(d.toLocal());
          }

          Widget row(String label, String value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(label, style: const TextStyle(color: FsColors.textMuted)),
                ),
                Expanded(
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(FsSpace.s5, 0, FsSpace.s5, FsSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                FsBadge(p.state ?? '', status: _stateStatus(p.state)),
                const SizedBox(height: 12),
                if ((p.description ?? '').isNotEmpty) row(context.tr('inventory.details.description'), p.description!),
                row(context.tr('inventory.details.state'), p.state ?? context.tr('inventory.details.notSpecified')),
                row(
                  context.tr('inventory.details.expiration'),
                  p.expirationDate == null
                      ? context.tr('inventory.expiry.none')
                      : '${fmtDate(p.expirationDate, 'dd/MM/yyyy')} · ${context.tr(expiryKey(p), {'days': (days ?? 0).abs()})}',
                ),
                row(context.tr('inventory.details.added'), fmtDate(p.createdAt, 'dd/MM/yyyy HH:mm')),
                row(context.tr('inventory.quantity'), '${p.quantity}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restaurant),
                        label: Text(context.tr('reports.history.consume')),
                        onPressed: () async {
                          await logAction(p, 'consume');
                          setSheet(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: FsColors.danger),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.tr('reports.history.discard')),
                        onPressed: () => logAction(p, 'discard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> onAddProduct() async {
    await context.push('/inventory/add');
    if (mounted) {
      setState(() => loading = true);
      _loadLatestThenProducts();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: onAddProduct,
      icon: const Icon(Icons.add),
      label: Text(context.tr('inventory.add.cta')),
      backgroundColor: FsColors.primary,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _loadLatestThenProducts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(FsSpace.s4, FsSpace.s4, FsSpace.s4, 96),
        children: [
          PageHeader(
            eyebrow: context.tr('nav.inventory'),
            title: context.tr('inventory.title'),
            subtitle: context.tr('inventory.subtitle'),
          ),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.tr('inventory.searchPlaceholder'),
            ),
            onChanged: (v) => setState(() {
              searchTerm = v;
              filterProducts();
            }),
          ),
          const SizedBox(height: FsSpace.s3),
          Row(
            children: [
              Expanded(
                child: FilterDropdown<String>(
                  label: context.tr('inventory.state'),
                  value: selectedState,
                  items: {_all: context.tr('inventory.allStates'), for (final s in _states) s: s},
                  onChanged: (v) => setState(() {
                    selectedState = v;
                    filterProducts();
                  }),
                ),
              ),
              const SizedBox(width: FsSpace.s3),
              Expanded(
                child: FilterDropdown<String>(
                  label: context.tr('inventory.category'),
                  value: selectedCategory,
                  items: {_all: context.tr('inventory.allCategories'), for (final c in categories.skip(1)) c: c},
                  onChanged: (v) => setState(() {
                    selectedCategory = v;
                    filterProducts();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: FsSpace.s4),
          if (loading)
            const SkeletonList(count: 6, height: 76)
          else if (filteredProducts.isEmpty)
            FsCard(
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: context.tr('inventory.empty.title'),
                hint: context.tr('inventory.empty.hint'),
                action: FilledButton(onPressed: onAddProduct, child: Text(context.tr('inventory.add.cta'))),
              ),
            )
          else
            for (final p in filteredProducts)
              Padding(
                padding: const EdgeInsets.only(bottom: FsSpace.s2),
                child: FsCard(
                  padding: const EdgeInsets.all(FsSpace.s3),
                  onTap: () => openProduct(p),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(FsRadius.md),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: NetImage(
                            p.image,
                            fallback: Container(
                              color: thumbBg(p.category),
                              alignment: Alignment.center,
                              child: Text(
                                p.name.trim().isEmpty ? '?' : p.name.trim()[0].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: FsColors.primaryDark),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              p.category?.isNotEmpty == true ? p.category! : context.tr('inventory.uncategorized'),
                              style: const TextStyle(color: FsColors.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                StatusDot(_stateStatus(p.state), size: 8),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(p.state ?? '', style: const TextStyle(fontSize: 12, color: FsColors.textSecondary)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: FsColors.primaryLight, borderRadius: BorderRadius.circular(FsRadius.md)),
                        child: Text(
                          '${p.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: FsColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
