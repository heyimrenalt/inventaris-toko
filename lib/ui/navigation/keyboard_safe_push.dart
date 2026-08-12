import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Pushes [route] the way [Navigator.push] does, but guarantees the
/// soft keyboard stays down for a screen the user is only *reading* on
/// return.
///
/// The bug this exists to kill: on Beranda / Produk / Mutasi / Sering
/// Keluar / Prioritas Kulakan the user taps the search field (keyboard
/// opens), taps a product, reads its detail, then hits back — and the
/// keyboard pops straight back up with the cursor blinking, because
/// Flutter's [ModalRoute] *saves the focused node when a route is pushed
/// over it and restores that focus when the route is popped*. Simply
/// unfocusing before the push isn't enough: the route restores focus on
/// the way back regardless.
///
/// So we unfocus on both sides of the trip:
///
/// * Before pushing — targets the live [FocusManager.primaryFocus] (the
///   search field) directly.
/// * After the pop — the route's focus restoration lands a frame or two
///   *later*, so a single unfocus right after the await is too early
///   (focus hasn't been restored yet, so there's nothing to clear). We
///   therefore clear focus for a handful of consecutive frames after
///   returning: whichever frame the restoration lands on, one of these
///   catches it. Beranda's search lives in an [OverlayEntry] on a
///   kept-alive page, and its restoration lands later than the plain
///   in-flow fields elsewhere — this is why one post-frame unfocus fixed
///   those screens but not Beranda.
Future<T?> keyboardSafePush<T>(BuildContext context, Route<T> route) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final navigator = Navigator.of(context);
  final result = await navigator.push<T>(route);
  _dismissKeyboardForNextFrames();
  return result;
}

/// Drops focus and hides the keyboard on each of the next few frames, so
/// a late [ModalRoute] focus restoration can't leave the keyboard up.
void _dismissKeyboardForNextFrames([int framesLeft = 3]) {
  if (framesLeft <= 0) return;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    FocusManager.instance.primaryFocus?.unfocus();
    // Belt-and-suspenders: even if some node is still focused, force the
    // platform keyboard closed.
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    _dismissKeyboardForNextFrames(framesLeft - 1);
  });
}
