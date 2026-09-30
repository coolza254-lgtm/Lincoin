import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/practice/practice_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/stats/stats_screen.dart';
import 'l10n/app_localizations.dart';
import 'state/providers.dart';
import 'state/update_controller.dart';
import 'ui/theme.dart';
import 'ui/tokens.g.dart';

class LincoinApp extends ConsumerWidget {
  const LincoinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final palette =
        LcTokens.themes[s.theme] ?? LcTokens.themes[LcTokens.defaultTheme]!;
    return MaterialApp(
      title: 'Lincoin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(palette, reduceMotion: s.reduceMotion),
      locale: const Locale('th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Status and navigation bar icons follow the theme; the app draws
      // edge to edge behind both bars.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemBars(palette.dark),
        child: child!,
      ),
      home: const AppShell(),
    );
  }

  static SystemUiOverlayStyle _systemBars(bool dark) => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Four tabs: home, practice & challenge, stats, shop (docs/09-ui-ux.md).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Daily online check (if enabled); only shows a dot, never installs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Skill challenges left open (app closed mid-round) are forfeited;
      // weekly challenges are settled from the days already cleared.
      final ch = ref.read(challengeServiceProvider);
      if (ch != null) {
        final n = ch.forfeitAbandoned() + ch.settleWeekly().length;
        if (n > 0) ref.read(dataVersionProvider.notifier).bump();
      }
      ref.read(updateControllerProvider.notifier).autoCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final onboarded = ref.watch(userDbProvider).meta(onboardedKey) != null;
    if (!onboarded) {
      return OnboardingScreen(onDone: () => setState(() {}));
    }
    // Back on another tab returns to the home tab before leaving the app.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        // Only the visible tab is built, so hidden tabs do not recompute
        // their data after every change. Each tab's list keeps its scroll
        // position (PageStorageKey) when you come back to it.
        body: AnimatedSwitcher(
          duration: context.motionFast,
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: switch (_tab) {
              1 => const PracticeScreen(),
              2 => const StatsScreen(),
              3 => const ShopScreen(),
              _ => const HomeScreen(),
            },
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            if (i != _tab) HapticFeedback.selectionClick();
            setState(() => _tab = i);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: t.tabHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bolt_outlined),
              selectedIcon: const Icon(Icons.bolt_rounded),
              label: t.tabPractice,
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights_rounded),
              label: t.tabStats,
            ),
            NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront_rounded),
              label: t.tabShop,
            ),
          ],
        ),
      ),
    );
  }
}
