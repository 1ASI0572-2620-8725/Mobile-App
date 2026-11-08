import 'package:dio/dio.dart';

/// Equivalente a `shared/infrastructure/auth.interceptor.ts`.
///
/// Ante un 401 intenta renovar el access token (15 min) con el refresh token
/// (7 días) y repite la petición; si no se puede, cierra la sesión.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.dio, required this.refreshToken, required this.onSessionExpired});

  final Dio dio;
  final Future<bool> Function() refreshToken;
  final void Function() onSessionExpired;

  static const _retriedKey = 'fs_retried';

  bool _isAuthEndpoint(String url) =>
      url.contains('/accounts/login') ||
      url.contains('/accounts/register') ||
      url.contains('/accounts/logout') ||
      url.contains('/accounts/refresh') ||
      url.contains('/accounts/me') ||
      url.contains('/billing/plans');

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final unauthorized = err.response?.statusCode == 401;
    if (!unauthorized || _isAuthEndpoint(req.uri.toString()) || req.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    if (await refreshToken()) {
      try {
        req.extra[_retriedKey] = true;
        return handler.resolve(await dio.fetch(req));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    onSessionExpired();
    handler.next(err);
  }
}
