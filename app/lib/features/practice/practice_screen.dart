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
import '../../ui/input.dart';

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

/// Tab 2: unlimited practice (docs/05-modes.md). Challenges are hidden
/// until they are ready.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final o = ref.watch(practiceOverviewProvider);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('practice'),
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          LcTokens.spacingMd,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [
          Text(t.tabPractice, style: tt.headlineMedium),
          const SizedBox(height: LcTokens.spacingLg),
          const SizedBox(height: LcTokens.spacingLg),
          if (o == null)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: t.noContentTitle,
            )
          else
            _PracticePanel(o),
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
            child: PressFilledButton(
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
