import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_logo.dart';

/// The branded startup screen shown while the database opens and the
/// first-launch migrations run.
///
/// Purely presentational: it owns no initialization and performs no
/// navigation. `MyApp`'s [FutureBuilder] decides when to swap it out for
/// the real app, which keeps `MainScaffold` the first route — the
/// notification cold-start path (`popUntil((route) => route.isFirst)`)
/// depends on that.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// How long the screen waits before admitting that startup is taking a
  /// while. Comfortably past the 1500ms minimum splash duration, so the
  /// message only ever shows up on a genuinely slow launch (realistically:
  /// the one launch after an upgrade that has to backfill mutations).
  static const slowStartThreshold = Duration(seconds: 3);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _dots;
  late final AnimationController _slowMessage;
  Timer? _slowStartTimer;
  bool _showSlowMessage = false;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slowMessage = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _entrance.forward().whenComplete(() {
      // Guarded: a fast init can dismount this screen mid-entrance, and
      // repeat() on a disposed controller throws.
      if (mounted) _dots.repeat();
    });

    _slowStartTimer = Timer(SplashScreen.slowStartThreshold, () {
      if (!mounted) return;
      setState(() => _showSlowMessage = true);
      _slowMessage.forward();
    });
  }

  @override
  void dispose() {
    _slowStartTimer?.cancel();
    _entrance.dispose();
    _dots.dispose();
    _slowMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: FadeTransition(
          opacity: _entrance,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 96),
              const SizedBox(height: AppSpacing.md),
              Text('Toko Mama', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              Text('Kelola stok, tanpa ribet', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xxl),
              _PulsingDots(animation: _dots),
              const SizedBox(height: AppSpacing.lg),
              // Fixed height so the slow-start message fading in doesn't
              // nudge the logo and tagline upward mid-launch.
              SizedBox(
                height: AppSpacing.xl,
                child: _showSlowMessage
                    ? FadeTransition(
                        key: const Key('splash_slow_message'),
                        opacity: _slowMessage,
                        child: Text(
                          'Menyiapkan data...',
                          style: AppTextStyles.caption,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three dots that pulse in sequence, driven by a repeating [animation].
///
/// Each dot animates scale as well as opacity: opacity alone reads as
/// static at a glance, so the trio only registers as motion once the dots
/// visibly grow and shrink.
class _PulsingDots extends StatelessWidget {
  const _PulsingDots({required this.animation});

  final Animation<double> animation;

  static const _dotCount = 3;
  static const _dotSize = 8.0;
  static const _minScale = 0.6;
  static const _minOpacity = 0.3;

  /// Offsets each dot a fifth of a cycle behind the previous one — 200ms of
  /// the 1000ms cycle — and maps the result onto an eased triangle wave, so
  /// the trio reads as a travelling pulse rather than three dots blinking in
  /// unison. Returns 0 at rest, 1 at the peak of the dot's bounce.
  double _waveFor(int index) {
    final phase = (animation.value - index * 0.2) % 1.0;
    final triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return Curves.easeInOut.transform(triangle);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dotCount; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Builder(
                builder: (context) {
                  final wave = _waveFor(i);
                  return Transform.scale(
                    // Scaling doesn't touch layout, so the row's width and
                    // the gaps between dots stay put as they bounce.
                    scale: _minScale + (1 - _minScale) * wave,
                    child: Opacity(
                      opacity: _minOpacity + (1 - _minOpacity) * wave,
                      child: Container(
                        width: _dotSize,
                        height: _dotSize,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
