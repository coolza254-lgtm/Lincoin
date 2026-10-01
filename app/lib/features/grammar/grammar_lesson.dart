import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../data/content_db.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../study/item_details.dart' show SpeakButton;

/// A Japanese sentence with the grammar part highlighted (or blanked).
class ClozeSentence extends StatelessWidget {
  final GrammarExample example;
  final bool blank;
  final double size;
  const ClozeSentence(
    this.example, {
    super.key,
    this.blank = false,
    this.size = LcTokens.jpSentenceSize + 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final (before, answer, after) = example.parts;
    final base = jpStyle(size, LcTokens.jpSentenceWeight, c.ink);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: before),
          if (blank)
            TextSpan(
              text: '　＿＿　',
              style: base.copyWith(
                color: c.accent,
                backgroundColor: c.accentSoft,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            TextSpan(
              text: answer,
              style: base.copyWith(
                color: c.accent,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: c.accent,
              ),
            ),
          TextSpan(text: after),
        ],
      ),
      semanticsLabel: blank ? '$before ช่องว่าง $after' : example.sentence.ja,
    );
  }
}

/// Example with translation and credit line.
class GrammarExampleTile extends StatelessWidget {
  final GrammarExample example;
  const GrammarExampleTile(this.example, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final e = example.sentence;
    return Container(
      width: double.infinity,
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
              Expanded(child: ClozeSentence(example)),
              SpeakButton(text: e.ja, small: true),
            ],
          ),
          if (e.th != null) Text(e.th!, style: tt.bodyMedium),
          const SizedBox(height: LcTokens.spacingXs),
          Text(
            t.exampleCredit(e.sourceNumber, e.jaAuthor, e.jaLicense),
            style: tt.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Full explanation of a grammar point: meaning, how to form it, notes,
/// examples and points it is often confused with.
class GrammarLesson extends ConsumerWidget {
  final GrammarPoint point;

  /// When set (feedback screen), this sentence is shown first.
  final GrammarExample? highlight;
  final int maxExamples;
  const GrammarLesson({
    super.key,
    required this.point,
    this.highlight,
    this.maxExamples = 3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final catalog = ref.watch(catalogProvider);
    final similar = [
      for (final id in point.similarIds)
        if (catalog?.byId[id] case final GrammarStudy g) g.point,
    ];
    final examples = [
      ?highlight,
      ...point.clozeExamples.where((e) => e != highlight),
    ].take(maxExamples);
    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: LcTokens.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tt.labelLarge?.copyWith(color: c.muted)),
          const SizedBox(height: LcTokens.spacingXs),
          child,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(point.titleJa, style: jpStyle(28, 700, c.ink)),
        const SizedBox(height: LcTokens.spacingXs),
        Text(point.titleTh, style: tt.titleLarge?.copyWith(color: c.accent)),
        section(t.grammarMeaning, Text(point.meaningTh, style: tt.bodyLarge)),
        section(
          t.grammarFormation,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(LcTokens.spacingMd),
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(LcTokens.radiusControl),
            ),
            child: Text(point.formationTh, style: tt.bodyLarge),
          ),
        ),
        if (point.notesTh != null)
          section(t.grammarNotes, Text(point.notesTh!, style: tt.bodyMedium)),
        if (examples.isNotEmpty)
          section(
            t.grammarExamples,
            Column(
              children: [
                for (final e in examples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LcTokens.spacingSm),
                    child: GrammarExampleTile(e),
                  ),
              ],
            ),
          ),
        if (similar.isNotEmpty)
          section(
            t.grammarCompare,
            Wrap(
              spacing: LcTokens.spacingSm,
              runSpacing: LcTokens.spacingSm,
              children: [
                for (final s in similar)
                  ActionChip(
                    label: Text('${s.titleJa}  ${s.titleTh}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GrammarPointScreen(point: s),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class GrammarPointScreen extends StatelessWidget {
  final GrammarPoint point;
  const GrammarPointScreen({super.key, required this.point});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(point.titleJa)),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          0,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [LcCard(child: GrammarLesson(point: point, maxExamples: 6))],
      ),
    ),
  );
}

/// All grammar points with their study state.
class GrammarListScreen extends ConsumerWidget {
  const GrammarListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final catalog = ref.watch(catalogProvider);
    ref.watch(dataVersionProvider);
    final started = {
      for (final card
          in ref
                  .read(deckServiceProvider(grammarDeck))
                  ?.repo
                  .cards(deck: grammarDeck)
                  .values ??
              const <Never>[])
        card.itemId,
    };
    final points = [
      for (final i in catalog?.path ?? const <StudyItem>[])
        if (i is GrammarStudy) i.point,
    ];
    final rows = <Object>[
      for (final (i, p) in points.indexed) ...[
        if (i == 0 || points[i - 1].level != p.level) 'N${p.level}',
        p,
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t.grammarList)),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingLg,
            0,
            LcTokens.spacingLg,
            LcTokens.spacingXxl,
          ),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final p = rows[i];
            // A level header before each level's first point.
            if (p is String) {
              final done = points
                  .where((g) => 'N${g.level}' == p && started.contains(g.id))
                  .length;
              final total = points.where((g) => 'N${g.level}' == p).length;
              return SectionLabel(t.grammarLevelProgress(p, done, total));
            }
            p as GrammarPoint;
            return ListTile(
              leading: Icon(
                started.contains(p.id)
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: started.contains(p.id) ? c.good : c.line,
              ),
              title: Text(p.titleJa, style: jpStyle(18, 500, c.ink)),
              subtitle: Text(p.titleTh, style: tt.bodySmall),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GrammarPointScreen(point: p)),
              ),
            );
          },
        ),
      ),
    );
  }
}
