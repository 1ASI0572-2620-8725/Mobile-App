import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/i18n/language_service.dart';
import '../../../../shared/presentation/components/ui.dart';
import '../../../../shared/presentation/theme/app_theme.dart';

const selectedPlanKey = 'selectedPlan';

class _PlanOption {
  const _PlanOption(this.key, this.icon, {this.featured = false});
  final String key;
  final IconData icon;
  final bool featured;
}

/// Equivalente a `billing/presentation/views/plan/plan.component.ts`.
class PlanView extends StatelessWidget {
  const PlanView({super.key});

  static const _plans = [
    _PlanOption('basic', Icons.person_outline),
    _PlanOption('premium', Icons.workspace_premium_outlined, featured: true),
    _PlanOption('family', Icons.groups_outlined),
  ];

  Future<void> selectPlan(BuildContext context, String plan) async {
    // Básico es gratis: no pasa por pago (mejora respecto al web).
    if (plan == 'basic') return context.go('/dashboard');
    await context.read<SharedPreferences>().setString(selectedPlanKey, plan);
    if (context.mounted) context.go('/payment');
  }

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
      actions: [TextButton(onPressed: () => context.go('/dashboard'), child: Text(context.tr('common.close')))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(FsSpace.s4),
      children: [
        PageHeader(title: context.tr('plans.title'), subtitle: context.tr('plans.subtitle')),
        for (final p in _plans)
          Padding(
            padding: const EdgeInsets.only(bottom: FsSpace.s3),
            child: FsCard(
              borderColor: p.featured ? FsColors.primary : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: FsColors.primaryLight,
                        child: Icon(p.icon, color: FsColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('plans.${p.key}.title'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                      ),
                      if (p.featured) FsBadge(context.tr('plans.popular'), status: FsStatus.ok),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('plans.${p.key}.price'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: FsColors.primaryDark),
                  ),
                  const SizedBox(height: 6),
                  Text(context.tr('plans.${p.key}.desc'), style: const TextStyle(color: FsColors.textSecondary)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: p.featured
                        ? FilledButton(onPressed: () => selectPlan(context, p.key), child: Text(context.tr('plans.select')))
                        : OutlinedButton(onPressed: () => selectPlan(context, p.key), child: Text(context.tr('plans.select'))),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
