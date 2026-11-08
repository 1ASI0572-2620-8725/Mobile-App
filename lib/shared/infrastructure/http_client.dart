import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Cliente HTTP compartido (equivalente a `provideHttpClient(...)` del front web).
///
/// El backend envía el JWT en cookies HttpOnly (`authToken`, `refreshToken`).
/// En el navegador eso lo hace `withCredentials: true`; aquí lo hace un
/// cookie jar persistente, así la sesión sobrevive al cerrar la app.
class HttpClient {
  HttpClient._(this.dio, this.cookieJar);

  final Dio dio;
  final PersistCookieJar cookieJar;

  static Future<HttpClient> create() async {
    final dir = await getApplicationSupportDirectory();
    final jar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 200),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.add(CookieManager(jar));
    return HttpClient._(dio, jar);
  }

  Future<void> clearSession() => cookieJar.deleteAll();
}

/// Mensaje de error del backend (`{ message }` o `{ errors: [{ defaultMessage }] }`).
String? backendMessage(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        final m = (errors.first as Map)['defaultMessage'];
        if (m is String) return m;
      }
      final m = body['message'];
      if (m is String) return m;
    }
  }
  return null;
}
