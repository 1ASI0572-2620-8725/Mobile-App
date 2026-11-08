import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'accounts/presentation/views/login/login_view.dart';
import 'accounts/presentation/views/register/register_view.dart';
import 'accounts/presentation/views/settings/settings_view.dart';
import 'alerts/presentation/alerts_view.dart';
import 'billing/presentation/views/payment/payment_view.dart';
import 'billing/presentation/views/plan/plan_view.dart';
import 'inventory/presentation/view/inventory_routes.dart';
import 'monitoring/presentation/devices_view.dart';
import 'monitoring/presentation/monitoring_view.dart';
import 'notifications/presentation/notifications_view.dart';
import 'recipes/presentation/recipes_view.dart';
import 'reports/presentation/reports_view.dart';
import 'shared/infrastructure/auth_guard.dart';
import 'shared/presentation/components/layout/layout.dart';
import 'shared/presentation/view/home/home_view.dart';
import 'shared/presentation/view/page_not_found/page_not_found_view.dart';

/// Equivalente a `app.routes.ts` (mismas rutas y guards).
GoRouter buildRouter(GlobalKey<NavigatorState> navigatorKey) => GoRouter(
  navigatorKey: navigatorKey,
  // Mejora UX: si hay sesión guardada entra directo; si no, el authGuard lleva a /login.
  initialLocation: '/dashboard',
  errorBuilder: (_, _) => const PageNotFoundView(),
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/login'),
    GoRoute(path: '/register', builder: (_, _) => const RegisterView()),
    GoRoute(path: '/login', builder: (_, _) => const LoginView()),
    GoRoute(path: '/plan', redirect: authGuard, builder: (_, _) => const PlanView()),
    GoRoute(path: '/payment', redirect: authGuard, builder: (_, _) => const PaymentView()),
    ShellRoute(
      builder: (_, state, child) => LayoutComponent(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/dashboard', redirect: authGuard, builder: (_, _) => const HomeView()),
        inventoryRoutes,
        GoRoute(path: '/monitoring', redirect: authGuard, builder: (_, _) => const MonitoringView()),
        GoRoute(path: '/devices', redirect: authGuard, builder: (_, _) => const DevicesView()),
        GoRoute(path: '/alerts', redirect: authGuard, builder: (_, _) => const AlertsView()),
        GoRoute(path: '/recipes', redirect: authGuard, builder: (_, _) => const RecipesView()),
        GoRoute(path: '/reports', redirect: authGuard, builder: (_, _) => const ReportsView()),
        GoRoute(path: '/notifications', redirect: authGuard, builder: (_, _) => const NotificationsView()),
        GoRoute(path: '/settings', redirect: authGuard, builder: (_, _) => const SettingsView()),
      ],
    ),
  ],
);
