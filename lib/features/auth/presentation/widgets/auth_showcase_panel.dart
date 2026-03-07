import 'package:flutter/material.dart';

import '../../../../shared/widgets/animated_reveal.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_logo.dart';

class AuthShowcasePanel extends StatelessWidget {
  const AuthShowcasePanel({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final highlights = const [
      'Trilhas por carreira com módulos e skills',
      'Sessões offline-first com sync automático',
      'Revisões D+1, D+7, D+15 e D+30 com alertas',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedReveal(
                child: AppLogo(
                  size: 76,
                  showLabel: true,
                  subtitle: 'Workspace premium para evolução em TI',
                ),
              ),
              const SizedBox(height: 28),
              AnimatedReveal(
                delay: const Duration(milliseconds: 80),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedReveal(
                delay: const Duration(milliseconds: 140),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.74),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ...highlights.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AnimatedReveal(
                    delay: Duration(milliseconds: 180 + (entry.key * 60)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedReveal(
                delay: const Duration(milliseconds: 320),
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _MiniMetric(
                              label: 'Sessões',
                              value: 'Foco + histórico',
                            ),
                            SizedBox(height: 14),
                            _MiniMetric(
                              label: 'Sync',
                              value: 'Drift + Supabase',
                            ),
                            SizedBox(height: 14),
                            _MiniMetric(
                              label: 'Tablet',
                              value: 'UI pensada para Android',
                            ),
                          ],
                        )
                      : Row(
                          children: const [
                            _MiniMetric(
                              label: 'Sessões',
                              value: 'Foco + histórico',
                            ),
                            SizedBox(width: 18),
                            _MiniMetric(
                              label: 'Sync',
                              value: 'Drift + Supabase',
                            ),
                            SizedBox(width: 18),
                            _MiniMetric(
                              label: 'Tablet',
                              value: 'UI pensada para Android',
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
