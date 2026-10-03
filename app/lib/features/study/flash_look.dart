import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';

/// Opens [FlashLookPanel] as a sheet over the flashcard (changes apply
/// live behind it).
Future<void> showFlashLook(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (_, scroll) => FlashLookPanel(controller: scroll),
  ),
);

/// Which parts of the flashcard screen are shown, and full screen.
class FlashLookPanel extends ConsumerWidget {
  final ScrollController? controller;

  /// Inside the settings list: no own scrolling.
  final bool embedded;
  const FlashLookPanel({super.key, this.controller, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    String label(FlashPart p) => switch (p) {
      FlashPart.progressBar => t.partProgressBar,
      FlashPart.cardsLeft => t.partCardsLeft,
      FlashPart.levelTag => t.partLevelTag,
      FlashPart.frontHint => t.partFrontHint,
      FlashPart.furigana => t.partFurigana,
      FlashPart.partOfSpeech => t.partPartOfSpeech,
      FlashPart.moreMeanings => t.partMoreMeanings,
      FlashPart.example => t.partExample,
      FlashPart.exampleTranslation => t.partExampleTranslation,
      FlashPart.ratingHelp => t.partRatingHelp,
      FlashPart.intervals => t.partIntervals,
      FlashPart.progressLink => t.partProgressLink,
    };
    final children = <Widget>[
      SwitchListTile(
        secondary: const Icon(Icons.fullscreen_rounded),
        title: Text(t.flashFullscreen),
        subtitle: Text(t.flashFullscreenHelp),
        value: s.flashFullscreen,
        onChanged: (v) => set.update((x) => x.copyWith(flashFullscreen: v)),
      ),
      if (!embedded)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingLg,
            LcTokens.spacingMd,
            LcTokens.spacingLg,
            0,
          ),
          child: SectionLabel(t.flashShow),
        ),
      for (final p in FlashPart.values)
        SwitchListTile(
          dense: true,
          title: Text(label(p)),
          value: s.shows(p),
          onChanged: (v) => set.update((x) => x.withPart(p, v)),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(LcTokens.spacingSm),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(t.flashShowAll),
            onPressed: s.flashHidden.isEmpty
                ? null
                : () => set.update((x) => x.copyWith(flashHidden: const {})),
          ),
        ),
      ),
    ];
    if (embedded) return Column(children: children);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: LcTokens.spacingXl),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LcTokens.spacingLg),
          child: Text(
            t.flashLook,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ...children,
      ],
    );
  }
}
