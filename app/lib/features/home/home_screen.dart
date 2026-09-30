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
import '../settings/settings_screen.dart';
import '../settings/updates_screen.dart';
import '../study/study_screen.dart';

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
    final balance = ref.watch(balanceProvider);
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
              Text('Lincoin', style: tt.titleLarge),
              const Spacer(),
              CoinChip(balance, large: true),
              const SizedBox(width: LcTokens.spacingXs),
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
                action: FilledButton(
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
              child: FilledButton(
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
                bg: streak.today ? c.coinSoft : c.track,
                fg: streak.today ? c.coin : c.muted,
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
          if (today.coins > 0) CoinChip(today.coins, signed: true),
        ],
      ),
    );
  }
}
