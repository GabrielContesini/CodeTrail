import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/icon_mapper.dart';
import '../models/app_view_models.dart';
import 'gradient_scaffold.dart';

class NavigationShellScaffold extends StatefulWidget {
  const NavigationShellScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  @override
  State<NavigationShellScaffold> createState() =>
      _NavigationShellScaffoldState();
}

class _NavigationShellScaffoldState extends State<NavigationShellScaffold> {
  bool _navVisible = true;

  @override
  Widget build(BuildContext context) {
    final items = buildNavigationItems();
    final startItems = items
        .where(
          (item) =>
              item.route == AppRoutes.dashboard ||
              item.route == AppRoutes.tracks ||
              item.route == AppRoutes.sessions,
        )
        .toList();
    final endItems = items
        .where(
          (item) =>
              item.route == AppRoutes.tasks || item.route == AppRoutes.projects,
        )
        .toList();
    final overflowItems = items
        .where(
          (item) =>
              item.route == AppRoutes.reviews ||
              item.route == AppRoutes.notes ||
              item.route == AppRoutes.analytics ||
              item.route == AppRoutes.settings,
        )
        .toList();

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shellPadding = EdgeInsets.fromLTRB(
                constraints.maxWidth >= 1180 ? 22 : 14,
                constraints.maxWidth >= 1180 ? 18 : 12,
                constraints.maxWidth >= 1180 ? 22 : 14,
                12,
              );

              return Padding(
                padding: shellPadding,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: AnimatedPadding(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.only(
                            bottom: _navVisible ? 128 : 18,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _navVisible
                            ? _PortfolioDock(
                                key: const ValueKey('portfolio-dock'),
                                location: widget.location,
                                startItems: startItems,
                                endItems: endItems,
                                overflowItems: overflowItems,
                                onToggleVisibility: _toggleNavigation,
                              )
                            : Align(
                                key: const ValueKey('portfolio-dock-hidden'),
                                child: _DockVisibilityButton(
                                  icon: Icons.keyboard_arrow_up_rounded,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.94),
                                  borderColor: Theme.of(
                                    context,
                                  ).colorScheme.outline,
                                  iconColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  onPressed: _toggleNavigation,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleNavigation() {
    setState(() => _navVisible = !_navVisible);
  }
}

class _PortfolioDock extends StatelessWidget {
  const _PortfolioDock({
    super.key,
    required this.location,
    required this.startItems,
    required this.endItems,
    required this.overflowItems,
    required this.onToggleVisibility,
  });

  final String location;
  final List<AppNavigationItem> startItems;
  final List<AppNavigationItem> endItems;
  final List<AppNavigationItem> overflowItems;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dockColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.42),
      scheme.surface,
    );
    final moreSelected = overflowItems.any(
      (item) => _matchesLocation(item.route, location),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: SizedBox(
          height: 102,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SizedBox(
                  height: 94,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _DockSegment(
                                color: dockColor,
                                children: startItems
                                    .map(
                                      (item) => _DockNavItem(
                                        item: item,
                                        selected: _matchesLocation(
                                          item.route,
                                          location,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(width: 88),
                            Expanded(
                              child: _DockSegment(
                                color: dockColor,
                                children: [
                                  ...endItems.map(
                                    (item) => _DockNavItem(
                                      item: item,
                                      selected: _matchesLocation(
                                        item.route,
                                        location,
                                      ),
                                    ),
                                  ),
                                  _DockMoreItem(
                                    selected: moreSelected,
                                    items: overflowItems,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: _DockCenterAction(
                          selected: location == AppRoutes.newSession,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DockVisibilityButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  backgroundColor: scheme.primary.withValues(alpha: 0.14),
                  borderColor: scheme.primary.withValues(alpha: 0.24),
                  iconColor: scheme.primary,
                  onPressed: onToggleVisibility,
                  size: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockSegment extends StatelessWidget {
  const _DockSegment({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.52),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: children
            .map(
              (child) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: child,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DockNavItem extends StatelessWidget {
  const _DockNavItem({required this.item, required this.selected});

  final AppNavigationItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: 0.82);

    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.go(item.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: selected
                  ? scheme.primary.withValues(alpha: 0.86)
                  : Colors.transparent,
            ),
            child: Center(
              child: Icon(
                IconMapper.fromKey(item.iconKey),
                size: 22,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockCenterAction extends StatelessWidget {
  const _DockCenterAction({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Foco',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => context.go(AppRoutes.newSession),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? scheme.secondary : Theme.of(context).cardColor,
              border: Border.all(
                color: selected
                    ? scheme.secondary.withValues(alpha: 0.56)
                    : scheme.outline,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 30,
              color: selected ? const Color(0xFF06110A) : scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DockMoreItem extends StatelessWidget {
  const _DockMoreItem({required this.selected, required this.items});

  final bool selected;
  final List<AppNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: 0.82);

    return Tooltip(
      message: 'Mais',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showMoreSheet(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: selected
                  ? scheme.primary.withValues(alpha: 0.86)
                  : Colors.transparent,
            ),
            child: Center(
              child: Icon(Icons.more_horiz_rounded, size: 22, color: foreground),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMoreSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final dockColor = Color.alphaBlend(
          Colors.black.withValues(alpha: 0.46),
          scheme.surface,
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: dockColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.52),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mais opções',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: items
                            .map(
                              (item) => SizedBox(
                                width: 136,
                                child: _MoreSheetItem(item: item),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoreSheetItem extends StatelessWidget {
  const _MoreSheetItem({required this.item});

  final AppNavigationItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).pop();
          context.go(item.route);
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.34),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconMapper.fromKey(item.iconKey),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockVisibilityButton extends StatelessWidget {
  const _DockVisibilityButton({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.onPressed,
    this.size = 42,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: size * 0.52),
        ),
      ),
    );
  }
}

bool _matchesLocation(String route, String location) {
  if (route == AppRoutes.dashboard) {
    return location == route;
  }
  if (route == AppRoutes.tracks) {
    return location == route || location.startsWith(AppRoutes.trackDetails);
  }
  if (route == AppRoutes.sessions) {
    return location == route;
  }
  if (route == AppRoutes.projects) {
    return location == route || location.startsWith(AppRoutes.projectDetails);
  }
  if (route == AppRoutes.settings) {
    return location == route || location.startsWith('${AppRoutes.settings}/');
  }
  return location == route;
}
