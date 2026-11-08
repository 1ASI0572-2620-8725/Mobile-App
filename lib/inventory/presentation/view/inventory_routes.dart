import 'package:go_router/go_router.dart';

import '../../../shared/infrastructure/auth_guard.dart';
import 'form/inventory_form_view.dart';
import 'list/inventory_view.dart';

/// Equivalente a `inventory/presentation/view/inventory.routes.ts`.
final inventoryRoutes = GoRoute(
  path: '/inventory',
  redirect: authGuard,
  builder: (_, _) => const FoodInventoryView(),
  routes: [GoRoute(path: 'add', builder: (_, _) => const InventoryAddView())],
);
