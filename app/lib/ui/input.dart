import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Feel settings that code without a [BuildContext] (round controllers)
/// needs. [LincoinApp] keeps them in step with the user's settings.
class Feel {
  Feel._();
  static bool haptics = true;

  static void selection() {
    if (haptics) HapticFeedback.selectionClick();
  }

  static void light() {
    if (haptics) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (haptics) HapticFeedback.mediumImpact();
  }
}

/// Face buttons of a game controller by position (Xbox naming: A bottom,
/// B right, X left, Y top). With [swapAB] the confirm and back buttons
/// trade places, as on Nintendo controllers.
class Pad {
  Pad._();

  /// Controller support on, layout and quick-answer mode; kept in step with
  /// the settings by [LincoinApp].
  static bool enabled = true;
  static bool swapAB = false;
  static bool quickAnswer = false;
  static LogicalKeyboardKey confirm(bool swapAB) =>
      swapAB ? LogicalKeyboardKey.gameButtonB : LogicalKeyboardKey.gameButtonA;
  static LogicalKeyboardKey back(bool swapAB) =>
      swapAB ? LogicalKeyboardKey.gameButtonA : LogicalKeyboardKey.gameButtonB;

  /// Buttons that pick answer 1–4 in quick-answer mode, and their labels.
  static List<(LogicalKeyboardKey, String)> answerKeys(bool swapAB) => [
    (confirm(swapAB), swapAB ? 'B' : 'A'),
    (back(swapAB), swapAB ? 'A' : 'B'),
    (LogicalKeyboardKey.gameButtonX, 'X'),
    (LogicalKeyboardKey.gameButtonY, 'Y'),
  ];

  static const digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];

  /// True while the user drives the app with keys or a controller (focus
  /// rings are showing), so a newly shown button should take focus.
  static bool get usingKeys =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
}

/// Shrinks [child] a little while a finger (or the confirm key) holds it
/// down and springs back on release. Uses a [Listener], so it never
/// competes with the child's own gestures. Off when animations are off.
class PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scale;
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.96,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || context.reduceMotion) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// [FilledButton] with [PressScale] and a light tap feel.
class PressFilledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final bool autofocus;
  final FocusNode? focusNode;
  const PressFilledButton({
    super.key,
    required this.onPressed,
    required Widget this.child,
    this.style,
    this.autofocus = false,
    this.focusNode,
  }) : icon = null,
       label = null;
  const PressFilledButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.style,
    this.autofocus = false,
    this.focusNode,
  }) : child = null;

  @override
  Widget build(BuildContext context) {
    final tap = onPressed == null
        ? null
        : () {
            Feel.selection();
            onPressed!();
          };
    return PressScale(
      enabled: onPressed != null,
      child: icon == null
          ? FilledButton(
              onPressed: tap,
              style: style,
              autofocus: autofocus,
              focusNode: focusNode,
              child: child,
            )
          : FilledButton.icon(
              onPressed: tap,
              style: style,
              autofocus: autofocus,
              focusNode: focusNode,
              icon: icon,
              label: label!,
            ),
    );
  }
}

/// [OutlinedButton] with [PressScale] and a light tap feel.
class PressOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final bool autofocus;
  final FocusNode? focusNode;
  const PressOutlinedButton({
    super.key,
    required this.onPressed,
    required Widget this.child,
    this.style,
    this.autofocus = false,
    this.focusNode,
  }) : icon = null,
       label = null;
  const PressOutlinedButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.style,
    this.autofocus = false,
    this.focusNode,
  }) : child = null;

  @override
  Widget build(BuildContext context) {
    final tap = onPressed == null
        ? null
        : () {
            Feel.selection();
            onPressed!();
          };
    return PressScale(
      enabled: onPressed != null,
      child: icon == null
          ? OutlinedButton(
              onPressed: tap,
              style: style,
              autofocus: autofocus,
              focusNode: focusNode,
              child: child,
            )
          : OutlinedButton.icon(
              onPressed: tap,
              style: style,
              autofocus: autofocus,
              focusNode: focusNode,
              icon: icon,
              label: label!,
            ),
    );
  }
}
