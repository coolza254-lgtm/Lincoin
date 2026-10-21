import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lincoin_core/lincoin_core.dart' show FsrsOptimizer;

import '../../data/catalog.dart';
import '../../services/model_trainer.dart';
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
  static const _deck = vocabDeck;

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
        key: const PageStorageKey('stats'),
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          LcTokens.spacingMd,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [
          Text(t.tabStats, style: tt.headlineMedium),
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
          SectionLabel(t.modelTitle),
          const _ModelCard(),
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
                            Text(levelName(t, l.level), style: tt.labelLarge),
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
          SectionLabel(t.forecast30),
          LcCard(
            child: _Bars(
              values: s.forecast30,
              showValues: false,
              labels: [
                for (var i = 0; i < 30; i++)
                  i == 0 ? t.today : (i % 7 == 0 ? '+$i' : ''),
              ],
              caption: t.forecastHelp,
            ),
          ),
          SectionLabel(t.strengthTitle),
          LcCard(
            child: _Bars(
              values: s.strength,
              labels: const [
                '<1 วัน',
                '1–7 วัน',
                '1–4 สป.',
                '1–3 ด.',
                '3–12 ด.',
                '>1 ปี',
              ],
              caption: t.strengthHelp,
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

  /// Numbers above the bars (off when there are too many bars for them).
  final bool showValues;
  const _Bars({
    required this.values,
    this.highlight,
    this.labels,
    required this.caption,
    this.showValues = true,
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
                          if (showValues && values[i] > 0)
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
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: tt.bodySmall?.copyWith(
                      fontSize: values.length > 14 ? 10 : null,
                    ),
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

/// The memory model: personal or default parameters, how well it predicts
/// this learner, refitting, and the most efficient retention target.
class _ModelCard extends ConsumerStatefulWidget {
  const _ModelCard();

  @override
  ConsumerState<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends ConsumerState<_ModelCard> {
  bool _busy = false;

  static String _pct(double x) => (x * 100).toStringAsFixed(1);

  Future<void> _fit() async {
    final t = AppLocalizations.of(context);
    final m = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await ref.read(modelTrainerProvider).train();
      ref.read(paramsVersionProvider.notifier).bump();
      ref.read(dataVersionProvider.notifier).bump();
      if (r != null) {
        m.showSnackBar(
          SnackBar(
            content: Text(
              r.active
                  ? t.modelFitDone(_pct(r.rmseBefore), _pct(r.rmseAfter))
                  : t.modelFitSame,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    ref.watch(dataVersionProvider);
    final active = ref.watch(activeParamsProvider);
    final repo = ref.watch(paramsRepoProvider);
    final latest = repo.latest(vocabDeck);
    final progress = ref.watch(modelTrainerProvider).progress();
    const need = FsrsOptimizer.minReviews;
    final advice = ref.watch(retentionAdviceProvider);
    final settings = ref.watch(settingsProvider);
    final now = settings.vocabRetention;
    double minutesAt(double r) => advice.curve
        .reduce(
          (a, b) => (a.retention - r).abs() < (b.retention - r).abs() ? a : b,
        )
        .minutesPerDay;
    final best = advice.recommended;
    String date(DateTime d) {
      final l = d.toLocal();
      return '${l.day}/${l.month}/${l.year}';
    }

    return LcCard(
      large: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active != null
                    ? Icons.psychology_rounded
                    : Icons.psychology_outlined,
                color: active != null ? c.good : c.accent,
              ),
              const SizedBox(width: LcTokens.spacingSm),
              Expanded(
                child: Text(
                  active != null ? t.modelPersonal : t.modelDefault,
                  style: tt.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: LcTokens.spacingXs),
          Text(t.modelWhy, style: tt.bodySmall),
          const SizedBox(height: LcTokens.spacingMd),
          if (active != null) ...[
            Text(
              t.modelError(_pct(active.rmseBefore), _pct(active.rmseAfter)),
              style: tt.bodyLarge,
            ),
            Text(t.modelErrorHelp, style: tt.bodySmall),
            const SizedBox(height: LcTokens.spacingXs),
            Text(
              t.modelFittedOn(
                date(active.createdAt),
                active.reviews,
                ModelTrainer.refitEvery,
              ),
              style: tt.bodySmall,
            ),
          ] else if (progress.now < need) ...[
            LcProgressBar(progress.now / need, height: 6),
            const SizedBox(height: 4),
            Text(t.modelNeed(need - progress.now), style: tt.bodySmall),
          ],
          if (latest != null && !latest.active && latest != active)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.modelKeptOld, style: tt.bodySmall),
            ),
          if (progress.now >= need)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _fit,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(_busy ? t.modelFitting : t.modelFitNow),
              ),
            ),
          const Divider(height: LcTokens.spacingXl),
          Text(t.retentionBest((best * 100).round()), style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            t.retentionBestHelp(
              (now * 100).round(),
              minutesAt(now).round(),
              minutesAt(best).round(),
            ),
            style: tt.bodySmall,
          ),
          if ((best - now).abs() >= 0.005)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  ref
                      .read(settingsProvider.notifier)
                      .update((x) => x.copyWith(vocabRetention: best));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t.retentionApplied((best * 100).round())),
                    ),
                  );
                },
                child: Text(t.retentionApply((best * 100).round())),
              ),
            ),
        ],
      ),
    );
  }
}
