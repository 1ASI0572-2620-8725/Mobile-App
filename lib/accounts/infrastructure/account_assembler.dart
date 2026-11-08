import '../domain/model/user_entity.dart';
import 'account_response.dart';

/// Equivalente a `accounts/infrastructure/account-assembler.ts`.
class AccountAssembler {
  AccountAssembler._();

  static User fromResponse(AuthResponse response) => User(
    name: response.fullName,
    email: response.email,
    password: '', // no viene del backend
  );
}
