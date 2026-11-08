import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/language_service.dart';
import '../../../../shared/presentation/theme/app_theme.dart';
import '../../../application/accounts_store.dart';
import '../auth_scaffold.dart';

/// Equivalente a `accounts/presentation/views/login/login.component.ts`.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool isSubmitting = false;
  String? loginError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> onSubmit() async {
    if (isSubmitting) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => loginError = 'auth.login.errors.required');
      return;
    }
    setState(() {
      isSubmitting = true;
      loginError = null;
    });
    final success = await context.read<AccountStore>().login(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => isSubmitting = false);
    if (success) {
      context.go('/dashboard');
    } else {
      setState(() => loginError = 'auth.login.errors.invalid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = context.watch<LanguageService>().current == 'es';
    return AuthScaffold(
      tagline: es ? 'Reduce el desperdicio.\nCome mejor.' : 'Reduce waste.\nEat smarter.',
      sub: es ? 'Monitorea la frescura de tus alimentos en tiempo real.' : 'Monitor your food freshness in real time.',
      heading: context.tr('auth.login.heading'),
      subtitle: context.tr('auth.login.sub'),
      children: [
        AutofillGroup(
          child: Column(
            children: [
              LabeledField(
                label: context.tr('auth.login.email'),
                hint: context.tr('auth.login.placeholderEmail'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              LabeledField(
                label: context.tr('auth.login.password'),
                hint: context.tr('auth.login.placeholderPassword'),
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
                autofillHints: const [AutofillHints.password],
              ),
            ],
          ),
        ),
        if (loginError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: FsSpace.s3),
            child: Text(context.tr(loginError!), style: const TextStyle(color: FsColors.danger)),
          ),
        FilledButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(context.tr('auth.login.cta')),
        ),
        const SizedBox(height: FsSpace.s4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.tr('auth.login.noAccount')),
            TextButton(onPressed: () => context.go('/register'), child: Text(context.tr('auth.login.goRegister'))),
          ],
        ),
      ],
    );
  }
}
