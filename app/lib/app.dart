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
import 'ui/input.dart';
import 'ui/theme.dart';
import 'ui/tokens.g.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

class LincoinApp extends ConsumerWidget {
  const LincoinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final palette =
        LcTokens.themes[s.theme] ?? LcTokens.themes[LcTokens.defaultTheme]!;
    Feel.haptics = s.haptics;
    Pad.enabled = s.controller;
    Pad.swapAB = s.swapAB;
    Pad.quickAnswer = s.quickAnswerButtons;
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      // With animations off, widgets that follow the platform setting (page
      // transitions, ripples, scrolling glow) also stay still.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemBars(palette.dark),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: s.reduceMotion),
          child: _ControllerKeys(
            enabled: s.controller,
            swapAB: s.swapAB,
            child: child!,
          ),
        ),
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

/// Game-controller keys for the whole app. Directional pad and the confirm
/// button work through Flutter's default focus shortcuts; this adds the back
/// button and, for a Nintendo-style layout, swaps confirm and back.
class _ControllerKeys extends StatelessWidget {
  final bool enabled;
  final bool swapAB;
  final Widget child;
  const _ControllerKeys({
    required this.enabled,
    required this.swapAB,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (node, e) {
      if (!enabled || e is! KeyDownEvent) return KeyEventResult.ignored;
      if (e.logicalKey == Pad.back(swapAB)) {
        _navigatorKey.currentState?.maybePop();
        return KeyEventResult.handled;
      }
      if (swapAB && e.logicalKey == Pad.confirm(true)) {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx != null) Actions.maybeInvoke(ctx, const ActivateIntent());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
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

  void _select(int i) {
    if (i != _tab) Feel.selection();
    setState(() => _tab = i);
  }

  /// Shoulder buttons (and Tab on a keyboard with Ctrl) switch tabs.
  KeyEventResult _tabKeys(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || !Pad.enabled) return KeyEventResult.ignored;
    final step = switch (e.logicalKey) {
      LogicalKeyboardKey.gameButtonLeft1 => -1,
      LogicalKeyboardKey.gameButtonRight1 => 1,
      _ => 0,
    };
    if (step == 0) {
      // Nothing focused yet: the first arrow press enters the page.
      if (node.hasPrimaryFocus &&
          (e.logicalKey == LogicalKeyboardKey.arrowDown ||
              e.logicalKey == LogicalKeyboardKey.arrowUp ||
              e.logicalKey == LogicalKeyboardKey.arrowLeft ||
              e.logicalKey == LogicalKeyboardKey.arrowRight)) {
        node.nextFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    _select((_tab + step) % 4);
    return KeyEventResult.handled;
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
      child: Focus(
        // Holds focus when nothing else has it, so controller keys still
        // reach the shell.
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _tabKeys,
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
            onDestinationSelected: _select,
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
      ),
    );
  }
}
