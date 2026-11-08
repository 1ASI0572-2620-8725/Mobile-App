import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/language_service.dart';
import '../../monitoring/infrastructure/monitoring_api.dart';
import '../../shared/presentation/components/ui.dart';
import '../../shared/presentation/theme/app_theme.dart';
import '../domain/history_model.dart';
import '../infrastructure/reports_api.dart';

const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Equivalente a `reports/presentation/reports.view.ts`.
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  List<double> humidity = [];
  List<double> temperature = [];
  List<double> ethylene = [];

  int gainPct = 0;
  int lossPct = 0;
  int improvementPct = 0;

  List<({String label, int wasteKg})> days = [];
  List<HistoryEntry> history = [];
  List<HistoryEntry> filtered = [];

  DateTime? hFrom;
  DateTime? hTo;
  String hAction = ''; // '' | consume | discard | add
  String hCategory = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => Future.wait([loadHistory(), _loadTrends()]);

  Future<void> _loadTrends() async {
    try {
      final readings = await context.read<MonitoringApi>().getAll();
      readings.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      final last = readings.length > 20 ? readings.sublist(readings.length - 20) : readings;
      if (mounted) {
        setState(() {
          temperature = last.map((r) => r.temperature).toList();
          humidity = last.map((r) => r.humidity).toList();
          ethylene = last.where((r) => r.ethyleneLevel != null).map((r) => r.ethyleneLevel!).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => temperature = humidity = ethylene = []);
    }
  }

  Future<void> loadHistory() async {
    try {
      history = await context.read<ReportsApi>().getAll();
    } catch (_) {
      history = [];
    }
    if (!mounted) return;
    setState(() {
      _computeWeeklyWaste();
      _computeKpis();
      applyHistoryFilters();
    });
  }

  DateTime? _date(String s) => DateTime.tryParse(s)?.toLocal();

  void _computeWeeklyWaste() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final waste = <DateTime, int>{for (var i = 0; i < 7; i++) start.add(Duration(days: i)): 0};
    for (final e in history.where((e) => _isAction(e.action, 'discard'))) {
      final d = _date(e.date);
      if (d == null) continue;
      final key = DateTime(d.year, d.month, d.day);
      if (waste.containsKey(key)) waste[key] = waste[key]! + e.quantity;
    }
    days = waste.entries.map((e) => (label: _dayLabels[e.key.weekday % 7], wasteKg: e.value)).toList();
  }

  /// Acepta el formato nuevo (CONSUMED/DISCARDED) y el antiguo (consume/discard).
  bool _isAction(String value, String kind) {
    final v = value.toLowerCase();
    return kind == 'consume' ? (v == 'consumed' || v == 'consume') : (v == 'discarded' || v == 'discard');
  }

  void _computeKpis() {
    final consumed = history.where((e) => _isAction(e.action, 'consume')).fold<int>(0, (a, e) => a + e.quantity);
    final discarded = history.where((e) => _isAction(e.action, 'discard')).fold<int>(0, (a, e) => a + e.quantity);
    final total = consumed + discarded;
    gainPct = total > 0 ? (consumed / total * 100).round() : 0;
    lossPct = total > 0 ? (discarded / total * 100).round() : 0;
    improvementPct = gainPct - lossPct;
  }

  void applyHistoryFilters() {
    filtered = history.where((e) {
      final t = _date(e.date);
      final okAction = hAction.isEmpty || (hAction == 'add' ? e.action == 'add' : _isAction(e.action, hAction));
      final okCategory = hCategory.isEmpty || e.category.toLowerCase() == hCategory.toLowerCase();
      final okDate =
          t == null || ((hFrom == null || !t.isBefore(hFrom!)) && (hTo == null || !t.isAfter(hTo!.add(const Duration(days: 1)))));
      return okAction && okCategory && okDate;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> exportCSV() async {
    String q(Object v) => '"${v.toString().replaceAll('"', '""')}"';
    final rows = [
      ['date', 'action', 'productName', 'category', 'quantity'].map(q).join(','),
      ...filtered.map((e) => [e.date, e.action, e.productName, e.category, e.quantity].map(q).join(',')),
    ];
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/consumption-history.csv');
    await file.writeAsString(rows.join('\n'));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _pickDate(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? hFrom : hTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      from ? hFrom = d : hTo = d;
      applyHistoryFilters();
    });
  }

  Widget _kpi(String label, String value, Color color, String foot) => Expanded(
    child: FsCard(
      padding: const EdgeInsets.all(FsSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: FsColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            foot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: FsColors.textMuted),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final maxWaste = days.isEmpty ? 1 : days.map((d) => d.wasteKg).reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final df = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(FsSpace.s4),
        children: [
          PageHeader(
            eyebrow: context.tr('nav.reports'),
            title: context.tr('reports.title'),
            subtitle: context.tr('reports.subtitle'),
            actions: [
              OutlinedButton.icon(
                onPressed: exportCSV,
                icon: const Icon(Icons.download, size: 18),
                label: Text(context.tr('reports.history.exportCsv')),
              ),
            ],
          ),
          Row(
            children: [
              _kpi(context.tr('reports.kpi.gain'), '+$gainPct%', FsColors.success, context.tr('reports.vsLastWeek')),
              const SizedBox(width: 8),
              _kpi(context.tr('reports.kpi.loss'), '-$lossPct%', FsColors.danger, context.tr('reports.vsLastWeek')),
              const SizedBox(width: 8),
              _kpi(context.tr('reports.kpi.improvement'), '+$improvementPct%', FsColors.success, context.tr('reports.mtd')),
            ],
          ),
          const SizedBox(height: FsSpace.s3),
          FsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('reports.weeklyWaste'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in days)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (d.wasteKg > 0)
                                Text('${d.wasteKg}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Container(
                                height: 4 + 100 * d.wasteKg / maxWaste,
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: d.wasteKg > 0 ? FsColors.warning : FsColors.border,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(d.label, style: const TextStyle(fontSize: 11, color: FsColors.textMuted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FsSpace.s3),
          FsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('reports.trends'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (humidity.isEmpty)
                  EmptyState(icon: Icons.show_chart, title: context.tr('reports.noTrends'))
                else ...[
                  Wrap(
                    spacing: 14,
                    children: [
                      _legend(const Color(0xFFE76F51), context.tr('monitoring.temperature')),
                      _legend(FsColors.info, context.tr('monitoring.humidity')),
                      if (ethylene.isNotEmpty) _legend(FsColors.primary, context.tr('monitoring.ethylene')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Sparkline(temperature, color: const Color(0xFFE76F51), height: 160, min: 0, max: 100),
                      Sparkline(humidity, color: FsColors.info, height: 160, min: 0, max: 100),
                    ],
                  ),
                  if (ethylene.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Sparkline(ethylene, color: FsColors.primary, height: 60),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: FsSpace.s3),
          FsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('reports.history.title'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(true),
                        child: Text('${context.tr('reports.from')}: ${hFrom == null ? '—' : df.format(hFrom!)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(false),
                        child: Text('${context.tr('reports.to')}: ${hTo == null ? '—' : df.format(hTo!)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilterDropdown<String>(
                        label: context.tr('reports.history.action'),
                        value: hAction,
                        items: {
                          '': context.tr('common.all'),
                          'consume': context.tr('reports.history.consume'),
                          'discard': context.tr('reports.history.discard'),
                          'add': context.tr('reports.history.add'),
                        },
                        onChanged: (v) => setState(() {
                          hAction = v;
                          applyHistoryFilters();
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: context.tr('reports.history.category'),
                          hintText: context.tr('reports.history.categoryPlaceholder'),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() {
                          hCategory = v;
                          applyHistoryFilters();
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  EmptyState(icon: Icons.history, title: context.tr('reports.history.empty'))
                else
                  for (final e in filtered)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: (_isAction(e.action, 'discard') ? FsStatus.crit : FsStatus.ok).background,
                        child: Icon(
                          _isAction(e.action, 'discard') ? Icons.delete_outline : Icons.restaurant,
                          color: (_isAction(e.action, 'discard') ? FsStatus.crit : FsStatus.ok).color,
                          size: 20,
                        ),
                      ),
                      title: Text(e.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${e.category} · ${_date(e.date) == null ? e.date : DateFormat('yyyy-MM-dd HH:mm').format(_date(e.date)!)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('×${e.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(e.action, style: const TextStyle(fontSize: 11, color: FsColors.textMuted)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
