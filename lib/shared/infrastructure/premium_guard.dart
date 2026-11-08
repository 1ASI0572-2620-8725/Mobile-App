import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../accounts/application/accounts_store.dart';

/// Equivalente a `shared/infrastructure/premium.guard.ts`.
/// Solo usuarios premium (USER_PREMIUM / ADMIN); si no, a la pantalla de planes.
String? premiumGuard(BuildContext context, GoRouterState state) => context.read<AccountStore>().isPremium() ? null : '/plan';
