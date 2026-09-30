import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../home/home_screen.dart' show levelName;

/// Progress numbers, all derived from the review log with fixed rules and
/// shown with their sample size so they are not over-read.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _deck = vocabDeck;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final s = ref.watch(statsProvider(_deck));
    if (s == null) {
      return SafeArea(
        child: EmptyState(
          icon: Icons.insights_rounded,
          title: t.noContentTitle,
        ),
      );
    }
    final ret = s.trueRetention30;
    final minutes7 = (s.activeMsTotal7 / 60000).round();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          LcTokens.spacingMd,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [
          Text(t.tabStats, style: tt.headlineMedium),
          const SizedBox(height: LcTokens.spacingLg),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: vocabDeck, label: Text(t.deckVocabShort)),
              ButtonSegment(
                value: grammarDeck,
                label: Text(t.deckGrammarShort),
              ),
            ],
            selected: {_deck},
            onSelectionChanged: (v) => setState(() => _deck = v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: LcTokens.spacingLg),
          LcCard(
            large: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.expectedKnown.toStringAsFixed(0),
                  style: tt.headlineMedium?.copyWith(fontSize: 40),
                ),
                Text(t.expectedKnown, style: tt.bodyLarge),
                const SizedBox(height: 4),
                Text(t.expectedKnownHelp, style: tt.bodySmall),
                const SizedBox(height: LcTokens.spacingLg),
                Row(
                  children: [
                    Expanded(
                      child: StatTile('${s.itemsStarted}', t.itemsStarted),
                    ),
                    Expanded(
                      child: StatTile('${s.masteredItems}', t.masteredItems),
                    ),
                    Expanded(child: StatTile('$minutes7', t.minutes7Days)),
                  ],
                ),
              ],
            ),
          ),
          SectionLabel(t.retentionTitle),
          LcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ret == null ? '–' : '${(ret * 100).toStringAsFixed(1)}%',
                      style: tt.headlineMedium,
                    ),
                    const SizedBox(width: LcTokens.spacingSm),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          t.targetIs((s.targetRetention * 100).round()),
                          style: tt.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LcTokens.spacingSm),
                Text(t.retentionHelp(s.retentionSample30), style: tt.bodySmall),
                if (s.retentionSample30 < 50)
                  Text(
                    t.smallSample,
                    style: tt.bodySmall?.copyWith(color: c.warn),
                  ),
              ],
            ),
          ),
          SectionLabel(t.coverageTitle),
          LcCard(
            child: Column(
              children: [
                for (final l in s.levels)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _deck == grammarDeck
                                  ? t.grammarLevel(l.level.toUpperCase())
                                  : levelName(t, l.level),
                              style: tt.labelLarge,
                            ),
                            const SizedBox(width: LcTokens.spacingSm),
                            Expanded(
                              child: Text(
                                t.levelLine(
                                  l.expectedKnown.toStringAsFixed(0),
                                  l.total,
                                  l.mastered,
                                ),
                                textAlign: TextAlign.right,
                                style: tt.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LcProgressBar(l.coverage),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SectionLabel(t.activity14),
          LcCard(
            child: _Bars(
              values: [for (final d in s.last14Days) d.reviews],
              highlight: [for (final d in s.last14Days) d.passed],
              caption: t.activityHelp,
            ),
          ),
          SectionLabel(t.forecast7),
          LcCard(
            child: _Bars(
              values: s.forecast7,
              labels: [t.today, for (var i = 1; i < 7; i++) '+$i'],
              caption: t.forecastHelp,
            ),
          ),
          if (s.calibrationSample >= 100) ...[
            SectionLabel(t.calibration),
            LcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in s.calibration)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 88,
                            child: Text(
                              '${(b.lower * 100).round()}–${(b.upper * 100).round()}%',
                              style: tt.bodySmall,
                            ),
                          ),
                          Expanded(child: LcProgressBar(b.actual, height: 8)),
                          SizedBox(
                            width: 72,
                            child: Text(
                              '${(b.actual * 100).round()}% (${b.count})',
                              textAlign: TextAlign.right,
                              style: tt.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: LcTokens.spacingSm),
                  Text(
                    t.calibrationHelp(s.logLoss?.toStringAsFixed(3) ?? '–'),
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          if (s.leeches > 0) ...[
            const SizedBox(height: LcTokens.spacingLg),
            LcPill(
              t.leeches(s.leeches),
              bg: c.warnSoft,
              fg: c.warn,
              icon: Icons.priority_high_rounded,
            ),
          ],
          const SizedBox(height: LcTokens.spacingLg),
          Text(t.totalReviews(s.totalReviews), style: tt.bodySmall),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<int> values;
  final List<int>? highlight;
  final List<String>? labels;
  final String caption;
  const _Bars({
    required this.values,
    this.highlight,
    this.labels,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final tt = Theme.of(context).textTheme;
    final maxV = math.max(1, values.fold(0, math.max));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Semantics(
                    label: '${labels?[i] ?? ''} ${values[i]}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (values[i] > 0)
                            Text(
                              '${values[i]}',
                              style: tt.bodySmall?.copyWith(fontSize: 10),
                            ),
                          Container(
                            height: 64 * values[i] / maxV + 2,
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: highlight == null
                                ? Container(color: c.accent)
                                : FractionallySizedBox(
                                    heightFactor: values[i] == 0
                                        ? 0
                                        : highlight![i] / values[i],
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: c.accent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (labels != null)
          Row(
            children: [
              for (final l in labels!)
                Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: tt.bodySmall,
                  ),
                ),
            ],
          ),
        const SizedBox(height: LcTokens.spacingSm),
        Text(caption, style: tt.bodySmall),
      ],
    );
  }
}
