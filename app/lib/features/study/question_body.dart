import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lincoin_core/lincoin_core.dart';

import '../../data/catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/pos_th.dart';
import '../../services/study_service.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../grammar/grammar_lesson.dart' show ClozeSentence;
import '../../ui/input.dart';

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

  /// After answering: highlights the right option and the one chosen
  /// (-1 = none chosen, e.g. "don't know").
  final int? revealChosen;

  /// With [revealChosen]: fold away the options that were neither right
  /// nor chosen, so the explanation below fits on screen.
  final bool collapseOthers;

  /// After a typed answer: whether it was right (locks and colours the
  /// field). Null while the question is open.
  final bool? revealTyped;

  const QuestionBody({
    super.key,
    required this.question,
    required this.onChoose,
    required this.onSubmit,
    this.showFurigana = true,
    this.hintShown = false,
    this.synonymHint = false,
    this.revealChosen,
    this.collapseOthers = false,
    this.revealTyped,
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
            for (final p in posLabels(w.word.pos, max: 2))
              LcPill(p, bg: c.track, fg: c.muted),
          ],
        ),
      ],
    );

    final (String label, Widget prompt) = switch (q.form) {
      QuestionForm.meaningChoice || QuestionForm.flashcard => (
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
            // Filled in (highlighted) once answered.
            ClozeSentence(
              q.example!,
              blank: widget.revealChosen == null,
              size: 26,
            ),
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
    final revealed = widget.revealTyped != null;
    final typedColor = !revealed
        ? null
        : (widget.revealTyped! ? c.good : c.warn);

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          LcPill(label),
          const SizedBox(height: LcTokens.spacingXxl),
          Semantics(header: true, child: prompt),
          const SizedBox(height: LcTokens.spacingXxl),
          if (q.choices != null)
            for (final (i, o) in q.choices!.options.indexed)
              _collapsible(
                context,
                hidden:
                    widget.collapseOthers &&
                    widget.revealChosen != null &&
                    i != q.choices!.correctIndex &&
                    i != widget.revealChosen,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
                  child: _Option(
                    autofocus: i == 0 && widget.revealChosen == null,
                    badge: Pad.enabled && Pad.quickAnswer && i < 4
                        ? Pad.answerKeys(Pad.swapAB)[i].$2
                        : null,
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
                ),
              )
          // Gave up without typing: nothing to show in the field.
          else if (revealed && _input.text.isEmpty)
            const SizedBox.shrink()
          else ...[
            TextField(
              controller: _input,
              focusNode: _focus,
              readOnly: revealed,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              style: jpStyle(24, 500, typedColor ?? c.ink),
              textAlign: TextAlign.center,
              // Empty on purpose: no example text that could hint at the answer.
              decoration: typedColor == null
                  ? const InputDecoration()
                  : InputDecoration(
                      fillColor: widget.revealTyped! ? c.goodSoft : c.warnSoft,
                      enabledBorder: _border(typedColor),
                      focusedBorder: _border(typedColor),
                      suffixIcon: Icon(
                        widget.revealTyped!
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: typedColor,
                      ),
                    ),
              onSubmitted: revealed ? null : widget.onSubmit,
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
            if (!revealed) ...[
              const SizedBox(height: LcTokens.spacingLg),
              SizedBox(
                width: double.infinity,
                child: PressFilledButton(
                  onPressed: _input.text.trim().isEmpty
                      ? null
                      : () => widget.onSubmit(_input.text),
                  child: Text(t.checkAnswer),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Keys 1–4 pick an answer; in quick-answer mode so do the controller's
  /// face buttons (A, B, X, Y by position).
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final choices = widget.question.choices;
    if (e is! KeyDownEvent || choices == null || widget.revealChosen != null) {
      return KeyEventResult.ignored;
    }
    var i = Pad.digitKeys.indexOf(e.logicalKey);
    if (i < 0 && Pad.enabled && Pad.quickAnswer) {
      i = Pad.answerKeys(Pad.swapAB).indexWhere((k) => k.$1 == e.logicalKey);
    }
    if (i < 0 || i >= choices.options.length) return KeyEventResult.ignored;
    widget.onChoose(i);
    return KeyEventResult.handled;
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(LcTokens.radiusControl),
    borderSide: BorderSide(color: color, width: 2),
  );

  /// Folds [child] to nothing (animated) when [hidden].
  Widget _collapsible(
    BuildContext context, {
    required bool hidden,
    required Widget child,
  }) => TweenAnimationBuilder<double>(
    tween: Tween(end: hidden ? 0 : 1),
    duration: context.motionNormal,
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, v, child) => IgnorePointer(
      ignoring: hidden,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: v,
          child: Opacity(opacity: v, child: child),
        ),
      ),
    ),
  );
}

enum _OptionState { idle, right, wrong, dim }

class _Option extends StatelessWidget {
  final String text;
  final bool japanese;
  final _OptionState state;
  final VoidCallback? onPressed;
  final String? badge;
  final bool autofocus;
  const _Option({
    this.autofocus = false,
    required this.text,
    required this.japanese,
    required this.state,
    required this.onPressed,
    this.badge,
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
    final button = OutlinedButton(
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
      autofocus: autofocus,
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
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(left: LcTokens.spacingSm),
              child: _ButtonBadge(badge!),
            ),
          if (icon != null) Icon(icon, color: fg),
        ],
      ),
    );
    return _RevealMotion(
      state: state,
      child: PressScale(enabled: onPressed != null, child: button),
    );
  }
}

/// Controller button glyph shown on an answer in quick-answer mode.
class _ButtonBadge extends StatelessWidget {
  final String label;
  const _ButtonBadge(this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.lc;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.track),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: c.muted,
        ),
      ),
    );
  }
}

/// A right answer pops once; a wrong one gives a short shake.
class _RevealMotion extends StatelessWidget {
  final _OptionState state;
  final Widget child;
  const _RevealMotion({required this.state, required this.child});

  @override
  Widget build(BuildContext context) {
    final active = state == _OptionState.right || state == _OptionState.wrong;
    if (!active || context.reduceMotion) return child;
    final wrong = state == _OptionState.wrong;
    return TweenAnimationBuilder<double>(
      key: ValueKey(state),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: wrong ? 420 : 360),
      child: child,
      builder: (context, t, child) {
        if (wrong) {
          // Damped side-to-side shake.
          final dx = 8 * (1 - t) * math.sin(t * math.pi * 6);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        }
        final s = 1 + 0.05 * math.sin(t * math.pi);
        return Transform.scale(scale: s, child: child);
      },
    );
  }
}
