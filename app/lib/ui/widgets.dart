import 'package:flutter/material.dart';

import '../data/content_db.dart';
import 'input.dart';
import 'theme.dart';
import 'tokens.g.dart';

/// Rounded surface with the soft two-layer shadow from the design.
class LcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool large;

  const LcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LcTokens.spacingXl),
    this.onTap,
    this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final radius = BorderRadius.circular(
      large ? LcTokens.radiusCardLarge : LcTokens.radiusCard,
    );
    return PressScale(
      enabled: onTap != null,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? c.surface,
          borderRadius: radius,
          boxShadow: c.dark
              ? null
              : [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
          border: c.dark ? Border.all(color: c.line) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class LcProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  const LcProgressBar(this.value, {super.key, this.height = 10, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(LcTokens.radiusPill),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.track),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: context.motionNormal,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: ColoredBox(color: color ?? c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Japanese text with readings above kanji (ruby).
class Furigana extends StatelessWidget {
  final List<FuriganaPart> parts;
  final double size;
  final bool showReading;
  final Color? color;
  final int weight;

  const Furigana(
    this.parts, {
    super.key,
    this.size = LcTokens.jpPromptSize,
    this.showReading = true,
    this.color,
    this.weight = LcTokens.jpPromptWeight,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final base = jpStyle(size, weight, color ?? c.ink);
    final rt = jpStyle(size * 0.34, 500, c.muted);
    final hasRt = showReading && parts.any((p) => p.rt != null);
    final label = parts.map((p) => p.text).join();
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final p in parts)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasRt)
                  Text(
                    p.rt != null ? p.rt! : '',
                    style: rt,
                    textScaler: TextScaler.noScaling,
                  ),
                Text(p.text, style: base),
              ],
            ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      4,
      LcTokens.spacingXl,
      4,
      LcTokens.spacingSm,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: context.lc.muted),
    ),
  );
}

/// Small rounded label (question type, word class …).
class LcPill extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color? fg;
  final IconData? icon;
  const LcPill(this.text, {super.key, this.bg, this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? c.accentSoft,
        borderRadius: BorderRadius.circular(LcTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg ?? c.accent),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg ?? c.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Big number with a caption, for stats and the home screen.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final String? sub;
  const StatTile(this.value, this.label, {super.key, this.sub});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: t.headlineMedium),
        Text(label, style: t.bodySmall),
        if (sub != null) Text(sub!, style: t.bodySmall),
      ],
    );
  }
}

/// Simple centred message for empty states.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(LcTokens.spacingXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.lc.muted),
          const SizedBox(height: LcTokens.spacingMd),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: LcTokens.spacingSm),
            Text(
              body!,
              style: t.bodyMedium?.copyWith(color: context.lc.muted),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: LcTokens.spacingLg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Grows and fades [child] in when [shown] (e.g. the result around an answered question).
class Reveal extends StatelessWidget {
  final bool shown;
  final Widget child;
  const Reveal({super.key, required this.shown, required this.child});

  @override
  Widget build(BuildContext context) => context.reduceMotion
      // AnimatedSize cannot run with a zero duration; without motion the
      // child simply appears.
      ? (shown ? child : const SizedBox.shrink())
      : AnimatedSize(
          duration: context.motionNormal,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: context.motionNormal,
            curve: Curves.easeOut,
            opacity: shown ? 1 : 0,
            child: child,
          ),
        );
}

/// Scales its child in with a small overshoot.
class PopIn extends StatelessWidget {
  final Widget child;
  const PopIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: context.reduceMotion ? 1 : 0.6, end: 1),
    duration: context.motionNormal * 1.6,
    curve: Curves.elasticOut,
    builder: (context, v, child) => Transform.scale(scale: v, child: child),
    child: child,
  );
}
