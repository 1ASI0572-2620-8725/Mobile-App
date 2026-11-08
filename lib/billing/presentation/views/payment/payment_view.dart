import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../accounts/application/accounts_store.dart';
import '../../../../core/i18n/language_service.dart';
import '../../../../shared/application/toast_service.dart';
import '../../../../shared/presentation/components/ui.dart';
import '../../../../shared/presentation/theme/app_theme.dart';
import '../../../infrastructure/billing_api.dart';
import '../plan/plan_view.dart';

/// Equivalente a `billing/presentation/views/payment/payment.component.ts`.
/// Pago simulado (sin pasarela real): los datos de tarjeta no se envían a ningún lado.
class PaymentView extends StatefulWidget {
  const PaymentView({super.key});

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  final _form = GlobalKey<FormState>();
  bool isSubmitting = false;

  Future<void> pay() async {
    if (isSubmitting || !(_form.currentState?.validate() ?? false)) return;
    final toast = context.read<ToastService>();
    final store = context.read<AccountStore>();
    final prefs = context.read<SharedPreferences>();
    final billing = context.read<BillingApi>();

    if (store.getCurrentUser() == null) return toast.error('No se encontró usuario registrado.');

    setState(() => isSubmitting = true);
    try {
      // El web guardaba 'premium' y lo convertía a número (NaN). Aquí se busca el id real del plan.
      final selected = prefs.getString(selectedPlanKey) ?? 'premium';
      final plans = await billing.getPlans();
      final plan = plans.firstWhere((p) => selected == 'basic' ? !p.isPremium : p.isPremium, orElse: () => plans.first);
      await billing.subscribe(plan.id, 'DEMO-REF-${DateTime.now().millisecondsSinceEpoch}');
      await store.refreshAfterRoleChange();
      await prefs.remove(selectedPlanKey);
      toast.success('Pago realizado con éxito. ¡Ya eres premium!');
      if (mounted) context.go('/dashboard');
    } catch (_) {
      toast.error('No se pudo procesar el pago. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? '' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.eco, color: FsColors.primary),
          SizedBox(width: 8),
          Text('FreshSense'),
        ],
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(FsSpace.s4),
        children: [
          PageHeader(title: context.tr('billing.payment.title'), subtitle: context.tr('billing.payment.subtitle')),
          FsCard(
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: context.tr('billing.payment.cardName')),
                  validator: _required,
                  autofillHints: const [AutofillHints.creditCardName],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: context.tr('billing.payment.cardNumber'),
                    hintText: '1234 5678 9012 3456',
                    prefixIcon: const Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(labelText: context.tr('billing.payment.expiry'), hintText: 'MM/YY'),
                        keyboardType: TextInputType.datetime,
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(labelText: context.tr('billing.payment.cvv'), hintText: '•••'),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isSubmitting ? null : pay,
                    icon: const Icon(Icons.lock, size: 18),
                    label: Text(context.tr('billing.payment.pay')),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: FsColors.textMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(context.tr('billing.payment.secure'), style: const TextStyle(color: FsColors.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
