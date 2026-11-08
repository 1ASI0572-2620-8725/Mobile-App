import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/language_service.dart';
import '../../../../shared/application/toast_service.dart';
import '../../../application/accounts_store.dart';
import '../../../domain/model/user_entity.dart';
import '../auth_scaffold.dart';

/// Equivalente a `accounts/presentation/views/register/register.component.ts`.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> onSubmit() async {
    if (isSubmitting) return;
    final toast = context.read<ToastService>();
    final user = User(name: _name.text.trim(), email: _email.text.trim(), password: _password.text);

    if (user.name.isEmpty || user.email.isEmpty || user.password.isEmpty || _confirm.text.isEmpty) {
      return toast.error(context.trNow('auth.register.errors.required'));
    }
    if (user.password != _confirm.text) {
      return toast.error(context.trNow('auth.register.errors.passwordMismatch'));
    }
    if (user.password.length < 8) {
      return toast.error(context.trNow('auth.register.errors.passwordTooShort'));
    }
    if (!RegExp('[A-Z]').hasMatch(user.password) || !RegExp(r'\d').hasMatch(user.password)) {
      return toast.error(context.trNow('auth.register.errors.passwordWeak'));
    }

    setState(() => isSubmitting = true);
    final result = await context.read<AccountStore>().register(user);
    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (result.ok) {
      toast.success(context.trNow('auth.register.errors.success'));
      context.go('/plan');
    } else {
      toast.error(result.message ?? context.trNow('auth.register.errors.emailTaken'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = context.watch<LanguageService>().current == 'es';
    return AuthScaffold(
      tagline: es ? 'Únete a FreshSense.\nEmpieza a ahorrar hoy.' : 'Join FreshSense.\nStart saving today.',
      sub: es ? 'Controla la frescura, reduce el desperdicio, come mejor.' : 'Track freshness, reduce waste, eat better.',
      heading: context.tr('auth.register.title'),
      subtitle: context.tr('auth.register.subtitle'),
      children: [
        LabeledField(
          label: context.tr('auth.register.name'),
          hint: context.tr('auth.register.placeholderName'),
          controller: _name,
        ),
        LabeledField(
          label: context.tr('auth.register.email'),
          hint: context.tr('auth.register.placeholderEmail'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        LabeledField(
          label: context.tr('auth.register.password'),
          hint: context.tr('auth.register.placeholderPassword'),
          controller: _password,
          obscure: true,
        ),
        LabeledField(
          label: context.tr('auth.register.confirm'),
          hint: context.tr('auth.register.placeholderPassword'),
          controller: _confirm,
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
        FilledButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(context.tr('auth.register.cta')),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(context.tr('auth.register.haveAccount'))),
            TextButton(onPressed: () => context.go('/login'), child: Text(context.tr('auth.register.goLogin'))),
          ],
        ),
      ],
    );
  }
}
