import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../accounts/application/accounts_store.dart';
import '../../../../alerts/domain/alert_model.dart';
import '../../../../alerts/infrastructure/alerts_api.dart';
import '../../../../core/i18n/language_service.dart';
import '../../../../inventory/infrastructure/inventory_api.dart';
import '../../../../monitoring/domain/monitoring_reading_model.dart';
import '../../../../monitoring/infrastructure/monitoring_api.dart';
import '../../components/ui.dart';
import '../../theme/app_theme.dart';

/// Equivalente a `shared/presentation/view/home/home.view.ts`.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  String name = '';
  bool loading = true;
  int totalProducts = 0;
  int freshnessScore = 0;
  List<Alert> _alerts = [];
  MonitoringReading? sensorData;

  // El backend usa ACTIVE/WARNING/CRITICAL; el modelo ya lo normaliza a minúsculas.
  List<Alert> get activeAlerts => _alerts.where((a) => a.state == 'active').toList();
  int get criticalCount => activeAlerts.where((a) => a.severity == 'critical').length;
  List<Alert> get recentAlerts => activeAlerts.take(4).toList();

  FsStatus get tempStatus => _classifyLinear(sensorData?.temperature, 6, 8);
  FsStatus get humidityStatus => _classifyHumidity(sensorData?.humidity);

  @override
  void initState() {
    super.initState();
    name = context.read<AccountStore>().getCurrentUser()?.fullName ?? 'Guest';
    _load();
  }

  Future<void> _load() => Future.wait([_loadInventory(), _loadAlerts(), _loadMonitoring()]);

  Future<void> _loadInventory() async {
    try {
      final products = await context.read<InventoryApi>().getProducts();
      if (mounted) setState(() => totalProducts = products.length);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadAlerts() async {
    try {
      final a = await context.read<AlertsApi>().getAll();
      if (mounted) setState(() => _alerts = a);
    } catch (_) {}
  }

  Future<void> _loadMonitoring() async {
    try {
      final d = await context.read<MonitoringApi>().getLatest();
      if (mounted) {
        setState(() {
          sensorData = d;
          _recomputeFreshness();
        });
      }
    } catch (_) {}
  }

  /// Puntaje 0–100 derivado de los sensores: ok=100, warn=60, crit=20.
  void _recomputeFreshness() {
    final statuses = [tempStatus, humidityStatus].where((s) => s != FsStatus.off).toList();
    if (statuses.isEmpty) {
      freshnessScore = 0;
      return;
    }
    int score(FsStatus s) => s == FsStatus.ok
        ? 100
        : s == FsStatus.warn
        ? 60
        : 20;
    freshnessScore = (statuses.map(score).reduce((a, b) => a + b) / statuses.length).round();
  }

  FsStatus _classifyLinear(double? val, double warn, double crit) {
    if (val == null) return FsStatus.off;
    if (val >= crit) return FsStatus.crit;
    if (val >= warn) return FsStatus.warn;
    return FsStatus.ok;
  }

  FsStatus _classifyHumidity(double? val) {
    if (val == null) return FsStatus.off;
    if (val > 90 || val < 50) return FsStatus.crit;
    if (val > 80 || val < 60) return FsStatus.warn;
    return FsStatus.ok;
  }

  String scoreVerdict() {
    if (totalProducts == 0) return 'home.scoreVerdict.empty';
    if (freshnessScore >= 70) return 'home.scoreVerdict.good';
    if (freshnessScore >= 40) return 'home.scoreVerdict.attention';
    return 'home.scoreVerdict.review';
  }

  FsStatus get scoreStatus {
    if (totalProducts == 0) return FsStatus.off;
    if (freshnessScore >= 70) return FsStatus.ok;
    if (freshnessScore >= 40) return FsStatus.warn;
    return FsStatus.crit;
  }

  String fmt(double? val, [int decimals = 1]) => val == null ? '—' : val.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>().current;
    final today = DateFormat.MMMMEEEEd(lang).format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(FsSpace.s4),
        children: [
          PageHeader(eyebrow: today, title: context.tr('home.heroTitle', {'name': name}), subtitle: context.tr('home.subtitle')),
          // Puntaje de frescura
          FsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('home.freshness'),
                  style: const TextStyle(color: FsColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (loading)
                  const Skeleton(height: 48, width: 120)
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$freshnessScore', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
                      const Text('/100', style: TextStyle(color: FsColors.textMuted, fontSize: 16)),
                      const Spacer(),
                      FsBadge(context.tr(scoreVerdict()), status: scoreStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: freshnessScore / 100,
                      minHeight: 8,
                      color: scoreStatus.color,
                      backgroundColor: FsColors.border,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: FsSpace.s3),
          // KPIs
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: FsSpace.s3,
            crossAxisSpacing: FsSpace.s3,
            childAspectRatio: 1.45,
            children: [
              _Kpi(icon: Icons.inventory_2_outlined, value: '$totalProducts', label: context.tr('home.kpi.products')),
              _Kpi(
                icon: Icons.warning_amber_rounded,
                value: '${activeAlerts.length}',
                label: context.tr('home.kpi.activeAlerts'),
                sub: criticalCount > 0 ? '$criticalCount ${context.tr('home.kpi.critical')}' : null,
                status: criticalCount > 0 ? FsStatus.crit : null,
              ),
              _Kpi(
                icon: Icons.thermostat,
                value: '${fmt(sensorData?.temperature)}°C',
                label: context.tr('home.kpi.temperature'),
                sub: context.tr('home.sensor.${tempStatus.name}'),
                status: tempStatus,
              ),
              _Kpi(
                icon: Icons.water_drop_outlined,
                value: '${fmt(sensorData?.humidity, 0)}%',
                label: context.tr('home.kpi.humidity'),
                sub: context.tr('home.sensor.${humidityStatus.name}'),
                status: humidityStatus,
              ),
            ],
          ),
          const SizedBox(height: FsSpace.s3),
          // Sensores en vivo
          FsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BlockHead(title: context.tr('home.sensor.title'), onViewAll: () => context.go('/monitoring')),
                Text(context.tr('home.sensor.subtitle'), style: const TextStyle(color: FsColors.textMuted, fontSize: 13)),
                const SizedBox(height: 8),
                _SensorRow(
                  Icons.thermostat,
                  context.tr('home.sensor.temperature'),
                  '${fmt(sensorData?.temperature)} °C',
                  tempStatus,
                ),
                _SensorRow(
                  Icons.water_drop_outlined,
                  context.tr('home.sensor.humidity'),
                  '${fmt(sensorData?.humidity, 0)} %',
                  humidityStatus,
                ),
                if (sensorData?.ethyleneLevel != null)
                  _SensorRow(
                    Icons.air,
                    context.tr('monitoring.ethylene'),
                    '${fmt(sensorData?.ethyleneLevel, 2)} ppm',
                    FsStatus.ok,
                  ),
              ],
            ),
          ),
          const SizedBox(height: FsSpace.s3),
          // Alertas recientes
          FsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BlockHead(title: context.tr('home.alerts.recent'), onViewAll: () => context.go('/alerts')),
                if (recentAlerts.isEmpty)
                  EmptyState(icon: Icons.check_circle_outline, title: context.tr('home.alerts.none'))
                else
                  for (final a in recentAlerts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: StatusDot(
                        a.severity == 'critical'
                            ? FsStatus.crit
                            : a.severity == 'warning'
                            ? FsStatus.warn
                            : FsStatus.ok,
                      ),
                      minLeadingWidth: 12,
                      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${a.source} · ${a.timeAgo}'),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockHead extends StatelessWidget {
  const _BlockHead({required this.title, required this.onViewAll});
  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      TextButton(onPressed: onViewAll, child: Text(context.tr('home.alerts.viewAll'))),
    ],
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.value, required this.label, this.sub, this.status});
  final IconData icon;
  final String value;
  final String label;
  final String? sub;
  final FsStatus? status;

  @override
  Widget build(BuildContext context) => FsCard(
    padding: const EdgeInsets.all(FsSpace.s3),
    borderColor: status == FsStatus.crit ? FsColors.danger : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: status?.color ?? FsColors.primary),
        FittedBox(
          child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: FsColors.textSecondary, fontSize: 12),
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: status?.color ?? FsColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
          ),
      ],
    ),
  );
}

class _SensorRow extends StatelessWidget {
  const _SensorRow(this.icon, this.name, this.value, this.status);
  final IconData icon;
  final String name;
  final String value;
  final FsStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: FsColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(name)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        StatusDot(status),
      ],
    ),
  );
}
