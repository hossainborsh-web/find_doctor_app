import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The opening animation: the Find Doctor logo beats like a heart inside
/// pulse rings, with a heartbeat line, while the app connects.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.status});

  /// What the app is doing ("Connecting…", "Loading your account…").
  final ValueNotifier<String> status;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _top = Color(0xFF312E81);
  static const _bottom = Color(0xFF1E1B4B);
  static const _accent = Color(0xFF2DD4BF);

  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final AnimationController _beat = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300));
  late final AnimationController _rings = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _line = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));

  // lub-dub: two quick beats, then a rest.
  late final Animation<double> _heartbeat = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.11)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12),
    TweenSequenceItem(
        tween: Tween(begin: 1.11, end: 0.98)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10),
    TweenSequenceItem(
        tween: Tween(begin: 0.98, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 9),
    TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 17),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
  ]).animate(_beat);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1;
      return;
    }
    _beat.repeat();
    _rings.repeat();
    _line.repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _beat.dispose();
    _rings.dispose();
    _line.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final logoIn = _interval(0.0, 0.65, Curves.easeOutBack);
    final logoFade = _interval(0.0, 0.4);
    final titleIn = _interval(0.35, 0.85);
    final restIn = _interval(0.55, 1.0);
    return Scaffold(
      backgroundColor: _bottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_top, _bottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse rings spreading out from the logo.
                      for (var i = 0; i < 3; i++)
                        AnimatedBuilder(
                          animation: _rings,
                          builder: (context, _) {
                            final t = (_rings.value + i / 3) % 1.0;
                            return Opacity(
                              opacity: (1 - t) * 0.45 * logoFade.value,
                              child: Container(
                                width: 140 + t * 150,
                                height: 140 + t * 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _accent.withValues(alpha: 0.9),
                                      width: 2),
                                ),
                              ),
                            );
                          },
                        ),
                      // The logo, beating.
                      FadeTransition(
                        opacity: logoFade,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.55, end: 1.0).animate(logoIn),
                          child: ScaleTransition(
                            scale: _heartbeat,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: 0.45),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/images/find_doctor_logo.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                FadeTransition(
                  opacity: titleIn,
                  child: SlideTransition(
                    position: Tween(
                            begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(titleIn),
                    child: const Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: 'Find ',
                            style: TextStyle(color: Colors.white)),
                        TextSpan(
                            text: 'Doctor',
                            style: TextStyle(color: Color(0xFFA5B4FC))),
                      ]),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: restIn,
                  child: const Text(
                    'Care, one tap away',
                    style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: restIn,
                  child: SizedBox(
                    width: 240,
                    height: 44,
                    child: AnimatedBuilder(
                      animation: _line,
                      builder: (context, _) => CustomPaint(
                        painter: _HeartbeatPainter(
                            progress: _line.value, color: _accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeTransition(
                  opacity: restIn,
                  child: ValueListenableBuilder<String>(
                    valueListenable: widget.status,
                    builder: (context, status, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        status,
                        key: ValueKey(status),
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A heartbeat (ECG) trace drawn left to right, with a glowing tip that
/// leaves a fading tail.
class _HeartbeatPainter extends CustomPainter {
  _HeartbeatPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  // Points of one beat across the width (x, y) in 0..1.
  static const _shape = <Offset>[
    Offset(0.00, 0.60),
    Offset(0.28, 0.60),
    Offset(0.33, 0.48),
    Offset(0.37, 0.60),
    Offset(0.43, 0.60),
    Offset(0.47, 0.05),
    Offset(0.52, 0.98),
    Offset(0.56, 0.60),
    Offset(0.64, 0.60),
    Offset(0.70, 0.40),
    Offset(0.76, 0.60),
    Offset(1.00, 0.60),
  ];

  Offset _at(double x, Size size) {
    for (var i = 1; i < _shape.length; i++) {
      final a = _shape[i - 1];
      final b = _shape[i];
      if (x <= b.dx) {
        final t = b.dx == a.dx ? 0.0 : (x - a.dx) / (b.dx - a.dx);
        final y = a.dy + (b.dy - a.dy) * t;
        return Offset(x * size.width, y * size.height);
      }
    }
    return Offset(size.width, _shape.last.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Faint full trace.
    final base = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final full = Path()
      ..moveTo(_shape.first.dx * size.width, _shape.first.dy * size.height);
    for (final point in _shape.skip(1)) {
      full.lineTo(point.dx * size.width, point.dy * size.height);
    }
    canvas.drawPath(full, base);

    // The bright moving part: a tail behind the tip.
    const tail = 0.35;
    final head = progress * (1 + tail);
    final start = math.max(0.0, head - tail);
    final end = math.min(1.0, head);
    if (end <= start) return;
    const steps = 48;
    for (var i = 0; i < steps; i++) {
      final x0 = start + (end - start) * i / steps;
      final x1 = start + (end - start) * (i + 1) / steps;
      final fade = (i + 1) / steps;
      canvas.drawLine(
        _at(x0, size),
        _at(x1, size),
        Paint()
          ..color = color.withValues(alpha: 0.15 + 0.85 * fade)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    }
    if (head <= 1.0) {
      final tip = _at(end, size);
      canvas.drawCircle(tip, 7,
          Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(tip, 3.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_HeartbeatPainter old) =>
      old.progress != progress || old.color != color;
}
