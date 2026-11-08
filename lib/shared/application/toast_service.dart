import 'package:flutter/material.dart';

import '../presentation/theme/app_theme.dart';

enum ToastType { success, error, warning, info }

/// Equivalente a `shared/application/toast.service.ts`.
/// Muestra los mensajes como SnackBar flotante (mejor UX en móvil).
class ToastService {
  ToastService(this.messengerKey);

  final GlobalKey<ScaffoldMessengerState> messengerKey;

  void success(String message) => _show(message, ToastType.success);
  void error(String message) => _show(message, ToastType.error);
  void warning(String message) => _show(message, ToastType.warning);
  void info(String message) => _show(message, ToastType.info);

  void _show(String message, ToastType type, {Duration duration = const Duration(seconds: 4)}) {
    final (color, icon) = switch (type) {
      ToastType.success => (FsColors.success, Icons.check_circle),
      ToastType.error => (FsColors.danger, Icons.error),
      ToastType.warning => (FsColors.warning, Icons.warning_amber_rounded),
      ToastType.info => (FsColors.info, Icons.info),
    };
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
  }
}
