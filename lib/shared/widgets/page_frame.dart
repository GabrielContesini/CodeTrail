import 'package:flutter/material.dart';

import '../models/page_tutorial.dart';
import 'page_tutorial_banner.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.tutorial,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final PageTutorialData? tutorial;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader = constraints.maxWidth < 980;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Padding(
            padding: EdgeInsets.all(compactHeader ? 18 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flex(
                  direction: compactHeader ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: compactHeader
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    if (!compactHeader)
                      Expanded(
                        child: _HeaderTexts(title: title, subtitle: subtitle),
                      ),
                    if (compactHeader)
                      _HeaderTexts(title: title, subtitle: subtitle),
                    if (actions.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: compactHeader ? 16 : 0,
                          left: compactHeader ? 0 : 16,
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: actions,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (tutorial != null) ...[
                  PageTutorialBanner(tutorial: tutorial!),
                  const SizedBox(height: 16),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderTexts extends StatelessWidget {
  const _HeaderTexts({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}
