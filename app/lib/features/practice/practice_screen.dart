import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/challenge_service.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import 'drill_controller.dart';
import 'drill_screen.dart';

class PracticeOverview {
  final int items;
  final int weak;
  final int recent;
  final int todayCoins;
  final double rate;
  final List<ChallengeRecord> active;
  final List<ChallengeRecord> history;
  final Map<String, int> weeklyProgress;

  const PracticeOverview({
    required this.items,
    required this.weak,
    required this.recent,
    required this.todayCoins,
    required this.rate,
    required this.active,
    required this.history,
    required this.weeklyProgress,
  });
}

final practiceOverviewProvider = Provider<PracticeOverview?>((ref) {
  ref.watch(dataVersionProvider);
  final p = ref.watch(practiceServiceProvider);
  final ch = ref.watch(challengeServiceProvider);
  if (p == null || ch == null) return null;
  final pool = p.pool();
  final (coins, rate) = p.todayPractice();
  final active = ch.active();
  return PracticeOverview(
    items: pool.length,
    weak: pool.where((i) => i.weak).length,
    recent: pool.where((i) => i.recent).length,
    todayCoins: coins,
    rate: rate,
    active: active,
    history: ch.history(limit: 10).where((c) => !c.active).toList(),
    weeklyProgress: {
      for (final c in active)
        if (c.type == ChallengeType.weekly) c.id: ch.weeklyProgress(c),
    },
  );
});

String tierName(AppLocalizations t, String tier) => switch (tier) {
  'easy' => t.tierEasy,
  'normal' => t.tierNormal,
  'hard' => t.tierHard,
  _ => t.tierBrutal,
};

String challengeTitle(AppLocalizations t, ChallengeType type) => switch (type) {
  ChallengeType.speed => t.chSpeed,
  ChallengeType.streak => t.chStreak,
  ChallengeType.weak => t.chWeak,
  ChallengeType.weekly => t.chWeekly,
};

String challengeRule(AppLocalizations t, ChallengeType type, int n) =>
    switch (type) {
      ChallengeType.speed => t.chSpeedRule(n),
      ChallengeType.streak => t.chStreakRule(n),
      ChallengeType.weak => t.chWeakRule(n),
      ChallengeType.weekly => t.chWeeklyRule(n),
    };

IconData challengeIcon(ChallengeType type) => switch (type) {
  ChallengeType.speed => Icons.timer_outlined,
  ChallengeType.streak => Icons.local_fire_department_outlined,
  ChallengeType.weak => Icons.gps_fixed_rounded,
  ChallengeType.weekly => Icons.calendar_month_outlined,
};

/// Tab 2: unlimited practice and Lincoin challenges (docs/05-modes.md).
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final o = ref.watch(practiceOverviewProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          LcTokens.spacingMd,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [
          Text(t.tabPractice, style: tt.headlineMedium),
          const SizedBox(height: LcTokens.spacingLg),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(t.practiceTitle),
                icon: const Icon(Icons.all_inclusive_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text(t.challengeTitle),
                icon: const Icon(Icons.emoji_events_outlined),
              ),
            ],
            selected: {_segment},
            onSelectionChanged: (s) => setState(() => _segment = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: LcTokens.spacingLg),
          if (o == null)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: t.noContentTitle,
            )
          else if (_segment == 0)
            _PracticePanel(o)
          else
            _ChallengePanel(o),
        ],
      ),
    );
  }
}

class _PracticePanel extends ConsumerWidget {
  final PracticeOverview o;
  const _PracticePanel(this.o);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final ready = o.items >= 4;
    return LcCard(
      large: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.practiceBody, style: tt.bodyMedium?.copyWith(color: c.muted)),
          const SizedBox(height: LcTokens.spacingLg),
          Row(
            children: [
              Expanded(child: StatTile('${o.items}', t.learnedItems)),
              Expanded(child: StatTile('${o.weak}', t.weakItems)),
              Expanded(child: StatTile('${o.recent}', t.recentItems)),
            ],
          ),
          const SizedBox(height: LcTokens.spacingLg),
          Row(
            children: [
              CoinChip(o.todayCoins),
              const SizedBox(width: LcTokens.spacingSm),
              Expanded(
                child: Text(
                  t.practiceRate((o.rate * 100).round()),
                  style: tt.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: LcTokens.spacingLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ready
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) =>
                            const DrillScreen(config: DrillConfig.practice()),
                      ),
                    )
                  : null,
              child: Text(ready ? t.startPractice : t.practiceNeedsItems),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengePanel extends ConsumerWidget {
  final PracticeOverview o;
  const _ChallengePanel(this.o);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    if (o.items < ChallengeService.minItemsToUnlock) {
      return LcCard(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: t.challengeLocked(ChallengeService.minItemsToUnlock),
          body: t.challengeLockedBody(o.items),
        ),
      );
    }
    final weekly = o.active
        .where((a) => a.type == ChallengeType.weekly)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.challengeBody, style: tt.bodyMedium?.copyWith(color: c.muted)),
        const SizedBox(height: LcTokens.spacingLg),
        if (weekly != null) ...[
          LcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(challengeIcon(weekly.type), color: c.accent),
                    const SizedBox(width: LcTokens.spacingSm),
                    Expanded(child: Text(t.chWeekly, style: tt.titleMedium)),
                    LcPill(tierName(t, weekly.tier)),
                  ],
                ),
                const SizedBox(height: LcTokens.spacingMd),
                LcProgressBar(
                  (o.weeklyProgress[weekly.id] ?? 0) / weekly.threshold,
                ),
                const SizedBox(height: LcTokens.spacingSm),
                Text(
                  t.weeklyProgress(
                    o.weeklyProgress[weekly.id] ?? 0,
                    weekly.threshold,
                    weekly.payout,
                  ),
                  style: tt.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: LcTokens.spacingMd),
        ],
        for (final type in ChallengeType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
            child: LcCard(
              onTap: type == ChallengeType.weekly && weekly != null
                  ? null
                  : () => showChallengeSetup(context, ref, type),
              child: Row(
                children: [
                  Icon(challengeIcon(type), color: c.accent, size: 28),
                  const SizedBox(width: LcTokens.spacingLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(challengeTitle(t, type), style: tt.titleMedium),
                        Text(
                          challengeRule(t, type, type.fallback['normal']!),
                          style: tt.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        if (o.history.isNotEmpty) ...[
          SectionLabel(t.challengeHistory),
          LcCard(
            padding: const EdgeInsets.symmetric(vertical: LcTokens.spacingSm),
            child: Column(
              children: [
                for (final h in o.history)
                  ListTile(
                    leading: Icon(challengeIcon(h.type)),
                    title: Text(
                      '${challengeTitle(t, h.type)} · ${tierName(t, h.tier)}',
                    ),
                    subtitle: Text(
                      t.historyLine((h.score ?? 0).toInt(), h.threshold),
                    ),
                    trailing: CoinChip(
                      h.result == 'won' ? h.payout - h.stake : -h.stake,
                      signed: true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Tier, threshold and stake, then start.
Future<void> showChallengeSetup(
  BuildContext context,
  WidgetRef ref,
  ChallengeType type,
) async {
  final t = AppLocalizations.of(context);
  final svc = ref.read(challengeServiceProvider)!;
  var tier = 'normal';
  var stake = 0;
  final record = await showModalBottomSheet<ChallengeRecord>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final tt = Theme.of(ctx).textTheme;
        final c = ctx.lc;
        final balance = ref.read(balanceProvider);
        final o = svc.offer(type, tier, balance);
        if (o.affordable) {
          stake = stake.clamp(o.minStake, o.maxStake);
        }
        final divisions = ((o.maxStake - o.minStake) / 10).floor();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingXl,
            0,
            LcTokens.spacingXl,
            LcTokens.spacingXl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(challengeIcon(type), color: c.accent),
                  const SizedBox(width: LcTokens.spacingSm),
                  Text(challengeTitle(t, type), style: tt.titleLarge),
                ],
              ),
              const SizedBox(height: LcTokens.spacingLg),
              Wrap(
                spacing: LcTokens.spacingSm,
                runSpacing: LcTokens.spacingSm,
                children: [
                  for (final id in const ['easy', 'normal', 'hard', 'brutal'])
                    ChoiceChip(
                      label: Text(
                        '${tierName(t, id)} ${svc.offer(type, id, balance).multiplier}×',
                      ),
                      selected: tier == id,
                      onSelected: (_) => setState(() => tier = id),
                    ),
                ],
              ),
              const SizedBox(height: LcTokens.spacingLg),
              LcCard(
                color: c.bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.toWin, style: tt.bodySmall),
                    Text(
                      challengeRule(t, type, o.threshold),
                      style: tt.titleMedium,
                    ),
                    if (o.calibrating)
                      Text(t.calibratingNote, style: tt.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: LcTokens.spacingLg),
              if (!o.affordable)
                Text(t.stakeTooLow(o.minStake), style: tt.bodyMedium)
              else ...[
                Row(
                  children: [
                    Text(t.stake, style: tt.bodyLarge),
                    const Spacer(),
                    CoinChip(stake),
                  ],
                ),
                if (divisions > 0)
                  Slider(
                    value: stake.toDouble(),
                    min: o.minStake.toDouble(),
                    max: o.maxStake.toDouble(),
                    divisions: divisions,
                    onChanged: (v) => setState(() => stake = v.round()),
                  ),
                Text(
                  t.stakeSummary(
                    (stake * o.multiplier).round(),
                    stake,
                    o.maxStake,
                  ),
                  style: tt.bodySmall,
                ),
              ],
              const SizedBox(height: LcTokens.spacingLg),
              FilledButton(
                onPressed: o.affordable
                    ? () {
                        try {
                          Navigator.pop(ctx, svc.start(o, stake));
                        } on StateError catch (e) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    : null,
                child: Text(t.startChallenge),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (record == null) return;
  ref.read(dataVersionProvider.notifier).bump();
  if (!context.mounted) return;
  if (record.type == ChallengeType.weekly) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.weeklyStarted)));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => DrillScreen(config: DrillConfig.challenge(record)),
    ),
  );
}
