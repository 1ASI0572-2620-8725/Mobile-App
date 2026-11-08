/// Equivalente a `accounts/domain/model/user.entity.ts`.
class User {
  const User({this.name = '', this.email = '', this.password = ''});

  final String name;
  final String email;
  final String password;

  User copyWith({String? name, String? email, String? password}) =>
      User(name: name ?? this.name, email: email ?? this.email, password: password ?? this.password);
}
