import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../services/challenge_service.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../study/item_details.dart';
import '../study/question_body.dart';
import 'drill_controller.dart';

/// Plays one practice round or challenge round.
class DrillScreen extends ConsumerStatefulWidget {
  final DrillConfig config;
  const DrillScreen({super.key, required this.config});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  late final DrillController ctl;

  @override
  void initState() {
    super.initState();
    ctl = DrillController(
      practice: ref.read(practiceServiceProvider)!,
      challenges: ref.read(challengeServiceProvider),
      config: widget.config,
      onDataChanged: () {
        if (mounted) ref.read(dataVersionProvider.notifier).bump();
      },
    );
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!widget.config.isChallenge || ctl.phase == DrillPhase.done) return true;
    final t = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.leaveChallengeTitle),
            content: Text(t.leaveChallengeBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.keepPlaying),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.forfeit),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.lc;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: ctl,
        builder: (context, _) {
          final ch = widget.config.challenge;
          return Scaffold(
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
                        Expanded(
                          child: LcProgressBar(
                            ctl.progress,
                            color: widget.config.timeLimit != null
                                ? c.coin
                                : null,
                          ),
                        ),
                        const SizedBox(width: LcTokens.spacingMd),
                        if (widget.config.timeLimit != null)
                          Text(
                            '${ctl.remaining.inSeconds}s',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        if (ch != null) ...[
                          const SizedBox(width: LcTokens.spacingSm),
                          LcPill(
                            '${ctl.score} / ${ch.threshold}',
                            icon: Icons.flag_rounded,
                          ),
                        ] else
                          CoinChip(ctl.coins),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ctl.isEmpty
                        ? EmptyState(
                            icon: Icons.school_outlined,
                            title: t.practiceNeedsItems,
                          )
                        : switch (ctl.phase) {
                            DrillPhase.done => _Summary(ctl),
                            _ => _QuestionArea(ctl),
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuestionArea extends StatelessWidget {
  final DrillController ctl;
  const _QuestionArea(this.ctl);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final q = ctl.question!;
    final feedback = ctl.phase == DrillPhase.feedback;
    final ok = ctl.lastCorrect ?? false;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LcTokens.spacingXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (feedback && !ctl.config.isChallenge ||
                    feedback && q.isTyped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LcTokens.spacingLg),
                    child: Container(
                      padding: const EdgeInsets.all(LcTokens.spacingLg),
                      decoration: BoxDecoration(
                        color: ok ? c.goodSoft : c.warnSoft,
                        borderRadius: BorderRadius.circular(
                          LcTokens.radiusCard,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ok
                                ? Icons.check_circle_rounded
                                : Icons.replay_circle_filled_rounded,
                            color: ok ? c.good : c.warn,
                          ),
                          const SizedBox(width: LcTokens.spacingMd),
                          Expanded(
                            child: Text(
                              ok ? t.correct : t.notYet,
                              style: tt.titleMedium?.copyWith(
                                color: ok ? c.good : c.warn,
                              ),
                            ),
                          ),
                          if (ctl.combo >= 3 && ok)
                            LcPill(
                              t.combo(ctl.combo),
                              bg: c.coinSoft,
                              fg: c.coin,
                            ),
                          if (ctl.lastCoins > 0) ...[
                            const SizedBox(width: LcTokens.spacingSm),
                            CoinChip(ctl.lastCoins, signed: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (feedback && !ctl.config.isChallenge)
                  LcCard(child: ItemDetails(item: ctl.current!.item))
                else if (feedback && q.isTyped)
                  _Answer(ctl.current!.item)
                else
                  QuestionBody(
                    key: ValueKey(ctl.index),
                    question: q,
                    revealChosen: feedback ? (ctl.chosen ?? -1) : null,
                    onChoose: ctl.choose,
                    onSubmit: ctl.submitTyped,
                    synonymHint: ctl.synonymHint,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingXl,
            0,
            LcTokens.spacingXl,
            LcTokens.spacingLg,
          ),
          child: feedback && !ctl.config.isChallenge
              ? SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    autofocus: true,
                    onPressed: ctl.next,
                    child: Text(t.next),
                  ),
                )
              : !feedback && !ctl.config.choiceOnly
              ? Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: ctl.dontKnow,
                    child: Text(t.dontKnow),
                  ),
                )
              : const SizedBox(height: 48),
        ),
      ],
    );
  }
}

/// Correct answer after a typed question in a challenge.
class _Answer extends StatelessWidget {
  final StudyItem item;
  const _Answer(this.item);

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final i = item;
    final (big, small) = switch (i) {
      KanaStudy() => (i.kana.char, i.kana.romaji),
      WordStudy() => (i.word.headword, i.word.reading),
    };
    return Column(
      children: [
        Text(big, style: jpStyle(LcTokens.jpAnswerSize, 700, c.ink)),
        Text(small, style: jpStyle(20, 500, c.muted)),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final DrillController ctl;
  const _Summary(this.ctl);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final r = ctl.result;
    final won = r?.result == 'won';
    final acc = ctl.answered == 0
        ? 0
        : (ctl.correct * 100 / ctl.answered).round();
    return Padding(
      padding: const EdgeInsets.all(LcTokens.spacingXl),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            r == null
                ? Icons.celebration_rounded
                : won
                ? Icons.emoji_events_rounded
                : Icons.sentiment_neutral_rounded,
            size: 64,
            color: r == null || won ? c.accent : c.muted,
          ),
          const SizedBox(height: LcTokens.spacingLg),
          Text(
            r == null
                ? t.practiceDone
                : won
                ? t.challengeWon
                : t.challengeLost,
            style: tt.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LcTokens.spacingXxl),
          LcCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatTile(
                  r == null ? '${ctl.correct}/${ctl.answered}' : '${ctl.score}',
                  r == null ? t.correctCount : t.scoreLabel(r.threshold),
                ),
                if (r == null) StatTile('$acc%', t.accuracyLabel),
                if (r == null)
                  StatTile('${ctl.bestCombo}', t.bestCombo)
                else
                  Column(
                    children: [
                      CoinChip(
                        won ? r.payout : -r.stake,
                        signed: true,
                        large: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        won ? t.payoutLabel : t.stakeLost,
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (r == null && ctl.coins > 0) ...[
            const SizedBox(height: LcTokens.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.coinsEarned, style: tt.bodyLarge),
                const SizedBox(width: LcTokens.spacingSm),
                CoinChip(ctl.coins, signed: true),
              ],
            ),
          ],
          if (r != null && r.type != ChallengeType.weekly) ...[
            const SizedBox(height: LcTokens.spacingLg),
            Text(
              t.thresholdAdapts,
              style: tt.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.done),
            ),
          ),
        ],
      ),
    );
  }
}
