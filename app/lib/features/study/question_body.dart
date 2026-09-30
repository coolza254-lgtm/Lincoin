import 'package:flutter/material.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../../data/catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/pos_th.dart';
import '../../services/study_service.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../grammar/grammar_lesson.dart' show ClozeSentence;

/// Prompt and answer area of one question. Shared by study sessions,
/// practice and challenges, so every mode asks questions the same way.
class QuestionBody extends StatefulWidget {
  final Question question;
  final bool showFurigana;
  final ValueChanged<int> onChoose;
  final ValueChanged<String> onSubmit;

  /// Reveals the first kana (recall only); null hides the button.
  final bool hintShown;
  final bool synonymHint;

  /// After answering (quick feedback in drills): highlights the right
  /// option and the one chosen.
  final int? revealChosen;

  const QuestionBody({
    super.key,
    required this.question,
    required this.onChoose,
    required this.onSubmit,
    this.showFurigana = true,
    this.hintShown = false,
    this.synonymHint = false,
    this.revealChosen,
  });

  @override
  State<QuestionBody> createState() => _QuestionBodyState();
}

class _QuestionBodyState extends State<QuestionBody> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    if (widget.question.isTyped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final q = widget.question;
    final item = q.item;

    Widget meaningPrompt(WordStudy w) => Column(
      children: [
        Text(
          w.word.shortMeaning,
          style: tt.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LcTokens.spacingSm),
        Wrap(
          spacing: LcTokens.spacingSm,
          children: [
            for (final p in posLabels(w.word.pos))
              LcPill(p, bg: c.track, fg: c.muted),
          ],
        ),
      ],
    );

    final (String label, Widget prompt) = switch (q.form) {
      QuestionForm.meaningChoice => (
        t.qMeaning,
        Furigana(
          (item as WordStudy).word.headwordFurigana,
          showReading: widget.showFurigana,
        ),
      ),
      QuestionForm.readingType => (
        t.qTypeReading,
        meaningPrompt(item as WordStudy),
      ),
      QuestionForm.wordChoice => (
        t.qChooseWord,
        meaningPrompt(item as WordStudy),
      ),
      QuestionForm.cloze => (
        t.qCloze,
        Column(
          children: [
            ClozeSentence(q.example!, blank: true, size: 26),
            const SizedBox(height: LcTokens.spacingMd),
            Text(
              q.example!.sentence.th ?? '',
              style: tt.bodyLarge?.copyWith(color: c.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      QuestionForm.kanaType || QuestionForm.kanaChoice => (
        q.form == QuestionForm.kanaType ? t.qTypeRomaji : t.qChooseRomaji,
        Text((item as KanaStudy).kana.char, style: jpStyle(96, 700, c.ink)),
      ),
    };

    final hint = widget.hintShown && item is WordStudy
        ? item.word.reading.characters.first
        : null;

    return Column(
      children: [
        LcPill(label),
        const SizedBox(height: LcTokens.spacingXxl),
        Semantics(header: true, child: prompt),
        const SizedBox(height: LcTokens.spacingXxl),
        if (q.choices != null)
          for (final (i, o) in q.choices!.options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
              child: _Option(
                text: o,
                japanese: q.form.japaneseOptions,
                state: widget.revealChosen == null
                    ? _OptionState.idle
                    : i == q.choices!.correctIndex
                    ? _OptionState.right
                    : i == widget.revealChosen
                    ? _OptionState.wrong
                    : _OptionState.dim,
                onPressed: widget.revealChosen == null
                    ? () => widget.onChoose(i)
                    : null,
              ),
            )
        else ...[
          TextField(
            controller: _input,
            focusNode: _focus,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            style: jpStyle(24, 500, c.ink),
            textAlign: TextAlign.center,
            // Empty on purpose: no example text that could hint at the answer.
            decoration: const InputDecoration(),
            onSubmitted: widget.onSubmit,
          ),
          const SizedBox(height: LcTokens.spacingSm),
          if (q.form == QuestionForm.readingType && _input.text.isNotEmpty)
            Text(
              normalizeReading(_input.text),
              style: jpStyle(20, 500, c.muted),
              semanticsLabel: t.kanaPreview,
            ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: LcTokens.spacingSm),
              child: Text(t.hintStartsWith(hint), style: tt.bodyMedium),
            ),
          if (widget.synonymHint)
            Padding(
              padding: const EdgeInsets.only(top: LcTokens.spacingSm),
              child: LcPill(
                t.synonymTryAgain,
                bg: c.coinSoft,
                fg: c.coin,
                icon: Icons.info_outline_rounded,
              ),
            ),
          const SizedBox(height: LcTokens.spacingLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _input.text.trim().isEmpty
                  ? null
                  : () => widget.onSubmit(_input.text),
              child: Text(t.checkAnswer),
            ),
          ),
        ],
      ],
    );
  }
}

enum _OptionState { idle, right, wrong, dim }

class _Option extends StatelessWidget {
  final String text;
  final bool japanese;
  final _OptionState state;
  final VoidCallback? onPressed;
  const _Option({
    required this.text,
    required this.japanese,
    required this.state,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    final tt = Theme.of(context).textTheme;
    final (bg, fg, icon) = switch (state) {
      _OptionState.right => (c.goodSoft, c.good, Icons.check_circle_rounded),
      _OptionState.wrong => (c.warnSoft, c.warn, Icons.cancel_rounded),
      _OptionState.dim => (c.surface, c.muted, null),
      _OptionState.idle => (c.surface, c.ink, null),
    };
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: bg,
        disabledBackgroundColor: bg,
        disabledForegroundColor: fg,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: LcTokens.spacingLg,
          vertical: 14,
        ),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: japanese
                  ? jpStyle(22, 500, fg)
                  : tt.bodyLarge?.copyWith(color: fg),
            ),
          ),
          if (icon != null) Icon(icon, color: fg),
        ],
      ),
    );
  }
}
