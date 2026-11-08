/// Equivalente a `accounts/infrastructure/account-response.ts`.
class AuthResponse {
  const AuthResponse({required this.id, required this.email, required this.fullName, required this.role});

  final int id;
  final String email;
  final String fullName;

  /// `ADMIN` | `USER_STANDARD` | `USER_PREMIUM`
  final String role;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    id: (json['id'] as num?)?.toInt() ?? 0,
    email: json['email'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    role: json['role'] as String? ?? 'USER_STANDARD',
  );

  /// El token nunca se guarda: viaja solo en la cookie HttpOnly.
  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'fullName': fullName, 'role': role};
}
