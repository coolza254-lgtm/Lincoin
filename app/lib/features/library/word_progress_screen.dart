import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../../l10n/app_localizations.dart';
import '../../services/library_service.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../study/flashcard.dart' show formatInterval;
import '../study/item_details.dart';
import 'library_screen.dart' show progressColors, progressLabel;

/// One word in depth: what it means, how well it is known now, when it
/// comes back, and every answer given to it.
class WordProgressScreen extends ConsumerWidget {
  final String itemId;
  const WordProgressScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lib = ref.watch(libraryProvider);
    final e = lib?.entry(itemId);
    return Scaffold(
      appBar: AppBar(title: Text(t.wordProgress)),
      body: e == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                LcTokens.spacingXl,
                0,
                LcTokens.spacingXl,
                LcTokens.spacingXxl,
              ),
              children: [
                _Progress(e, lib!),
                const SizedBox(height: LcTokens.spacingLg),
                LcCard(large: true, child: ItemDetails(item: e.item)),
                if (e.card != null) _History(lib.history(e.card!.id)),
              ],
            ),
    );
  }
}

class _Progress extends StatelessWidget {
  final LibraryEntry e;
  final LibraryService lib;
  const _Progress(this.e, this.lib);

  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final (fg, bg) = progressColors(c, e.progress);
    final s = e.card?.state;
    final now = lib.svc.clock.nowUtc();
    final started = s != null && !s.isNew;
    final history = started ? lib.history(e.card!.id) : const [];

    Widget stat(String label, String value, {String? help}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.bodyLarge),
                if (help != null) Text(help, style: tt.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: LcTokens.spacingMd),
          Text(value, style: tt.titleMedium),
        ],
      ),
    );

    return LcCard(
      large: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LcPill(
                progressLabel(t, e.progress),
                bg: bg,
                fg: fg,
                icon: e.progress == WordProgress.mastered
                    ? Icons.verified_rounded
                    : null,
              ),
              if (e.card?.isLeech ?? false) ...[
                const SizedBox(width: LcTokens.spacingSm),
                LcPill(
                  t.leechTag,
                  bg: c.warnSoft,
                  fg: c.warn,
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ],
          ),
          if (!started) ...[
            const SizedBox(height: LcTokens.spacingMd),
            Text(t.notStartedBody, style: tt.bodyMedium),
          ] else ...[
            const SizedBox(height: LcTokens.spacingLg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${((e.recall ?? 0) * 100).round()}%',
                  style: tt.displaySmall?.copyWith(color: fg),
                ),
                const SizedBox(width: LcTokens.spacingMd),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(t.statRecall, style: tt.bodyMedium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LcTokens.spacingSm),
            LcProgressBar(e.recall ?? 0, color: fg),
            const SizedBox(height: LcTokens.spacingXs),
            Text(t.statRecallHelp, style: tt.bodySmall),
            const Divider(height: LcTokens.spacingXl),
            stat(
              t.statNext,
              e.due
                  ? t.statNextNow
                  : t.statNextIn(
                      formatInterval(t, s.due!.difference(now)),
                      _date(s.due!),
                    ),
            ),
            if (s.stability != null)
              stat(
                t.statStability,
                t.statStabilityValue(
                  formatInterval(
                    t,
                    Duration(minutes: (s.stability! * 24 * 60).round()),
                  ),
                ),
                help: t.statStabilityHelp,
              ),
            if (s.difficulty != null)
              stat(t.statDifficulty, '${s.difficulty!.toStringAsFixed(1)}/10'),
            stat(t.statReps, t.statTimes(s.reps)),
            stat(t.statLapses, t.statTimes(s.lapses)),
            if (history.isNotEmpty)
              stat(t.statFirstSeen, _date(history.last.tsUtc)),
            if (e.card!.isLeech) ...[
              const SizedBox(height: LcTokens.spacingSm),
              Text(t.statLeech, style: tt.bodySmall?.copyWith(color: c.warn)),
            ],
          ],
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  final List<ReviewRecord> log;
  const _History(this.log);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    String two(int n) => n.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(t.historyTitle),
        LcCard(
          child: log.isEmpty
              ? Text(t.historyEmpty, style: tt.bodyMedium)
              : Column(
                  children: [
                    for (final r in log.take(50))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(() {
                                    final d = r.tsUtc.toLocal();
                                    return '${d.day}/${d.month}/${d.year} '
                                        '${two(d.hour)}:${two(d.minute)}';
                                  }(), style: tt.bodyMedium),
                                  if (r.rPredicted != null)
                                    Text(
                                      t.historyRecall(
                                        (r.rPredicted! * 100).round(),
                                      ),
                                      style: tt.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            _RatingPill(r.rating, c),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RatingPill extends StatelessWidget {
  final Rating rating;
  final LcPalette c;
  const _RatingPill(this.rating, this.c);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, fg, bg) = switch (rating) {
      Rating.again => (t.rateAgain, c.warn, c.warnSoft),
      Rating.hard => (t.rateHard, c.ink, c.track),
      Rating.good => (t.rateGood, c.accent, c.accentSoft),
      Rating.easy => (t.rateEasy, c.good, c.goodSoft),
    };
    return LcPill(label, bg: bg, fg: fg);
  }
}
