import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../../data/catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../services/study_service.dart';
import '../../state/providers.dart';
import '../../ui/input.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../library/word_progress_screen.dart';
import 'item_details.dart';
import 'session_controller.dart';

/// Anki/Kaishi-style card: the word alone on the front; tap to turn it
/// over to the reading, meanings and an example, then rate yourself.
class FlashcardView extends ConsumerWidget {
  final SessionState s;
  final String deck;
  const FlashcardView(this.s, this.deck, {super.key});

  static const _rateKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final q = s.question!;
    final ctl = ref.read(sessionProvider(deck).notifier);
    final isNew = ref.read(deckServiceProvider(deck))?.stored(q.cardId) == null;
    return Focus(
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        if (!s.flipped && e.logicalKey == LogicalKeyboardKey.space) {
          ctl.flip();
          return KeyEventResult.handled;
        }
        final i = _rateKeys.indexOf(e.logicalKey);
        if (s.flipped && i >= 0) {
          ctl.rate(Rating.values[i]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                LcTokens.spacingXl,
                LcTokens.spacingLg,
                LcTokens.spacingXl,
                LcTokens.spacingLg,
              ),
              child: _Flip(
                flipped: s.flipped,
                front: _Front(q: q, isNew: isNew, onTap: ctl.flip),
                back: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LcCard(large: true, child: ItemDetails(item: q.item)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.insights_rounded, size: 18),
                        label: Text(t.wordProgressOpen),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                WordProgressScreen(itemId: q.item.id),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LcTokens.spacingLg,
              LcTokens.spacingMd,
              LcTokens.spacingLg,
              LcTokens.spacingLg,
            ),
            child: s.flipped
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.rateHelp, style: tt.bodySmall),
                      const SizedBox(height: LcTokens.spacingSm),
                      Row(
                        children: [
                          for (final r in Rating.values) ...[
                            if (r != Rating.again)
                              const SizedBox(width: LcTokens.spacingSm),
                            Expanded(
                              child: _RateButton(
                                rating: r,
                                interval: s.intervals?[r],
                                onPressed: () => ctl.rate(r),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: PressFilledButton(
                      autofocus: true,
                      onPressed: ctl.flip,
                      child: Text(t.showAnswer),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Front extends StatelessWidget {
  final Question q;
  final bool isNew;
  final VoidCallback onTap;
  const _Front({required this.q, required this.isNew, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final item = q.item;
    final kana = item is KanaStudy;
    final (String level, Widget face, String hint) = switch (item) {
      KanaStudy(:final kana) => (
        kana.script == 'hiragana' ? t.hiragana : t.katakana,
        Text(kana.char, style: jpStyle(120, 700, c.ink)),
        t.flashKanaHint,
      ),
      WordStudy(:final word) => (
        'N${word.level}',
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Furigana(word.headwordFurigana, size: 56, showReading: false),
        ),
        t.flashFrontHint,
      ),
      GrammarStudy() => throw StateError('grammar is not a flashcard'),
    };
    return Semantics(
      button: true,
      hint: t.showAnswer,
      child: LcCard(
        large: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 360,
            minWidth: double.infinity,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isNew)
                LcPill(
                  kana ? t.newKana : t.newWord,
                  icon: Icons.auto_awesome_rounded,
                )
              else
                LcPill(level, bg: c.track, fg: c.muted),
              const SizedBox(height: LcTokens.spacingXxl),
              face,
              const SizedBox(height: LcTokens.spacingXxl),
              Text(hint, style: tt.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turns from [front] to [back] around the vertical axis. Without
/// animations the back simply replaces the front.
class _Flip extends StatelessWidget {
  final bool flipped;
  final Widget front;
  final Widget back;
  const _Flip({required this.flipped, required this.front, required this.back});

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return flipped ? back : front;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, a) {
        final incoming = child.key == ValueKey(flipped);
        return AnimatedBuilder(
          animation: a,
          child: child,
          builder: (context, child) {
            // The card leaves edge-on in the first half and the new side
            // arrives in the second, so only one face shows at a time.
            final v = a.value < 0.5 ? math.pi / 2 : (1 - a.value) * math.pi;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(incoming ? -v : v),
              child: child,
            );
          },
        );
      },
      child: KeyedSubtree(
        key: ValueKey(flipped),
        child: flipped ? back : front,
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  final Rating rating;
  final Duration? interval;
  final VoidCallback onPressed;
  const _RateButton({
    required this.rating,
    required this.interval,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.lc;
    final (label, fg, bg) = switch (rating) {
      Rating.again => (t.rateAgain, c.warn, c.warnSoft),
      Rating.hard => (t.rateHard, c.ink, c.track),
      Rating.good => (t.rateGood, c.accent, c.accentSoft),
      Rating.easy => (t.rateEasy, c.good, c.goodSoft),
    };
    return PressFilledButton(
      // "Good" is the usual answer, as on Anki's space bar.
      autofocus: rating == Rating.good,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        minimumSize: const Size(0, 60),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (interval != null)
            Text(
              formatInterval(t, interval!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg.withValues(alpha: 0.8),
              ),
            ),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// "10 นาที", "3 วัน", "1.5 เดือน" …, as on Anki's rating buttons.
String formatInterval(AppLocalizations t, Duration d) {
  String n(double v) =>
      v < 10 && v != v.roundToDouble() ? v.toStringAsFixed(1) : '${v.round()}';
  final m = d.inSeconds / 60;
  if (m < 1) return t.ivlNow;
  if (m < 60) return t.ivlMinutes('${m.round()}');
  final h = m / 60;
  if (h < 24) return t.ivlHours('${h.round()}');
  final days = h / 24;
  if (days < 30) return t.ivlDays('${days.round()}');
  if (days < 365) return t.ivlMonths(n(days / 30));
  return t.ivlYears(n(days / 365));
}
