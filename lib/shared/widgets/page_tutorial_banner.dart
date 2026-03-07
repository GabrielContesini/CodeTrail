import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/service_providers.dart';
import '../models/page_tutorial.dart';
import 'app_card.dart';

class PageTutorialBanner extends ConsumerStatefulWidget {
  const PageTutorialBanner({super.key, required this.tutorial});

  final PageTutorialData tutorial;

  @override
  ConsumerState<PageTutorialBanner> createState() => _PageTutorialBannerState();
}

class _PageTutorialBannerState extends ConsumerState<PageTutorialBanner> {
  bool _loading = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final shouldShow = await ref
        .read(tutorialServiceProvider)
        .shouldShow(widget.tutorial.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _visible = shouldShow;
    });
  }

  Future<void> _dismiss() async {
    await ref.read(tutorialServiceProvider).markSeen(widget.tutorial.id);
    if (mounted) {
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_visible) {
      return const SizedBox.shrink();
    }

    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, -0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: _visible ? 1 : 0,
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.tutorial.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _dismiss, child: const Text('Entendi')),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.tutorial.description),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.tutorial.steps
                    .asMap()
                    .entries
                    .map(
                      (entry) => _TutorialStepChip(
                        index: entry.key + 1,
                        label: entry.value,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialStepChip extends StatelessWidget {
  const _TutorialStepChip({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
