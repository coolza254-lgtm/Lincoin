import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';

/// Placeholder until practice and challenge modes arrive (phase 5).
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    Widget row(IconData i, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, color: c.accent),
          const SizedBox(width: LcTokens.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleMedium),
                Text(body, style: tt.bodyMedium?.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
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
          LcCard(
            large: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LcPill(t.comingInPhase(5), icon: Icons.construction_rounded),
                const SizedBox(height: LcTokens.spacingLg),
                row(
                  Icons.all_inclusive_rounded,
                  t.practiceTitle,
                  t.practiceBody,
                ),
                row(
                  Icons.emoji_events_outlined,
                  t.challengeTitle,
                  t.challengeBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
