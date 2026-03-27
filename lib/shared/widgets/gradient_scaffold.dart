import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/design/background.webp',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.34),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.96),
                scheme.surface.withValues(alpha: 0.90),
                Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.98),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -160,
          left: -80,
          child: _GlowOrb(
            size: 380,
            colors: [
              scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
              Colors.transparent,
            ],
          ),
        ),
        Positioned(
          right: -120,
          bottom: -180,
          child: _GlowOrb(
            size: 460,
            colors: [
              scheme.secondary.withValues(alpha: isDark ? 0.18 : 0.10),
              Colors.transparent,
            ],
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                  Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}
