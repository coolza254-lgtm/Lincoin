import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../data/content_db.dart';
import '../grammar/grammar_lesson.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/pos_th.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';

/// Word or kana with reading, Thai meanings and an example (with credit).
/// Used on the introduction and feedback screens.
class ItemDetails extends ConsumerWidget {
  final StudyItem item;
  final bool showFurigana;

  /// Grammar feedback: the sentence that was asked.
  final GrammarExample? example;
  const ItemDetails({
    super.key,
    required this.item,
    this.showFurigana = true,
    this.example,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final i = item;
    if (i is GrammarStudy) {
      return GrammarLesson(point: i.point, highlight: example);
    }
    if (i is KanaStudy) {
      return Column(
        children: [
          Text(i.kana.char, style: jpStyle(96, 700, c.ink)),
          const SizedBox(height: LcTokens.spacingSm),
          Text(i.kana.romaji, style: tt.headlineMedium),
          const SizedBox(height: LcTokens.spacingSm),
          Text(
            i.kana.script == 'hiragana' ? t.hiragana : t.katakana,
            style: tt.bodySmall,
          ),
          const SizedBox(height: LcTokens.spacingMd),
          SpeakButton(text: i.kana.char),
        ],
      );
    }
    final w = (i as WordStudy).word;
    final examples =
        ref.watch(catalogProvider)?.db.examplesFor(w.id) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Furigana(
            w.headwordFurigana,
            size: LcTokens.jpAnswerSize,
            showReading: showFurigana,
          ),
        ),
        const SizedBox(height: LcTokens.spacingXs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(w.reading, style: jpStyle(20, 500, c.muted)),
            const SizedBox(width: LcTokens.spacingSm),
            SpeakButton(text: w.reading),
          ],
        ),
        const SizedBox(height: LcTokens.spacingMd),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: LcTokens.spacingSm,
          runSpacing: LcTokens.spacingSm,
          children: [
            LcPill('N${w.level}'),
            for (final p in posLabels(w.pos))
              LcPill(p, bg: c.track, fg: c.muted),
          ],
        ),
        const SizedBox(height: LcTokens.spacingLg),
        for (final (n, s) in w.senses.take(4).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: LcTokens.spacingSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${n + 1}.',
                    style: tt.bodyLarge?.copyWith(color: c.muted),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.display,
                        style: n == 0 ? tt.titleMedium : tt.bodyLarge,
                      ),
                      if (s.noteTh != null)
                        Text(s.noteTh!, style: tt.bodySmall),
                      if (s.th == null)
                        Text(t.untranslated, style: tt.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (w.senses.length > 4)
          Text(t.moreMeanings(w.senses.length - 4), style: tt.bodySmall),
        for (final e in examples.take(1)) ...[
          const SizedBox(height: LcTokens.spacingMd),
          Container(
            padding: const EdgeInsets.all(LcTokens.spacingLg),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(LcTokens.radiusControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        e.ja,
                        style: jpStyle(
                          LcTokens.jpSentenceSize,
                          LcTokens.jpSentenceWeight,
                          c.ink,
                        ),
                      ),
                    ),
                    SpeakButton(text: e.ja, small: true),
                  ],
                ),
                const SizedBox(height: LcTokens.spacingXs),
                if (e.th != null) Text(e.th!, style: tt.bodyMedium),
                const SizedBox(height: LcTokens.spacingSm),
                Text(
                  t.exampleCredit(e.sourceNumber, e.jaAuthor, e.jaLicense),
                  style: tt.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class SpeakButton extends ConsumerWidget {
  final String text;
  final bool small;
  const SpeakButton({super.key, required this.text, this.small = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return IconButton(
      tooltip: t.listen,
      iconSize: small ? 20 : 24,
      visualDensity: small ? VisualDensity.compact : null,
      color: context.lc.accent,
      icon: const Icon(Icons.volume_up_rounded),
      onPressed: () async {
        final ok = await ref.read(ttsProvider).speak(text);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(t.noJapaneseVoice)));
        }
      },
    );
  }
}
