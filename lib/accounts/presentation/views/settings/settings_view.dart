import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/i18n/language_service.dart';
import '../../../../notifications/infrastructure/notifications_api.dart';
import '../../../../shared/application/toast_service.dart';
import '../../../../shared/presentation/components/ui.dart';
import '../../../../shared/presentation/theme/app_theme.dart';
import '../../../application/accounts_store.dart';
import '../../../application/integrations_service.dart';

const _prefsKey = 'fs.prefs';
const _notifyPrefsKey = 'fs.notify.prefs';

const _tabs = [
  ('profile', Icons.person_outline),
  ('preferences', Icons.tune),
  ('theme', Icons.palette_outlined),
  ('notifications', Icons.notifications_outlined),
  ('security', Icons.lock_outline),
  ('integrations', Icons.hub_outlined),
];

// US24: preferencias granulares de notificación.
const _notifyKeys = ['inventory.low', 'inventory.expiring', 'recipes.new'];
const _channels = ['inapp', 'push', 'email'];
Map<String, Map<String, dynamic>> _defaultNotify() => {
  'inventory.low': {
    'enabled': true,
    'channels': ['inapp'],
  },
  'inventory.expiring': {
    'enabled': true,
    'channels': ['inapp', 'push'],
  },
  'recipes.new': {
    'enabled': false,
    'channels': ['inapp'],
  },
};

/// Equivalente a `accounts/presentation/views/settings/settings.view.ts`.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final SharedPreferences _prefs = context.read<SharedPreferences>();
  late final ToastService _toast = context.read<ToastService>();

  bool dirty = false;
  void markDirty() => setState(() => dirty = true);

  // Perfil
  final _name = TextEditingController();
  String email = '';
  final _phone = TextEditingController(text: '+51 999 999 999');
  final _org = TextEditingController(text: 'FreshSense Labs');
  bool profileSubmitting = false;

  // Preferencias
  Map<String, String> prefs = {
    'language': 'es',
    'timezone': 'America/Lima',
    'units': 'metric',
    'dateFormat': 'DD/MM/YYYY',
    'weekStartsOn': 'mon',
  };
  static const timezones = ['America/Lima', 'America/Mexico_City', 'America/Bogota', 'UTC'];

  // Tema
  String themeMode = 'system';
  bool rounded = true;
  String density = 'comfortable';

  // Notificaciones básicas
  bool notifEmail = true;
  bool notifPush = false;
  bool weeklyReport = true;
  bool criticalOnly = true;
  double humidityThreshold = 80;
  double tempThreshold = 6;
  late Map<String, Map<String, dynamic>> notifyPrefs = _loadNotifyPrefs();

  // Seguridad
  final _pwCurrent = TextEditingController();
  final _pwNew = TextEditingController();
  bool pwSubmitting = false;
  bool twoFA = false;
  List<String> sessions = ['current'];

  // Integraciones
  final integrations = [
    {'key': 'google', 'name': 'Google', 'connected': false, 'note': 'Calendar & Drive export'},
    {'key': 'slack', 'name': 'Slack', 'connected': false, 'note': '#freshsense channel'},
    {'key': 'zapier', 'name': 'Zapier', 'connected': false},
    {'key': 'webhooks', 'name': 'Webhooks', 'connected': false},
  ];
  static const providers = [(1, 'Samsung SmartThings'), (2, 'LG ThinQ')];
  DateTime? lastSync;
  int importedCount = -1;

  @override
  void initState() {
    super.initState();
    final current = context.read<AccountStore>().getCurrentUser();
    _name.text = current?.fullName ?? '';
    email = current?.email ?? '';

    // Preferencias de notificación reales desde el backend.
    context
        .read<NotificationsApi>()
        .getPreferences()
        .then((p) {
          if (mounted) {
            setState(() {
              notifEmail = p.emailEnabled;
              notifPush = p.pushEnabled;
            });
          }
        })
        .catchError((_) {});

    // Preferencias locales desde el dispositivo.
    try {
      final raw = _prefs.getString(_prefsKey);
      if (raw != null) prefs.addAll(Map<String, String>.from(jsonDecode(raw) as Map));
    } catch (_) {}
    prefs['language'] = context.read<LanguageService>().current;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _org, _pwCurrent, _pwNew]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Map<String, dynamic>> _loadNotifyPrefs() {
    final merged = _defaultNotify();
    try {
      final raw = context.read<SharedPreferences>().getString(_notifyPrefsKey);
      if (raw != null) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        for (final k in merged.keys) {
          if (saved[k] is Map) merged[k] = Map<String, dynamic>.from(saved[k] as Map);
        }
      }
    } catch (_) {}
    return merged;
  }

  void _persistNotificationPrefs() => context
      .read<NotificationsApi>()
      .updatePreferences(NotificationPreference(inAppEnabled: true, emailEnabled: notifEmail, pushEnabled: notifPush))
      .ignore();

  Future<void> saveProfile() async {
    final name = _name.text.trim();
    if (name.isEmpty) return _toast.warning(context.trNow('settings.profile.name'));
    setState(() => profileSubmitting = true);
    final res = await context.read<AccountStore>().updateProfile(name);
    if (!mounted) return;
    setState(() => profileSubmitting = false);
    if (res.ok) {
      setState(() => dirty = false);
      _toast.success(context.trNow('settings.profile.save'));
    } else {
      _toast.error(res.message ?? context.trNow('settings.profile.saveError'));
    }
  }

  void setPref(String k, String v) {
    setState(() => prefs[k] = v);
    if (k == 'language') context.read<LanguageService>().use(v);
    markDirty();
  }

  void savePrefs() {
    _prefs.setString(_prefsKey, jsonEncode(prefs));
    _prefs.setString(_notifyPrefsKey, jsonEncode(notifyPrefs));
    _persistNotificationPrefs();
    setState(() => dirty = false);
    _toast.success(context.trNow('settings.preferences.save'));
  }

  void saveAll() {
    _prefs.setString(_notifyPrefsKey, jsonEncode(notifyPrefs));
    _persistNotificationPrefs();
    setState(() => dirty = false);
    _toast.success(context.trNow('settings.saveAll'));
  }

  Future<void> changePassword() async {
    final current = _pwCurrent.text.trim();
    final next = _pwNew.text.trim();
    if (current.isEmpty || next.isEmpty) return _toast.warning(context.trNow('settings.security.passwordRequired'));
    if (next.length < 8 || !RegExp('[A-Z]').hasMatch(next) || !RegExp(r'\d').hasMatch(next)) {
      return _toast.warning(context.trNow('settings.security.passwordWeak'));
    }
    setState(() => pwSubmitting = true);
    final res = await context.read<AccountStore>().changePassword(current, next);
    if (!mounted) return;
    setState(() => pwSubmitting = false);
    if (res.ok) {
      _pwCurrent.clear();
      _pwNew.clear();
      _toast.success(context.trNow('settings.security.passwordChanged'));
    } else {
      _toast.error(res.message ?? context.trNow('settings.security.passwordError'));
    }
  }

  // ---------- UI ----------
  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: FsSpace.s3),
    child: FsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _gap() => const SizedBox(height: 12);

  Widget _profile() => _section(context.tr('settings.profile.title'), [
    Center(
      child: CircleAvatar(
        radius: 36,
        backgroundColor: FsColors.primaryLight,
        child: Text(
          _name.text.isEmpty ? '?' : _name.text[0].toUpperCase(),
          style: const TextStyle(fontSize: 28, color: FsColors.primaryDark, fontWeight: FontWeight.w800),
        ),
      ),
    ),
    _gap(),
    TextField(
      controller: _name,
      decoration: InputDecoration(labelText: context.tr('settings.profile.name')),
      onChanged: (_) => markDirty(),
    ),
    _gap(),
    TextField(
      enabled: false,
      controller: TextEditingController(text: email),
      decoration: InputDecoration(labelText: context.tr('settings.profile.email')),
    ),
    _gap(),
    TextField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(labelText: context.tr('settings.profile.phone')),
      onChanged: (_) => markDirty(),
    ),
    _gap(),
    TextField(
      controller: _org,
      decoration: InputDecoration(labelText: context.tr('settings.profile.organization')),
      onChanged: (_) => markDirty(),
    ),
    _gap(),
    FilledButton(onPressed: profileSubmitting ? null : saveProfile, child: Text(context.tr('settings.profile.save'))),
  ]);

  Widget _preferences() => _section(context.tr('settings.preferences.title'), [
    FilterDropdown<String>(
      label: context.tr('settings.preferences.language'),
      value: prefs['language']!,
      items: const {'es': 'Español', 'en': 'English'},
      onChanged: (v) => setPref('language', v),
    ),
    _gap(),
    FilterDropdown<String>(
      label: context.tr('settings.preferences.timezone'),
      value: timezones.contains(prefs['timezone']) ? prefs['timezone']! : timezones.first,
      items: {for (final t in timezones) t: t},
      onChanged: (v) => setPref('timezone', v),
    ),
    _gap(),
    FilterDropdown<String>(
      label: context.tr('settings.preferences.units'),
      value: prefs['units']!,
      items: {
        'metric': context.tr('settings.preferences.unitsMetric'),
        'imperial': context.tr('settings.preferences.unitsImperial'),
      },
      onChanged: (v) => setPref('units', v),
    ),
    _gap(),
    FilterDropdown<String>(
      label: context.tr('settings.preferences.dateFormat'),
      value: prefs['dateFormat']!,
      items: const {'DD/MM/YYYY': 'DD/MM/YYYY', 'MM/DD/YYYY': 'MM/DD/YYYY', 'YYYY-MM-DD': 'YYYY-MM-DD'},
      onChanged: (v) => setPref('dateFormat', v),
    ),
    _gap(),
    FilterDropdown<String>(
      label: context.tr('settings.preferences.weekStartsOn'),
      value: prefs['weekStartsOn']!,
      items: {'mon': context.tr('settings.preferences.monday'), 'sun': context.tr('settings.preferences.sunday')},
      onChanged: (v) => setPref('weekStartsOn', v),
    ),
    _gap(),
    FilledButton(onPressed: savePrefs, child: Text(context.tr('settings.preferences.save'))),
  ]);

  Widget _theme() => _section(context.tr('settings.theme.title'), [
    SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'light', label: Text(context.tr('settings.theme.modeLight'))),
        ButtonSegment(value: 'dark', label: Text(context.tr('settings.theme.modeDark'))),
        ButtonSegment(value: 'system', label: Text(context.tr('settings.theme.modeSystem'))),
      ],
      selected: {themeMode},
      onSelectionChanged: (s) {
        setState(() => themeMode = s.first);
        markDirty();
      },
    ),
    _gap(),
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('settings.theme.primaryColor')),
      trailing: const CircleAvatar(radius: 12, backgroundColor: FsColors.primary),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('settings.theme.rounded')),
      value: rounded,
      onChanged: (v) {
        setState(() => rounded = v);
        markDirty();
      },
    ),
    FilterDropdown<String>(
      label: context.tr('settings.theme.density'),
      value: density,
      items: {
        'comfortable': context.tr('settings.theme.densityComfortable'),
        'compact': context.tr('settings.theme.densityCompact'),
      },
      onChanged: (v) {
        setState(() => density = v);
        markDirty();
      },
    ),
    _gap(),
    FilledButton(
      onPressed: () => _toast.success(context.trNow('settings.theme.apply')),
      child: Text(context.tr('settings.theme.apply')),
    ),
  ]);

  Widget _notifications() => Column(
    children: [
      _section(context.tr('settings.notifications.title'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('settings.notifications.email')),
          value: notifEmail,
          onChanged: (v) {
            setState(() => notifEmail = v);
            markDirty();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('settings.notifications.push')),
          value: notifPush,
          onChanged: (v) {
            setState(() => notifPush = v);
            markDirty();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('settings.notifications.weeklyReport')),
          value: weeklyReport,
          onChanged: (v) {
            setState(() => weeklyReport = v);
            markDirty();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('settings.notifications.criticalOnly')),
          value: criticalOnly,
          onChanged: (v) {
            setState(() => criticalOnly = v);
            markDirty();
          },
        ),
        Text('${context.tr('settings.notifications.humidityThreshold')}: ${humidityThreshold.round()}'),
        Slider(
          value: humidityThreshold,
          min: 40,
          max: 100,
          divisions: 60,
          onChanged: (v) {
            setState(() => humidityThreshold = v);
            markDirty();
          },
        ),
        Text('${context.tr('settings.notifications.temperatureThreshold')}: ${tempThreshold.round()}'),
        Slider(
          value: tempThreshold,
          min: 0,
          max: 15,
          divisions: 15,
          onChanged: (v) {
            setState(() => tempThreshold = v);
            markDirty();
          },
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  notifEmail = true;
                  notifPush = false;
                  weeklyReport = true;
                  criticalOnly = true;
                  humidityThreshold = 80;
                  tempThreshold = 6;
                }),
                child: Text(context.tr('settings.notifications.reset')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: saveAll, child: Text(context.tr('settings.notifications.save'))),
            ),
          ],
        ),
      ]),
      _section(context.tr('settings.notify.title'), [
        Text(context.tr('settings.notify.desc'), style: const TextStyle(color: FsColors.textMuted)),
        for (final k in _notifyKeys) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('settings.notify.keys.$k')),
            value: notifyPrefs[k]!['enabled'] as bool,
            onChanged: (v) {
              setState(() => notifyPrefs[k]!['enabled'] = v);
              markDirty();
            },
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final ch in _channels)
                FilterChip(
                  label: Text(ch),
                  selected: (notifyPrefs[k]!['channels'] as List).contains(ch),
                  onSelected: (sel) {
                    setState(() {
                      final list = List<String>.from(notifyPrefs[k]!['channels'] as List);
                      sel ? list.add(ch) : list.remove(ch);
                      notifyPrefs[k]!['channels'] = list.toSet().toList();
                    });
                    markDirty();
                  },
                ),
            ],
          ),
          const Divider(),
        ],
        OutlinedButton.icon(
          onPressed: () => _toast.info('FreshSense: Test notification sent successfully.'),
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(context.tr('settings.notify.test')),
        ),
      ]),
    ],
  );

  Widget _security() => _section(context.tr('settings.security.title'), [
    Text(context.tr('settings.security.password'), style: const TextStyle(fontWeight: FontWeight.w700)),
    Text(context.tr('settings.security.passwordHint'), style: const TextStyle(color: FsColors.textMuted)),
    _gap(),
    TextField(
      controller: _pwCurrent,
      obscureText: true,
      decoration: InputDecoration(labelText: context.tr('settings.security.currentPassword')),
    ),
    _gap(),
    TextField(
      controller: _pwNew,
      obscureText: true,
      decoration: InputDecoration(labelText: context.tr('settings.security.newPassword')),
    ),
    _gap(),
    FilledButton(onPressed: pwSubmitting ? null : changePassword, child: Text(context.tr('settings.security.changePassword'))),
    const Divider(height: 32),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('settings.security.twoFactor')),
      subtitle: Text(context.tr('settings.security.twoFactorHint')),
      value: twoFA,
      onChanged: (v) => setState(() => twoFA = v),
    ),
    const Divider(height: 24),
    Text(context.tr('settings.security.activeSessions'), style: const TextStyle(fontWeight: FontWeight.w700)),
    for (final (i, _) in sessions.indexed)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.phone_android),
        title: Text(prefs['language'] == 'en' ? 'This session' : 'Esta sesión'),
        subtitle: Text(prefs['language'] == 'en' ? 'Now' : 'Ahora'),
        trailing: i == 0 ? FsBadge(context.tr('settings.security.current'), status: FsStatus.ok) : null,
      ),
  ]);

  Widget _integrations() {
    final svc = context.read<IntegrationsService>();
    return Column(
      children: [
        _section(context.tr('settings.integrations.title'), [
          for (final i in integrations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.extension_outlined),
              title: Text(i['name'] as String),
              subtitle: i['note'] == null ? null : Text(i['note'] as String),
              trailing: OutlinedButton(
                onPressed: () => setState(() => i['connected'] = !(i['connected'] as bool)),
                child: Text(
                  context.tr((i['connected'] as bool) ? 'settings.integrations.disconnect' : 'settings.integrations.connect'),
                ),
              ),
            ),
        ]),
        _section(context.tr('settings.integrations.smartFridges.title'), [
          Text(context.tr('settings.integrations.smartFridges.desc'), style: const TextStyle(color: FsColors.textMuted)),
          for (final (id, name) in providers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.kitchen_outlined),
              title: Text(name),
              trailing: OutlinedButton(
                onPressed: () async {
                  await svc.toggle(id, svc.getStatus(id) == 'connected' ? 'disconnected' : 'connected');
                  setState(() {});
                },
                child: Text(
                  context.tr(
                    svc.getStatus(id) == 'connected' ? 'settings.integrations.disconnect' : 'settings.integrations.connect',
                  ),
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: () => setState(() {
              importedCount = 2; // simulado, igual que el respaldo del web
              lastSync = DateTime.now();
            }),
            icon: const Icon(Icons.sync),
            label: Text(context.tr('settings.integrations.smartFridges.sync')),
          ),
          if (lastSync != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${context.tr('settings.integrations.smartFridges.lastSync')}: ${DateFormat('dd/MM/yyyy HH:mm').format(lastSync!)} · $importedCount ${context.tr('settings.integrations.smartFridges.items')}',
                style: const TextStyle(color: FsColors.textMuted),
              ),
            ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodies = [_profile, _preferences, _theme, _notifications, _security, _integrations];
    return DefaultTabController(
      length: _tabs.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(FsSpace.s4, FsSpace.s4, FsSpace.s4, 0),
            child: PageHeader(title: context.tr('settings.title'), subtitle: context.tr('settings.subtitle')),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: FsColors.primaryDark,
            indicatorColor: FsColors.primary,
            tabs: [for (final (k, icon) in _tabs) Tab(icon: Icon(icon, size: 20), text: context.tr('settings.tabs.$k'))],
          ),
          if (dirty)
            MaterialBanner(
              backgroundColor: FsColors.warningBg,
              content: Text(context.tr('settings.unsaved')),
              actions: [TextButton(onPressed: saveAll, child: Text(context.tr('settings.saveAll')))],
            ),
          Expanded(
            child: TabBarView(
              children: [
                for (final b in bodies) ListView(padding: const EdgeInsets.all(FsSpace.s4), children: [b()]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
