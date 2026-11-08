import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/language_service.dart';
import '../../shared/presentation/components/ui.dart';
import '../../shared/presentation/theme/app_theme.dart';
import '../domain/monitoring_reading_model.dart';
import '../infrastructure/monitoring_api.dart';

/// Cada cuántos segundos se consulta la última lectura (tiempo cuasi real).
const _pollInterval = Duration(seconds: 5);

/// Puntos que guarda cada sparkline.
const _trendMax = 20;

class _MetricCard {
  const _MetricCard({
    required this.id,
    required this.icon,
    required this.value,
    required this.unit,
    required this.status,
    required this.rangeLabel,
    required this.trend,
    required this.color,
  });

  final String id; // temp | hum | gas
  final IconData icon;
  final double value;
  final String unit;
  final FsStatus status;
  final String rangeLabel;
  final List<double> trend;
  final Color color;
}

/// Equivalente a `monitoring/presentation/monitoring.view.ts`, con el gas (etileno)
/// y refresco automático cada 5 s.
class MonitoringView extends StatefulWidget {
  const MonitoringView({super.key});

  @override
  State<MonitoringView> createState() => _MonitoringViewState();
}

class _MonitoringViewState extends State<MonitoringView> {
  bool loading = true;
  bool noData = false;
  bool exporting = false;
  MonitoringReading? latest;
  int? _lastReadingId;
  final Map<String, List<double>> _trends = {'temp': [], 'hum': [], 'gas': []};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    MonitoringReading? data;
    try {
      data = await context.read<MonitoringApi>().getLatest();
    } catch (_) {
      // Sin respuesta: se mantiene el último valor.
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      if (data == null) {
        if (latest == null) noData = true;
        return;
      }
      noData = false;
      if (data.id != _lastReadingId) {
        _push('temp', data.temperature);
        _push('hum', data.humidity);
        if (data.ethyleneLevel != null) _push('gas', data.ethyleneLevel!);
      }
      _lastReadingId = data.id;
      latest = data;
    });
  }

  void _push(String id, double v) {
    final arr = _trends[id]!..add(v);
    if (arr.length > _trendMax) arr.removeAt(0);
  }

  FsStatus classifyTemp(double v) => v >= 8
      ? FsStatus.crit
      : v >= 6
      ? FsStatus.warn
      : FsStatus.ok;

  FsStatus classifyHumidity(double v) {
    if (v > 90 || v < 50) return FsStatus.crit;
    if (v > 80 || v < 60) return FsStatus.warn;
    return FsStatus.ok;
  }

  /// Los umbrales de etileno viven en el Edge (por categoría): se usa su semáforo.
  FsStatus statusFromEdge(String? s) => s == 'RED'
      ? FsStatus.crit
      : s == 'YELLOW'
      ? FsStatus.warn
      : FsStatus.ok;

  List<_MetricCard> get metrics {
    final d = latest;
    if (d == null) return [];
    return [
      _MetricCard(
        id: 'temp',
        icon: Icons.thermostat,
        value: d.temperature,
        unit: '°C',
        status: classifyTemp(d.temperature),
        rangeLabel: '0 – 6 °C',
        trend: [..._trends['temp']!],
        color: const Color(0xFFE76F51),
      ),
      _MetricCard(
        id: 'hum',
        icon: Icons.water_drop_outlined,
        value: d.humidity,
        unit: '%',
        status: classifyHumidity(d.humidity),
        rangeLabel: '60 – 80 %',
        trend: [..._trends['hum']!],
        color: FsColors.info,
      ),
      if (d.ethyleneLevel != null)
        _MetricCard(
          id: 'gas',
          icon: Icons.air,
          value: d.ethyleneLevel!,
          unit: 'ppm',
          status: statusFromEdge(d.status),
          rangeLabel: d.category != null ? 'Edge · ${d.category}' : 'Edge',
          trend: [..._trends['gas']!],
          color: FsColors.primary,
        ),
    ];
  }

  FsStatus get overallStatus {
    final s = metrics.map((m) => m.status);
    if (s.contains(FsStatus.crit)) return FsStatus.crit;
    if (s.contains(FsStatus.warn)) return FsStatus.warn;
    return FsStatus.ok;
  }

  int get lastSyncMinutes {
    final d = DateTime.tryParse(latest?.recordedAt ?? '');
    if (d == null) return 0;
    final diff = DateTime.now().difference(d.isUtc ? d.toLocal() : d).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  String get lastReadingDate {
    final d = DateTime.tryParse(latest?.recordedAt ?? '');
    return d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  String titleKey(String id) => id == 'temp'
      ? 'monitoring.temperature'
      : id == 'hum'
      ? 'monitoring.humidity'
      : 'monitoring.ethylene';

  String freshnessLabel(String? status) => switch (status) {
    'GREEN' => 'monitoring.freshness.green',
    'YELLOW' => 'monitoring.freshness.yellow',
    'RED' => 'monitoring.freshness.red',
    _ => 'monitoring.freshness.unknown',
  };

  /// Exporta el historial como CSV y lo comparte (en el web se descargaba).
  Future<void> exportCsv() async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final rows = await context.read<MonitoringApi>().getAll();
      String esc(Object? v) {
        final s = v?.toString() ?? '';
        return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
      }

      final lines = [
        'recordedAt,temperature,humidity,ethyleneLevel,status,category',
        ...rows.map((r) => [r.recordedAt, r.temperature, r.humidity, r.ethyleneLevel, r.status, r.category].map(esc).join(',')),
      ];
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/freshsense-monitoreo-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv');
      await file.writeAsString(lines.join('\n'));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  void openLast() {
    final r = latest;
    if (r == null) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget row(String k, Widget v) => ListTile(dense: true, title: Text(context.tr(k)), trailing: v);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('monitoring.viewLast'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              row('monitoring.temperature', Text('${r.temperature} °C')),
              row('monitoring.humidity', Text('${r.humidity} %')),
              if (r.ethyleneLevel != null) row('monitoring.ethylene', Text('${r.ethyleneLevel} ppm')),
              row('monitoring.detail.freshness', FsBadge(context.tr(freshnessLabel(r.status)), status: statusFromEdge(r.status))),
              if (r.category != null) row('monitoring.detail.category', Text(r.category!)),
              row('monitoring.detail.recordedAt', Text(lastReadingDate)),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = metrics;
    return RefreshIndicator(
      onRefresh: _poll,
      child: ListView(
        padding: const EdgeInsets.all(FsSpace.s4),
        children: [
          PageHeader(
            eyebrow: context.tr('nav.monitoring'),
            title: context.tr('monitoring.title'),
            subtitle: context.tr('monitoring.subtitle'),
            actions: [
              OutlinedButton.icon(
                onPressed: exporting ? null : exportCsv,
                icon: const Icon(Icons.download, size: 18),
                label: Text(context.tr('monitoring.exportCsv')),
              ),
            ],
          ),
          if (loading)
            const SkeletonList(count: 3, height: 140)
          else if (noData)
            FsCard(
              child: EmptyState(icon: Icons.sensors_off, title: context.tr('monitoring.empty')),
            )
          else ...[
            // Barra de estado
            FsCard(
              color: overallStatus.background,
              child: Row(
                children: [
                  StatusDot(overallStatus, size: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(overallStatus == FsStatus.ok ? 'monitoring.status.healthy' : 'monitoring.status.offline'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          context.tr('monitoring.lastSync', {'minutes': lastSyncMinutes}),
                          style: const TextStyle(color: FsColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.autorenew, size: 16, color: FsColors.textMuted),
                  const Text(' 5 s', style: TextStyle(color: FsColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: FsSpace.s3),
            for (final m in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: FsSpace.s3),
                child: FsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: m.color.withValues(alpha: .12),
                            child: Icon(m.icon, color: m.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.tr(titleKey(m.id)), style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${context.tr('monitoring.card.healthyRange')}: ${m.rangeLabel}',
                                  style: const TextStyle(color: FsColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          FsBadge(context.tr('home.sensor.${m.status.name}'), status: m.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: m.value.toStringAsFixed(m.id == 'gas' ? 2 : 1),
                              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: ' ${m.unit}',
                              style: const TextStyle(fontSize: 16, color: FsColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Sparkline(m.trend, color: m.color),
                    ],
                  ),
                ),
              ),
            FsCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('monitoring.history.title'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(lastReadingDate, style: const TextStyle(color: FsColors.textMuted)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: openLast,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(context.tr('monitoring.viewLast')),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
