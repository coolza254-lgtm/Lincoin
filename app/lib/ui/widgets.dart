import 'package:flutter/material.dart';

import '../data/content_db.dart';
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
    return Container(
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
    );
  }
}

/// Lincoin amount with the coin mark. The coin is a shape, not only colour,
/// so it still reads in the black-and-white theme.
class CoinChip extends StatelessWidget {
  final int amount;
  final bool signed;
  final bool large;
  const CoinChip(
    this.amount, {
    super.key,
    this.signed = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final text = signed && amount > 0 ? '+$amount' : '$amount';
    return Semantics(
      label: '$text Lincoin',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 10,
          vertical: large ? 8 : 4,
        ),
        decoration: BoxDecoration(
          color: c.coinSoft,
          borderRadius: BorderRadius.circular(LcTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinMark(size: large ? 22 : 16),
            SizedBox(width: large ? 8 : 6),
            Text(
              _group(text),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: large ? 18 : 14,
                color: c.coin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _group(String s) =>
      s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

class CoinMark extends StatelessWidget {
  final double size;
  const CoinMark({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.coin,
        border: Border.all(color: c.coinSoft, width: size / 10),
      ),
      child: Text(
        'L',
        style: TextStyle(
          fontSize: size * 0.58,
          height: 1,
          fontWeight: FontWeight.w800,
          color: c.coinSoft,
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
