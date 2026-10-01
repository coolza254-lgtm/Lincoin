import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../../data/catalog.dart';
import '../../data/settings_repo.dart';
import '../../data/study_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../services/study_service.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import 'item_details.dart';
import 'question_body.dart';
import 'session_controller.dart';
import '../../ui/input.dart';

class StudyScreen extends ConsumerWidget {
  /// 'vocab' or 'grammar'.
  final String deck;
  const StudyScreen({super.key, this.deck = vocabDeck});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider(deck));
    final ctl = ref.read(sessionProvider(deck).notifier);
    final t = AppLocalizations.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ctl.quit();
        final data = ref.read(dataVersionProvider.notifier);
        Future.microtask(data.bump);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: t.close,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(child: LcProgressBar(s.progress)),
                    const SizedBox(width: LcTokens.spacingMd),
                    CoinChip(s.coins),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motionNormal,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: _slideFade,
                  child: KeyedSubtree(
                    // A question and its feedback share one subtree: the
                    // answer is revealed in place, not on a new page.
                    key: ValueKey(switch (s.phase) {
                      SessionPhase.intro => 'intro-${s.question?.cardId}',
                      SessionPhase.done => 'done',
                      _ =>
                        'q-${s.question?.cardId}-'
                            '${s.answered - (s.phase == SessionPhase.feedback ? 1 : 0)}',
                    }),
                    child: switch (s.phase) {
                      SessionPhase.intro => _Intro(s, deck),
                      SessionPhase.question ||
                      SessionPhase.feedback => _QuestionView(s, deck),
                      SessionPhase.done => _Done(s, deck),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// New content slides in slightly from the right while the old one fades.
Widget _slideFade(Widget child, Animation<double> a) => FadeTransition(
  opacity: a,
  child: SlideTransition(
    position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
    child: child,
  ),
);

/// Scrollable body with a fixed action area at the bottom.
class _Frame extends StatelessWidget {
  final Widget body;
  final List<Widget> actions;
  const _Frame({required this.body, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              LcTokens.spacingXl,
              LcTokens.spacingLg,
              LcTokens.spacingXl,
              LcTokens.spacingLg,
            ),
            child: body,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingXl,
            LcTokens.spacingMd,
            LcTokens.spacingXl,
            LcTokens.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ],
    );
  }
}

class _Intro extends ConsumerWidget {
  final SessionState s;
  final String deck;
  const _Intro(this.s, this.deck);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final item = s.question!.item;
    return _Frame(
      body: Column(
        children: [
          LcPill(switch (item) {
            KanaStudy() => t.newKana,
            GrammarStudy() => t.newGrammar,
            _ => t.newWord,
          }, icon: Icons.auto_awesome_rounded),
          const SizedBox(height: LcTokens.spacingXl),
          LcCard(large: true, child: ItemDetails(item: item)),
          const SizedBox(height: LcTokens.spacingMd),
          Text(
            t.introHint,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        PressFilledButton(
          onPressed: ref.read(sessionProvider(deck).notifier).finishIntro,
          child: Text(t.gotIt),
        ),
      ],
    );
  }
}

class _QuestionView extends ConsumerWidget {
  final SessionState s;
  final String deck;
  const _QuestionView(this.s, this.deck);

  bool _showFurigana(WidgetRef ref, Question q) {
    final mode = ref.read(settingsProvider).furigana;
    if (mode == FuriganaMode.always) return true;
    if (mode == FuriganaMode.never) return false;
    final svc = ref.read(deckServiceProvider(deck));
    final stored = svc?.stored(q.cardId);
    return stored == null || !svc!.config.mastery.isMastered(stored.state);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final q = s.question!;
    final ctl = ref.read(sessionProvider(deck).notifier);
    final fb = s.phase == SessionPhase.feedback;
    return _Frame(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed slots, so the question keeps its state (typed text, focus)
          // when the result appears around it.
          Reveal(
            shown: fb,
            child: fb ? _ResultBanner(s) : const SizedBox.shrink(),
          ),
          QuestionBody(
            key: const ValueKey('question'),
            question: q,
            showFurigana: _showFurigana(ref, q),
            hintShown: s.hintShown,
            synonymHint: s.synonymHint,
            onChoose: ctl.chooseOption,
            onSubmit: ctl.submitTyped,
            revealChosen: fb && q.choices != null
                ? (s.chosenIndex ?? -1)
                : null,
            collapseOthers: true,
            revealTyped: fb && q.isTyped ? (s.correct ?? false) : null,
          ),
          Reveal(
            shown: fb,
            child: fb
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: LcTokens.spacingSm),
                      LcCard(
                        large: true,
                        child: ItemDetails(
                          item: q.item,
                          example: q.example,
                          hideHeadword: q.form == QuestionForm.meaningChoice,
                        ),
                      ),
                      if (q.item is WordStudy)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(t.reportTranslation),
                            onPressed: () => _report(context, ref, q.item.id),
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      actions: [
        if (fb)
          PressFilledButton(
            // Takes focus from the answer field, which closes the keyboard.
            autofocus: true,
            onPressed: ctl.next,
            child: Text(t.next),
          )
        else
          Row(
            children: [
              FilterChip(
                label: Text(t.guessing),
                selected: s.guessing,
                onSelected: (_) => ctl.toggleGuess(),
                tooltip: t.guessingHelp,
              ),
              const Spacer(),
              if (q.form == QuestionForm.readingType && !s.hintShown)
                TextButton(onPressed: ctl.showHint, child: Text(t.hint)),
              TextButton(onPressed: ctl.dontKnow, child: Text(t.dontKnow)),
            ],
          ),
      ],
    );
  }

  Future<void> _report(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    final t = AppLocalizations.of(context);
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.reportTranslation),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          decoration: InputDecoration(hintText: t.reportHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          PressFilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.send),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final catalog = ref.read(catalogProvider);
    StudyRepo(ref.read(userDbProvider)).reportContent(
      itemId,
      'translation',
      ctl.text.trim(),
      catalog?.info.version ?? '',
      DateTime.now().toUtc(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.reportSaved)));
    }
  }
}

/// Right / not yet, what happens next, and the Lincoin earned.
class _ResultBanner extends StatelessWidget {
  final SessionState s;
  const _ResultBanner(this.s);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final ok = s.correct ?? false;
    final r = s.result!;
    final gaveUp = s.typedAnswer == null && s.chosenIndex == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingLg),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(LcTokens.spacingLg),
          decoration: BoxDecoration(
            color: ok ? c.goodSoft : c.warnSoft,
            borderRadius: BorderRadius.circular(LcTokens.radiusCard),
          ),
          child: Row(
            children: [
              PopIn(
                child: Icon(
                  ok
                      ? Icons.check_circle_rounded
                      : Icons.replay_circle_filled_rounded,
                  color: ok ? c.good : c.warn,
                  size: 32,
                ),
              ),
              const SizedBox(width: LcTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ok ? t.correct : t.notYet,
                      style: tt.titleLarge?.copyWith(
                        color: ok ? c.good : c.warn,
                      ),
                    ),
                    if (!ok && gaveUp)
                      Text(t.willReviewSoon, style: tt.bodyMedium),
                    if (r.graduated) Text(t.graduated, style: tt.bodyMedium),
                    if (r.mastered) Text(t.masteredNow, style: tt.bodyMedium),
                    if (r.leech) Text(t.leechNote, style: tt.bodySmall),
                  ],
                ),
              ),
              if (r.coinTotal > 0)
                PopIn(child: CoinChip(r.coinTotal, signed: true)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Done extends ConsumerWidget {
  final SessionState s;
  final String deck;
  const _Done(this.s, this.deck);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final acc = s.answered == 0
        ? 0
        : (s.correctCount * 100 / s.answered).round();
    return _Frame(
      body: Column(
        children: [
          const SizedBox(height: LcTokens.spacingXxl),
          PopIn(
            child: Icon(
              s.answered == 0
                  ? Icons.check_circle_outline_rounded
                  : Icons.celebration_rounded,
              size: 64,
              color: c.accent,
            ),
          ),
          const SizedBox(height: LcTokens.spacingLg),
          Text(
            s.answered == 0 ? t.nothingToStudy : t.sessionDone,
            style: tt.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LcTokens.spacingXxl),
          if (s.answered > 0)
            LcCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatTile('${s.answered}', t.answeredLabel),
                  StatTile('$acc%', t.accuracyLabel),
                  Column(
                    children: [
                      CountUpCoins(s.coins, large: true),
                      const SizedBox(height: 4),
                      Text(t.coinsEarned, style: tt.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          for (final e in s.bonus?.entries ?? const <LedgerEntry>[])
            Padding(
              padding: const EdgeInsets.only(top: LcTokens.spacingMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      e.reason == LedgerReason.dailyClear
                          ? t.bonusDailyClear
                          : t.bonusCoverage,
                      style: tt.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: LcTokens.spacingSm),
                  CoinChip(e.delta, signed: true),
                ],
              ),
            ),
          if (s.laterSteps > 0)
            Padding(
              padding: const EdgeInsets.only(top: LcTokens.spacingLg),
              child: Text(
                t.laterSteps(s.laterSteps),
                style: tt.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      actions: [
        PressFilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(t.backHome),
        ),
      ],
    );
  }
}
