import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../accounts/application/accounts_store.dart';
import '../../../../core/i18n/language_service.dart';
import '../../theme/app_theme.dart';

class _NavItem {
  const _NavItem(this.path, this.labelKey, this.icon);
  final String path;
  final String labelKey;
  final IconData icon;
}

/// Mismas secciones y rutas que el sidebar de `layout.html`.
const _sections = <String, List<_NavItem>>{
  'nav.sections.overview': [_NavItem('/dashboard', 'nav.dashboard', Icons.space_dashboard_outlined)],
  'nav.sections.operations': [
    _NavItem('/inventory', 'nav.inventory', Icons.inventory_2_outlined),
    _NavItem('/monitoring', 'nav.monitoring', Icons.sensors),
    _NavItem('/devices', 'nav.devices', Icons.router_outlined),
    _NavItem('/alerts', 'nav.alerts', Icons.warning_amber_rounded),
    _NavItem('/recipes', 'nav.recipes', Icons.menu_book_outlined),
    _NavItem('/reports', 'nav.reports', Icons.bar_chart),
  ],
  'nav.sections.engagement': [_NavItem('/notifications', 'nav.notifications', Icons.notifications_outlined)],
  'nav.sections.account': [_NavItem('/settings', 'nav.settings', Icons.settings_outlined)],
};

/// Accesos directos de la barra inferior (UX móvil); el resto va en el menú lateral.
const _bottom = [
  _NavItem('/dashboard', 'nav.dashboard', Icons.space_dashboard_outlined),
  _NavItem('/inventory', 'nav.inventory', Icons.inventory_2_outlined),
  _NavItem('/monitoring', 'nav.monitoring', Icons.sensors),
  _NavItem('/alerts', 'nav.alerts', Icons.warning_amber_rounded),
];

/// Equivalente a `shared/presentation/components/layout/layout.ts`:
/// topbar con marca e idioma, menú con secciones y salida de sesión.
class LayoutComponent extends StatelessWidget {
  LayoutComponent({super.key, required this.child, required this.location});

  final Widget child;
  final String location;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _titleKey() {
    for (final items in _sections.values) {
      for (final i in items) {
        if (location.startsWith(i.path)) return i.labelKey;
      }
    }
    return 'app.brand';
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AccountStore>().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final bottomIndex = _bottom.indexWhere((i) => location.startsWith(i.path));

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.eco, color: FsColors.primary),
            const SizedBox(width: 8),
            Flexible(child: Text(context.tr(_titleKey()), overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('nav.notifications'),
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go('/notifications'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: lang.toggle,
              child: Text(lang.current.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: FsColors.primary,
                  child: Icon(Icons.eco, color: Colors.white),
                ),
                title: Text(context.tr('app.brand'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                subtitle: Text(context.read<AccountStore>().getCurrentUser()?.email ?? ''),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in _sections.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Text(
                          context.tr(entry.key).toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: FsColors.textMuted),
                        ),
                      ),
                      for (final item in entry.value)
                        ListTile(
                          leading: Icon(item.icon),
                          title: Text(context.tr(item.labelKey)),
                          selected: location.startsWith(item.path),
                          selectedColor: FsColors.primaryDark,
                          selectedTileColor: FsColors.primaryLight,
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go(item.path);
                          },
                        ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: FsColors.danger),
                title: Text(context.tr('app.logout'), style: const TextStyle(color: FsColors.danger)),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex < 0 ? _bottom.length : bottomIndex,
        onDestinationSelected: (i) => i == _bottom.length ? _scaffoldKey.currentState?.openDrawer() : context.go(_bottom[i].path),
        destinations: [
          for (final item in _bottom) NavigationDestination(icon: Icon(item.icon), label: context.tr(item.labelKey)),
          NavigationDestination(icon: const Icon(Icons.menu), label: lang.current == 'es' ? 'Más' : 'More'),
        ],
      ),
    );
  }
}
