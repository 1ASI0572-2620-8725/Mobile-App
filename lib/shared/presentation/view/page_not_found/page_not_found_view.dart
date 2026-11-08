import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/ui.dart';
import '../../theme/app_theme.dart';

/// Equivalente a `shared/presentation/view/page-not-found/page-not-found.view.ts`.
class PageNotFoundView extends StatelessWidget {
  const PageNotFoundView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(FsSpace.s6),
        child: FsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '404',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: FsColors.primary),
              ),
              EmptyState(
                icon: Icons.travel_explore,
                title: 'Page not found',
                hint: 'The page you are looking for doesn’t exist or has been moved.',
                action: FilledButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
