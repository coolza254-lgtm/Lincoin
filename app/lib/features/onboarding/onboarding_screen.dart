import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';

const onboardedKey = 'onboarded';

/// First run: what the app is, where to start, how much per day.
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _kana = true;
  int _perDay = 10;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pages.nextPage(
        duration: context.motionNormal,
        curve: Curves.easeOutCubic,
      );
    } else {
      ref
          .read(settingsProvider.notifier)
          .update(
            (s) => s.copyWith(includeKana: _kana, vocabNewPerDay: _perDay),
          );
      ref.read(userDbProvider).setMeta(onboardedKey, '1');
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;

    Widget option({
      required bool selected,
      required String title,
      required String body,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
      child: Semantics(
        selected: selected,
        button: true,
        child: LcCard(
          onTap: onTap,
          color: selected ? c.accentSoft : null,
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? c.accent : c.muted,
              ),
              const SizedBox(width: LcTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tt.titleMedium),
                    Text(body, style: tt.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget bullet(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingLg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(LcTokens.radiusControl),
            ),
            child: Icon(icon, color: c.accent),
          ),
          const SizedBox(width: LcTokens.spacingLg),
          Expanded(child: Text(text, style: tt.bodyLarge)),
        ],
      ),
    );

    final pages = [
      ListView(
        padding: const EdgeInsets.all(LcTokens.spacingXl),
        children: [
          const SizedBox(height: LcTokens.spacingXl),
          Center(
            child: Image.asset(
              'assets/brand/symbol.png',
              width: 120,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: LcTokens.spacingLg),
          Text(
            t.welcomeTitle,
            style: tt.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LcTokens.spacingXxl),
          bullet(Icons.event_repeat_rounded, t.welcome1),
          bullet(Icons.card_giftcard_rounded, t.welcome2),
          bullet(Icons.favorite_border_rounded, t.welcome3),
        ],
      ),
      ListView(
        padding: const EdgeInsets.all(LcTokens.spacingXl),
        children: [
          const SizedBox(height: LcTokens.spacingXl),
          Text(t.onbKanaTitle, style: tt.headlineMedium),
          const SizedBox(height: LcTokens.spacingXl),
          option(
            selected: _kana,
            title: t.onbKanaYes,
            body: t.onbKanaYesBody,
            onTap: () => setState(() => _kana = true),
          ),
          option(
            selected: !_kana,
            title: t.onbKanaNo,
            body: t.onbKanaNoBody,
            onTap: () => setState(() => _kana = false),
          ),
        ],
      ),
      ListView(
        padding: const EdgeInsets.all(LcTokens.spacingXl),
        children: [
          const SizedBox(height: LcTokens.spacingXl),
          Text(t.onbPaceTitle, style: tt.headlineMedium),
          const SizedBox(height: LcTokens.spacingSm),
          Text(t.onbPaceBody, style: tt.bodyMedium?.copyWith(color: c.muted)),
          const SizedBox(height: LcTokens.spacingXl),
          for (final (n, title, minutes) in [
            (5, t.paceLight, 10),
            (10, t.paceNormal, 20),
            (20, t.paceIntense, 40),
          ])
            option(
              selected: _perDay == n,
              title: '$title · ${t.cardsPerDay(n)}',
              body: t.paceMinutes(minutes),
              onTap: () => setState(() => _perDay = n),
            ),
          Text(t.onbChangeLater, style: tt.bodySmall),
        ],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LcTokens.spacingXl,
                0,
                LcTokens.spacingXl,
                LcTokens.spacingLg,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        AnimatedContainer(
                          duration: context.motionFast,
                          width: i == _page ? 20 : 8,
                          height: 8,
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: i == _page ? c.accent : c.track,
                            borderRadius: BorderRadius.circular(
                              LcTokens.radiusPill,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: LcTokens.spacingLg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_page < 2 ? t.next : t.letsStart),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
