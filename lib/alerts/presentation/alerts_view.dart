import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/language_service.dart';
import '../../shared/presentation/components/ui.dart';
import '../../shared/presentation/theme/app_theme.dart';
import '../domain/alert_model.dart';
import '../infrastructure/alerts_api.dart';

/// Equivalente a `alerts/presentation/alerts.view.ts`.
class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  List<Alert> _all = [];
  bool loading = true;
  String stateFilter = 'active';
  String sevFilter = 'all';
  String query = '';

  @override
  void initState() {
    super.initState();
    _loadApiAlerts();
  }

  // Solo alertas reales del backend (las genera el job de frescura: vencimiento + sensor).
  Future<void> _loadApiAlerts() async {
    try {
      final data = await context.read<AlertsApi>().getAll();
      if (mounted) setState(() => _all = data);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  List<Alert> get visible {
    final q = query.toLowerCase();
    return _all.where((a) {
      final okState = stateFilter == 'all' || a.state == stateFilter;
      final okSev = sevFilter == 'all' || a.severity == sevFilter;
      final okQ = q.isEmpty || a.title.toLowerCase().contains(q) || a.message.toLowerCase().contains(q);
      return okState && okSev && okQ;
    }).toList();
  }

  void _setState(Alert a, String state) {
    setState(() => a.state = state);
    context.read<AlertsApi>().update(a.id, a).ignore();
  }

  void resolve(Alert a) => _setState(a, 'resolved');
  void mute(Alert a) => _setState(a, 'muted');

  FsStatus sevStatus(String s) => s == 'critical'
      ? FsStatus.crit
      : s == 'warning'
      ? FsStatus.warn
      : FsStatus.ok;

  void open(Alert a) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(FsSpace.s5, 0, FsSpace.s5, FsSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(a.message),
            const Divider(height: 28),
            for (final (k, v) in [
              ('alerts.columns.source', a.source),
              ('alerts.columns.severity', a.severity),
              ('alerts.columns.status', a.state),
              ('alerts.columns.createdAt', a.timeAgo),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(context.tr(k), style: const TextStyle(color: FsColors.textMuted)),
                    ),
                    Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('common.close'))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: a.state == 'resolved'
                        ? null
                        : () {
                            resolve(a);
                            Navigator.pop(ctx);
                          },
                    child: Text(context.tr('alerts.actions.markResolved')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final list = visible;
    return RefreshIndicator(
      onRefresh: _loadApiAlerts,
      child: ListView(
        padding: const EdgeInsets.all(FsSpace.s4),
        children: [
          PageHeader(
            eyebrow: context.tr('nav.alerts'),
            title: context.tr('alerts.title'),
            subtitle: context.tr('alerts.subtitle'),
          ),
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('alerts.searchPlaceholder')),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: FsSpace.s3),
          Row(
            children: [
              Expanded(
                child: FilterDropdown<String>(
                  label: context.tr('alerts.filters.stateLabel'),
                  value: stateFilter,
                  items: {
                    'all': context.tr('alerts.filters.stateAll'),
                    'active': context.tr('alerts.filters.stateActive'),
                    'muted': context.tr('alerts.filters.stateMuted'),
                    'resolved': context.tr('alerts.filters.stateResolved'),
                  },
                  onChanged: (v) => setState(() => stateFilter = v),
                ),
              ),
              const SizedBox(width: FsSpace.s3),
              Expanded(
                child: FilterDropdown<String>(
                  label: context.tr('alerts.filters.severityLabel'),
                  value: sevFilter,
                  items: {
                    'all': context.tr('alerts.filters.severityAll'),
                    'critical': context.tr('alerts.filters.severityCritical'),
                    'warning': context.tr('alerts.filters.severityWarning'),
                    'info': context.tr('alerts.filters.severityInfo'),
                  },
                  onChanged: (v) => setState(() => sevFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: FsSpace.s4),
          if (loading)
            const SkeletonList(count: 3, height: 120)
          else if (list.isEmpty)
            FsCard(
              child: EmptyState(
                icon: Icons.notifications_off_outlined,
                title: context.tr('alerts.empty.title'),
                hint: context.tr('alerts.empty.hint'),
              ),
            )
          else
            for (final a in list)
              Padding(
                padding: const EdgeInsets.only(bottom: FsSpace.s3),
                child: FsCard(
                  onTap: () => open(a),
                  borderColor: a.severity == 'critical' ? FsColors.danger.withValues(alpha: .5) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FsBadge(a.severity, status: sevStatus(a.severity)),
                          const SizedBox(width: 8),
                          Icon(
                            a.source == 'Humidity' ? Icons.water_drop_outlined : Icons.thermostat,
                            size: 16,
                            color: FsColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(a.source, style: const TextStyle(color: FsColors.textMuted, fontSize: 13)),
                          ),
                          Text(a.timeAgo, style: const TextStyle(color: FsColors.textMuted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(a.message, style: const TextStyle(color: FsColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: a.state == 'muted' ? null : () => mute(a),
                            child: Text(context.tr('alerts.actions.mute')),
                          ),
                          const SizedBox(width: 4),
                          FilledButton.tonal(
                            onPressed: a.state == 'resolved' ? null : () => resolve(a),
                            child: Text(context.tr('alerts.actions.resolve')),
                          ),
                        ],
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
