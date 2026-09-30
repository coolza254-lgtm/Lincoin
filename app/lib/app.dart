import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
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
      home: const AppShell(),
    );
  }
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(updateControllerProvider.notifier).autoCheck(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          PracticeScreen(),
          StatsScreen(),
          ShopScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
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
    );
  }
}
