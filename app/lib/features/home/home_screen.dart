import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../state/update_controller.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
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
    final plan = ref.watch(todayPlanProvider);
    final balance = ref.watch(balanceProvider);
    final coverage = ref.watch(coverageProvider);
    final updateDot = ref.watch(updateControllerProvider).hasUpdate;

    return SafeArea(
      child: ListView(
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
          else if (plan != null) ...[
            LcCard(
              large: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.style_rounded, color: c.accent),
                      const SizedBox(width: LcTokens.spacingSm),
                      Text(t.vocabDeck, style: tt.titleLarge),
                    ],
                  ),
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
                                builder: (_) => const StudyScreen(),
                              ),
                            ),
                      child: Text(plan.isEmpty ? t.allDoneToday : t.startStudy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LcTokens.spacingLg),
            LcCard(
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: c.muted),
                  const SizedBox(width: LcTokens.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.grammarDeck, style: tt.titleMedium),
                        Text(t.comingInPhase(6), style: tt.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionLabel(t.coverageTitle),
            LcCard(
              child: Column(
                children: [
                  for (final e in coverage.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              levelName(t, e.key),
                              style: tt.labelLarge,
                            ),
                          ),
                          Expanded(child: LcProgressBar(e.value)),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '${(e.value * 100).toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style: tt.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
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
