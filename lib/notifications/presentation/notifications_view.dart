import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/language_service.dart';
import '../../shared/presentation/components/ui.dart';
import '../../shared/presentation/theme/app_theme.dart';
import '../domain/notification_model.dart';
import '../infrastructure/notifications_api.dart';

/// Equivalente a `notifications/presentation/notifications.view.ts`.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  List<AppNotification> _notifications = [];
  bool loading = true;
  bool error = false;

  List<AppNotification> get unread => _notifications.where((n) => !n.isRead).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<NotificationsApi>().getInbox();
      if (mounted) setState(() => _notifications = data);
    } catch (_) {
      if (mounted) setState(() => error = true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> markAsRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await context.read<NotificationsApi>().markAsRead(n.id);
      if (mounted) {
        setState(() => _notifications = _notifications.map((i) => i.id == n.id ? i.copyWith(isRead: true) : i).toList());
      }
    } catch (_) {}
  }

  void markAllAsRead() {
    for (final n in unread) {
      markAsRead(n);
    }
  }

  String _fmt(String s) {
    final d = DateTime.tryParse(s);
    return d == null ? s : DateFormat('dd/MM/yy HH:mm').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(FsSpace.s4),
      children: [
        PageHeader(
          eyebrow: context.tr('nav.notifications'),
          title: context.tr('notifications.inbox.title'),
          subtitle: context.tr('notifications.inbox.subtitle'),
          actions: [
            if (unread.isNotEmpty)
              TextButton.icon(
                onPressed: markAllAsRead,
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(context.tr('notifications.inbox.markAllRead')),
              ),
          ],
        ),
        if (loading)
          const SkeletonList(count: 4, height: 70)
        else if (_notifications.isEmpty)
          FsCard(
            child: EmptyState(icon: Icons.notifications_none, title: context.tr('notifications.inbox.empty')),
          )
        else
          FsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final n in _notifications)
                  ListTile(
                    onTap: () => markAsRead(n),
                    tileColor: n.isRead ? null : FsColors.primaryLight.withValues(alpha: .5),
                    leading: CircleAvatar(
                      backgroundColor: n.isRead ? FsColors.bg : FsColors.primaryLight,
                      child: Icon(
                        n.isRead ? Icons.mark_email_read_outlined : Icons.mail_outline,
                        color: n.isRead ? FsColors.textMuted : FsColors.primary,
                      ),
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.message),
                        const SizedBox(height: 2),
                        Text(_fmt(n.createdAt), style: const TextStyle(fontSize: 11, color: FsColors.textMuted)),
                      ],
                    ),
                    trailing: n.isRead
                        ? null
                        : IconButton(
                            tooltip: context.tr('notifications.inbox.markRead'),
                            icon: const Icon(Icons.check, color: FsColors.primary),
                            onPressed: () => markAsRead(n),
                          ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
