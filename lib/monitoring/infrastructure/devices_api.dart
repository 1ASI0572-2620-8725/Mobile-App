import 'package:dio/dio.dart';

import '../../environments/environment.dart';

/// Dispositivo listado (sin secretos).
class DeviceResponse {
  const DeviceResponse({required this.id, required this.deviceId, this.name, required this.registeredAt});

  final int id;
  final String deviceId;
  final String? name;
  final String registeredAt;

  factory DeviceResponse.fromJson(Map<String, dynamic> json) => DeviceResponse(
    id: (json['id'] as num?)?.toInt() ?? 0,
    deviceId: json['deviceId'] as String? ?? '',
    name: json['name'] as String?,
    registeredAt: json['registeredAt'] as String? ?? '',
  );
}

/// Respuesta al registrar: código de emparejamiento (no la clave secreta).
class DeviceRegistrationResponse {
  const DeviceRegistrationResponse({
    required this.deviceId,
    this.name,
    required this.pairingCode,
    required this.pairingExpiresAt,
  });

  final String deviceId;
  final String? name;
  final String pairingCode;
  final String pairingExpiresAt;

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) => DeviceRegistrationResponse(
    deviceId: json['deviceId'] as String? ?? '',
    name: json['name'] as String?,
    pairingCode: json['pairingCode'] as String? ?? '',
    pairingExpiresAt: json['pairingExpiresAt'] as String? ?? '',
  );
}

/// Equivalente a `monitoring/infrastructure/devices-api.ts`.
class DevicesApi {
  DevicesApi(this._http);

  final Dio _http;
  static const _base = '${Environment.apiBaseUrl}/devices';

  Future<DeviceRegistrationResponse> register(String deviceId, String name) async {
    final res = await _http.post(_base, data: {'deviceId': deviceId, 'name': name});
    return DeviceRegistrationResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<DeviceResponse>> list() async {
    final res = await _http.get(_base);
    return (res.data as List? ?? []).map((e) => DeviceResponse.fromJson(e as Map<String, dynamic>)).toList();
  }
}
