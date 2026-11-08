import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounts/application/accounts_store.dart';
import 'accounts/application/integrations_service.dart';
import 'accounts/infrastructure/accounts_api.dart';
import 'alerts/application/alerts_store.dart';
import 'alerts/infrastructure/alerts_api.dart';
import 'app.routes.dart';
import 'billing/infrastructure/billing_api.dart';
import 'core/i18n/language_service.dart';
import 'inventory/application/inventory_store.dart';
import 'inventory/infrastructure/inventory_api.dart';
import 'monitoring/application/monitoring_store.dart';
import 'monitoring/infrastructure/devices_api.dart';
import 'monitoring/infrastructure/monitoring_api.dart';
import 'notifications/infrastructure/notifications_api.dart';
import 'recipes/infrastructure/recipes_api.dart';
import 'reports/infrastructure/reports_api.dart';
import 'shared/application/toast_service.dart';
import 'shared/infrastructure/auth_interceptor.dart';
import 'shared/infrastructure/http_client.dart';
import 'shared/presentation/theme/app_theme.dart';

/// Equivalente a `main.ts` + `app.config.ts`: crea los servicios una sola vez
/// (como `providedIn: 'root'`) y los inyecta con Provider.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  final prefs = await SharedPreferences.getInstance();
  final http = await HttpClient.create();
  final language = LanguageService();
  await language.init();

  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final router = buildRouter(navigatorKey);

  final accountStore = AccountStore(AccountApis(http.dio), prefs, http);
  http.dio.interceptors.add(
    AuthInterceptor(
      dio: http.dio,
      refreshToken: accountStore.refreshToken,
      onSessionExpired: () async {
        await accountStore.logout();
        router.go('/login');
      },
    ),
  );

  final monitoringApi = MonitoringApi(http.dio);
  final inventoryApi = InventoryApi(http.dio);
  final alertsApi = AlertsApi(http.dio);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: http),
        Provider.value(value: http.dio),
        Provider.value(value: prefs),
        Provider.value(value: ToastService(messengerKey)),
        ChangeNotifierProvider.value(value: language),
        ChangeNotifierProvider.value(value: accountStore),
        Provider.value(value: IntegrationsService(prefs)),
        Provider.value(value: inventoryApi),
        Provider.value(value: alertsApi),
        Provider.value(value: monitoringApi),
        Provider.value(value: DevicesApi(http.dio)),
        Provider.value(value: BillingApi(http.dio)),
        Provider.value(value: NotificationsApi(http.dio)),
        Provider.value(value: RecipesApi(http.dio)),
        Provider.value(value: ReportsApi(http.dio)),
        ChangeNotifierProvider(create: (_) => InventoryStore(inventoryApi)),
        ChangeNotifierProvider(create: (_) => AlertsStore(alertsApi)),
        ChangeNotifierProvider(create: (_) => MonitoringStore(monitoringApi)),
      ],
      child: AppComponent(router: router, messengerKey: messengerKey),
    ),
  );
}

/// Equivalente a `app.ts`.
class AppComponent extends StatelessWidget {
  const AppComponent({super.key, required this.router, required this.messengerKey});

  final GoRouter router;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return MaterialApp.router(
      title: lang.t('app.brand'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: messengerKey,
      locale: Locale(lang.current),
      routerConfig: router,
    );
  }
}
