import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../state/update_controller.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../grammar/grammar_lesson.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/updates_screen.dart';
import '../study/study_screen.dart';
import '../../ui/input.dart';

String levelName(AppLocalizations t, String level) =>
    level == 'kana' ? t.levelKana : level.toUpperCase();

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final catalog = ref.watch(catalogProvider);
    final vocabCov = ref.watch(coverageProvider(vocabDeck));
    final grammarCov = ref.watch(coverageProvider(grammarDeck));
    final updateDot = ref.watch(updateControllerProvider).hasUpdate;

    Widget covRow(String label, double v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: tt.labelLarge)),
          Expanded(child: LcProgressBar(v)),
          SizedBox(
            width: 52,
            child: Text(
              '${(v * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: tt.labelLarge,
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: ListView(
        key: const PageStorageKey('home'),
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          LcTokens.spacingMd,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [
          Row(
            children: [
              Image.asset(
                'assets/brand/symbol.png',
                width: 36,
                height: 36,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: LcTokens.spacingSm),
              Expanded(
                child: Text(
                  'Lincoin',
                  style: tt.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
              IconButton(
                tooltip: t.settings,
                icon: Badge(
                  isLabelVisible: updateDot,
                  backgroundColor: c.accent,
                  child: const Icon(Icons.settings_outlined),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: LcTokens.spacingXl),
          if (catalog == null)
            LcCard(
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: t.noContentTitle,
                body: t.noContentBody,
                action: PressFilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpdatesScreen()),
                  ),
                  child: Text(t.goToUpdates),
                ),
              ),
            )
          else ...[
            const _TodayStrip(),
            const _DeckCard(deck: vocabDeck, large: true),
            const _LevelList(),
            const SizedBox(height: LcTokens.spacingLg),
            const _DeckCard(deck: grammarDeck),
            SectionLabel(t.coverageTitle),
            LcCard(
              child: Column(
                children: [
                  for (final e in vocabCov.entries)
                    covRow(levelName(t, e.key), e.value),
                  for (final e in grammarCov.entries)
                    covRow(t.grammarLevel(e.key.toUpperCase()), e.value),
                  const SizedBox(height: LcTokens.spacingSm),
                  Text(t.coverageHelp, style: tt.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's due/new counts and the start button for one deck.
class _DeckCard extends ConsumerWidget {
  final String deck;
  final bool large;
  const _DeckCard({required this.deck, this.large = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final plan = ref.watch(todayPlanProvider(deck));
    final grammar = deck == grammarDeck;
    final hasItems =
        ref.watch(catalogProvider)?.itemsOf(deck).isNotEmpty ?? false;
    return LcCard(
      large: large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                grammar ? Icons.menu_book_rounded : Icons.style_rounded,
                color: c.accent,
              ),
              const SizedBox(width: LcTokens.spacingSm),
              Expanded(
                child: Text(
                  grammar ? t.grammarDeck : t.vocabDeck,
                  style: tt.titleLarge,
                ),
              ),
              if (grammar && hasItems)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GrammarListScreen(),
                    ),
                  ),
                  child: Text(t.seeAllGrammar),
                ),
            ],
          ),
          if (!hasItems)
            Padding(
              padding: const EdgeInsets.only(top: LcTokens.spacingSm),
              child: Text(t.noGrammarYet, style: tt.bodySmall),
            )
          else if (plan != null) ...[
            const SizedBox(height: LcTokens.spacingLg),
            if (large)
              _TodayRing(
                done: ref.watch(todayDoneProvider(deck)),
                due: plan.dueCount,
                fresh: plan.newCount,
                minutes: plan.estimatedMinutes,
              )
            else
              Row(
                children: [
                  Expanded(child: StatTile('${plan.dueCount}', t.dueLabel)),
                  Expanded(child: StatTile('${plan.newCount}', t.newLabel)),
                  Expanded(
                    child: StatTile(
                      plan.isEmpty ? '–' : '~${plan.estimatedMinutes}',
                      t.minutesLabel,
                    ),
                  ),
                ],
              ),
            if (plan.queue.newCardsPausedForBacklog) ...[
              const SizedBox(height: LcTokens.spacingMd),
              LcPill(
                t.newPausedBacklog,
                bg: c.warnSoft,
                fg: c.warn,
                icon: Icons.info_outline_rounded,
              ),
            ],
            const SizedBox(height: LcTokens.spacingLg),
            SizedBox(
              width: double.infinity,
              child: PressFilledButton(
                onPressed: plan.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => StudyScreen(deck: deck),
                        ),
                      ),
                child: Text(plan.isEmpty ? t.allDoneToday : t.startStudy),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's progress as a ring (done of done + left), with what is left.
class _TodayRing extends StatelessWidget {
  final int done;
  final int due;
  final int fresh;
  final int minutes;
  const _TodayRing({
    required this.done,
    required this.due,
    required this.fresh,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final total = done + due + fresh;
    final v = total == 0 ? 1.0 : done / total;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.muted),
          const SizedBox(width: LcTokens.spacingSm),
          Expanded(child: Text(text, style: tt.bodyLarge)),
        ],
      ),
    );
    return Row(
      children: [
        SizedBox(
          width: 104,
          height: 104,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: context.motionNormal * 2,
            curve: Curves.easeOutCubic,
            builder: (context, x, _) => Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: x,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: c.track,
                  color: total > 0 && done >= total ? c.good : c.accent,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$done', style: tt.headlineMedium),
                      Text(t.ringOf(total), style: tt.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: LcTokens.spacingXl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.todayTitle, style: tt.titleMedium),
              const SizedBox(height: LcTokens.spacingXs),
              line(Icons.replay_rounded, t.ringDue(due)),
              line(Icons.auto_awesome_rounded, t.ringNew(fresh)),
              line(
                Icons.schedule_rounded,
                due + fresh == 0 ? t.allDoneToday : t.ringMinutes(minutes),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Every vocabulary level, N5 → N1, each with its own session.
class _LevelList extends ConsumerWidget {
  const _LevelList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final progress = ref.watch(levelProgressProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(t.levelsTitle),
        LcCard(
          padding: const EdgeInsets.symmetric(vertical: LcTokens.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LcTokens.spacingLg,
                  LcTokens.spacingSm,
                  LcTokens.spacingLg,
                  LcTokens.spacingXs,
                ),
                child: Text(t.levelsHelp, style: tt.bodySmall),
              ),
              for (final level in vocabLevels)
                _LevelRow(level: level, progress: progress[level]),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelRow extends ConsumerWidget {
  final String level;
  final ({int learned, int total})? progress;
  const _LevelRow({required this.level, required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final total = progress?.total ?? 0;
    final learned = progress?.learned ?? 0;
    final key = studyKey(vocabDeck, level);
    final plan = total == 0 ? null : ref.watch(todayPlanProvider(key));
    final open = plan != null && !plan.isEmpty;
    void play() => Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyScreen(deck: key),
      ),
    );
    final kana = level == 'kana';
    return InkWell(
      onTap: open ? play : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LcTokens.spacingLg,
          vertical: LcTokens.spacingMd,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: total == 0 ? c.track : c.accentSoft,
                borderRadius: BorderRadius.circular(LcTokens.radiusControl),
              ),
              child: Text(
                kana ? 'あ' : level.toUpperCase(),
                style: kana
                    ? jpStyle(24, 700, c.accent)
                    : tt.titleMedium?.copyWith(
                        color: total == 0 ? c.muted : c.accent,
                        fontWeight: FontWeight.w800,
                      ),
              ),
            ),
            const SizedBox(width: LcTokens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kana ? t.levelKana : 'JLPT ${level.toUpperCase()}',
                    style: tt.titleMedium,
                  ),
                  if (total == 0)
                    Text(t.levelSoon, style: tt.bodySmall)
                  else ...[
                    const SizedBox(height: 6),
                    LcProgressBar(learned / total, height: 6),
                    const SizedBox(height: 4),
                    Text(
                      '${t.levelWords(learned, total)}'
                      '${plan == null ? '' : ' · ${t.levelDueNew(plan.dueCount, plan.newCount)}'}',
                      style: tt.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LcTokens.spacingMd),
            if (total > 0)
              IconButton(
                tooltip: t.levelWordsList,
                icon: const Icon(Icons.list_alt_rounded),
                color: c.muted,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LibraryScreen(level: level),
                  ),
                ),
              ),
            if (total > 0)
              open
                  ? PressScale(
                      child: IconButton.filled(
                        tooltip: t.levelPlay,
                        onPressed: play,
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    )
                  : Tooltip(
                      message: t.levelDone,
                      child: Icon(Icons.check_circle_rounded, color: c.good),
                    ),
          ],
        ),
      ),
    );
  }
}

/// Streak and what was done today, above the decks.
class _TodayStrip extends ConsumerWidget {
  const _TodayStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final today = ref.watch(todaySummaryProvider);
    final streak = ref.watch(streakProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingLg),
      child: Row(
        children: [
          if (streak.days > 0) ...[
            Tooltip(
              message: streak.today ? t.streakHelp : t.streakKeep,
              child: LcPill(
                t.streakDays(streak.days),
                icon: Icons.local_fire_department_rounded,
                bg: streak.today ? c.warnSoft : c.track,
                fg: streak.today ? c.warn : c.muted,
              ),
            ),
            const SizedBox(width: LcTokens.spacingMd),
          ],
          Expanded(
            child: Text(
              today.any
                  ? t.todaySummary(today.reviews + today.practice)
                  : (streak.days > 0 ? t.streakKeep : t.todayNotYet),
              style: tt.bodyMedium?.copyWith(color: c.muted),
            ),
          ),
        ],
      ),
    );
  }
}
