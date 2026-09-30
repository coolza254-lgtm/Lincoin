import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../state/update_controller.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import 'backup_screen.dart';
import 'credits_screen.dart';
import 'updates_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    final updateDot = ref.watch(updateControllerProvider).hasUpdate;

    Widget card(List<Widget> children) => LcCard(
      padding: const EdgeInsets.symmetric(vertical: LcTokens.spacingSm),
      child: Column(children: children),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingLg,
          0,
          LcTokens.spacingLg,
          LcTokens.spacingXxl,
        ),
        children: [
          SectionLabel(t.sectionStudy),
          card([
            _SliderTile(
              title: t.targetRetention,
              help: t.targetRetentionHelp,
              value: s.vocabRetention,
              min: 0.80,
              max: 0.95,
              divisions: 15,
              label: '${(s.vocabRetention * 100).round()}%',
              onChanged: (v) => set.update(
                (x) => x.copyWith(vocabRetention: (v * 100).round() / 100),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            _SliderTile(
              title: t.newPerDay,
              help: t.newPerDayHelp,
              value: s.vocabNewPerDay.toDouble(),
              min: 0,
              max: AppSettings.newPerDayMax.toDouble(),
              divisions: AppSettings.newPerDayMax,
              label: '${s.vocabNewPerDay}',
              onChanged: (v) =>
                  set.update((x) => x.copyWith(vocabNewPerDay: v.round())),
            ),
            const Divider(indent: 16, endIndent: 16),
            const Divider(indent: 16, endIndent: 16),
            _SliderTile(
              title: t.targetRetentionGrammar,
              help: t.targetRetentionHelp,
              value: s.grammarRetention,
              min: 0.80,
              max: 0.95,
              divisions: 15,
              label: '${(s.grammarRetention * 100).round()}%',
              onChanged: (v) => set.update(
                (x) => x.copyWith(grammarRetention: (v * 100).round() / 100),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            _SliderTile(
              title: t.newPerDayGrammar,
              help: t.newPerDayGrammarHelp,
              value: s.grammarNewPerDay.toDouble(),
              min: 0,
              max: AppSettings.grammarNewPerDayMax.toDouble(),
              divisions: AppSettings.grammarNewPerDayMax,
              label: '${s.grammarNewPerDay}',
              onChanged: (v) =>
                  set.update((x) => x.copyWith(grammarNewPerDay: v.round())),
            ),
            const Divider(indent: 16, endIndent: 16),
            SwitchListTile(
              title: Text(t.includeKana),
              subtitle: Text(t.includeKanaHelp),
              value: s.includeKana,
              onChanged: (v) => set.update((x) => x.copyWith(includeKana: v)),
            ),
            ListTile(
              title: Text(t.furiganaMode),
              subtitle: Text(switch (s.furigana) {
                FuriganaMode.always => t.furiganaAlways,
                FuriganaMode.hideMastered => t.furiganaHideMastered,
                FuriganaMode.never => t.furiganaNever,
              }),
              onTap: () async {
                final v = await _choose<FuriganaMode>(context, t.furiganaMode, {
                  FuriganaMode.always: t.furiganaAlways,
                  FuriganaMode.hideMastered: t.furiganaHideMastered,
                  FuriganaMode.never: t.furiganaNever,
                }, s.furigana);
                if (v != null) set.update((x) => x.copyWith(furigana: v));
              },
            ),
            ListTile(
              title: Text(t.dayStart),
              subtitle: Text(t.dayStartHelp(s.dayStartHour)),
              onTap: () async {
                final v = await _choose<int>(context, t.dayStart, {
                  for (var h = 0; h <= 6; h++) h: '0$h:00',
                }, s.dayStartHour);
                if (v != null) set.update((x) => x.copyWith(dayStartHour: v));
              },
            ),
          ]),
          SectionLabel(t.sectionLook),
          card([
            Padding(
              padding: const EdgeInsets.all(LcTokens.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.theme, style: tt.bodyLarge),
                  const SizedBox(height: LcTokens.spacingMd),
                  Wrap(
                    spacing: LcTokens.spacingMd,
                    runSpacing: LcTokens.spacingMd,
                    children: [
                      for (final p in LcTokens.themes.values)
                        _ThemeSwatch(
                          palette: p,
                          selected: p.id == s.theme,
                          onTap: () =>
                              set.update((x) => x.copyWith(theme: p.id)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: Text(t.reduceMotion),
              value: s.reduceMotion,
              onChanged: (v) => set.update((x) => x.copyWith(reduceMotion: v)),
            ),
          ]),
          SectionLabel(t.sectionApp),
          card([
            ListTile(
              leading: Badge(
                isLabelVisible: updateDot,
                backgroundColor: context.lc.accent,
                child: const Icon(Icons.system_update_rounded),
              ),
              title: Text(t.updates),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UpdatesScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: Text(t.backup),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded),
              title: Text(t.credits),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CreditsScreen())),
            ),
          ]),
        ],
      ),
    );
  }

  static Future<T?> _choose<T>(
    BuildContext context,
    String title,
    Map<T, String> options,
    T current,
  ) => showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => SafeArea(
      child: RadioGroup<T>(
        groupValue: current,
        onChanged: (v) => Navigator.pop(ctx, v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: LcTokens.spacingSm),
            for (final e in options.entries)
              RadioListTile<T>(value: e.key, title: Text(e.value)),
            const SizedBox(height: LcTokens.spacingLg),
          ],
        ),
      ),
    ),
  );
}

class _SliderTile extends StatelessWidget {
  final String title;
  final String help;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.help,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: tt.bodyLarge)),
              Text(
                label,
                style: tt.titleMedium?.copyWith(color: context.lc.accent),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
          ),
          Text(help, style: tt.bodySmall),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final LcPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    return Semantics(
      selected: selected,
      button: true,
      label: palette.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LcTokens.radiusControl),
        child: Container(
          width: 88,
          padding: const EdgeInsets.all(LcTokens.spacingSm),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(LcTokens.radiusControl),
            border: Border.all(
              color: selected ? c.accent : c.line,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final col in [
                    palette.accent,
                    palette.coin,
                    palette.good,
                  ])
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                palette.name,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: palette.ink),
                maxLines: 2,
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 16, color: palette.ink),
            ],
          ),
        ),
      ),
    );
  }
}
