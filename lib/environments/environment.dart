/// Equivalente a `src/environments/environment*.ts` del front web.
///
/// La URL del backend se puede cambiar al compilar sin tocar el código:
/// `flutter build apk --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`
class Environment {
  Environment._();

  static const bool production = bool.fromEnvironment('dart.vm.product');

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://137-131-253-18.sslip.io/api');
}
