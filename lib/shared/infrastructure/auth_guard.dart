import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../accounts/application/accounts_store.dart';

/// Equivalente a `shared/infrastructure/auth.guard.ts`.
/// Devuelve `null` si puede pasar o la ruta a la que se debe redirigir.
FutureOr<String?> authGuard(BuildContext context, GoRouterState state) async {
  final store = context.read<AccountStore>();
  if (store.isLogged()) return null;

  // Intenta restaurar la sesión con la cookie guardada.
  if (await store.tryRestoreSession()) return null;
  return '/login';
}
