import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/fd_palette.dart';
import '../services/account_service.dart';
import '../services/post_service.dart';
import 'explore_tab.dart' show FeedAvatar, kLinkBlue, showPostOptions;
import 'prototype_session.dart';

/// Reel colour themes (gradient top → bottom).
const reelThemes = <List<Color>>[
  [Color(0xFF4F46E5), Color(0xFF1E1B4B)], // 0 indigo
  [Color(0xFFE11D48), Color(0xFF4C0519)], // 1 rose
  [Color(0xFFDC2626), Color(0xFF450A0A)], // 2 red
  [Color(0xFF0284C7), Color(0xFF082F49)], // 3 sky
  [Color(0xFF16A34A), Color(0xFF052E16)], // 4 green
  [Color(0xFFD97706), Color(0xFF451A03)], // 5 amber
  [Color(0xFF7C3AED), Color(0xFF2E1065)], // 6 purple
  [Color(0xFFDB2777), Color(0xFF500724)], // 7 pink
  [Color(0xFF0D9488), Color(0xFF042F2E)], // 8 teal
];

const _reelIcons = <String, IconData>{
  'heart': Icons.favorite_rounded,
  'lungs': Icons.air_rounded,
  'bp': Icons.monitor_heart_rounded,
  'water': Icons.water_drop_rounded,
  'stretch': Icons.self_improvement_rounded,
  'mosquito': Icons.bug_report_rounded,
  'food': Icons.restaurant_rounded,
  'sun': Icons.wb_sunny_rounded,
  'sparkle': Icons.auto_awesome_rounded,
  'check': Icons.check_circle_rounded,
  'warning': Icons.warning_amber_rounded,
  'phone': Icons.call_rounded,
  'clock': Icons.timer_rounded,
  'brain': Icons.psychology_rounded,
  'skin': Icons.face_retouching_natural_rounded,
  'hospital': Icons.local_hospital_rounded,
  'walk': Icons.directions_walk_rounded,
  'moon': Icons.bedtime_rounded,
};

IconData reelIcon(String key) =>
    _reelIcons[key] ?? Icons.health_and_safety_rounded;

List<Color> reelColors(FeedPost reel) =>
    reelThemes[reel.theme.abs() % reelThemes.length];

// ======================================================================
// Static cover (grid tiles, feed cards, stories)
// ======================================================================

class ReelCover extends StatelessWidget {
  const ReelCover({super.key, required this.reel, this.showViews = true});
  final FeedPost reel;
  final bool showViews;

  @override
  Widget build(BuildContext context) {
    final colors = reelColors(reel);
    final first = reel.slides.isEmpty
        ? const ReelSlide(type: 'title', title: 'Health tip')
        : reel.slides.first;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final k = (math.min(c.maxWidth, c.maxHeight) / 300)
            .clamp(0.45, 1.6)
            .toDouble();
        final inner = math.max(1.0, c.maxWidth - 32 * k);
        return Stack(children: [
          Positioned(
            right: -c.maxWidth * 0.18,
            top: c.maxHeight * 0.08,
            child: Icon(reelIcon(first.icon),
                size: c.maxWidth * 0.8,
                color: Colors.white.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16 * k, 30 * k, 16 * k, 30 * k),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: inner,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(10 * k),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(reelIcon(first.icon),
                            color: Colors.white, size: 26 * k),
                      ),
                      SizedBox(height: 12 * k),
                      Text(
                        first.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24 * k,
                          height: 1.1,
                        ),
                      ),
                      if (first.body.isNotEmpty) ...[
                        SizedBox(height: 6 * k),
                        Text(first.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14 * k)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 8,
            right: 8,
            child: Icon(Icons.movie_creation_outlined,
                color: Colors.white,
                size: 20,
                shadows: [Shadow(blurRadius: 6, color: Colors.black45)]),
          ),
          if (showViews)
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(children: [
                const Icon(Icons.play_arrow_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 2),
                Text(PostService.count(reel.views),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ),
        ]);
      }),
    );
  }
}

// ======================================================================
// Animated player
// ======================================================================

class ReelPlayer extends StatefulWidget {
  const ReelPlayer({
    super.key,
    required this.reel,
    this.playing = true,
    this.interactive = true,
    this.captionOverlay = true,
  });
  final FeedPost reel;
  final bool playing;

  /// Tap to pause, double-tap to like. Off for previews.
  final bool interactive;

  /// Leaves room at the bottom for the caption drawn over the reel.
  final bool captionOverlay;

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _slide;
  int _index = 0;
  bool _paused = false;
  bool _heart = false;
  Timer? _heartTimer;

  List<ReelSlide> get _slides => widget.reel.slides.isEmpty
      ? const [ReelSlide(type: 'title', title: 'Health tip')]
      : widget.reel.slides;

  Duration _durationOf(int index) =>
      Duration(milliseconds: (_slides[index].seconds * 1000).round());

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
        vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
    _slide = AnimationController(vsync: this, duration: _durationOf(0))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      });
    if (widget.playing) _slide.forward();
  }

  @override
  void didUpdateWidget(covariant ReelPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id || _index >= _slides.length) {
      _index = 0;
      _paused = false;
      _slide
        ..duration = _durationOf(0)
        ..value = 0;
      if (widget.playing) _slide.forward();
    } else if (oldWidget.playing != widget.playing) {
      if (widget.playing && !_paused) {
        _slide.forward();
      } else {
        _slide.stop();
      }
    }
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    _ambient.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted) return;
    setState(() => _index = (_index + 1) % _slides.length);
    _slide
      ..duration = _durationOf(_index)
      ..forward(from: 0);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _slide.stop();
    } else if (widget.playing) {
      _slide.forward();
    }
  }

  void _doubleTap() {
    final user = PostService.userKey(context.read<PrototypeSession>().account);
    PostService.instance.like(widget.reel, user);
    setState(() => _heart = true);
    _heartTimer?.cancel();
    _heartTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _heart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = reelColors(widget.reel);
    final slides = _slides;
    if (_index >= slides.length) _index = 0;
    // Captured so the outgoing slide keeps showing its own content (fully
    // shown) while the next one fades in.
    final index = _index;
    final slide = slides[index];
    return GestureDetector(
      onTap: widget.interactive ? _togglePause : null,
      onDoubleTap: widget.interactive ? _doubleTap : null,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Moving gradient background.
            AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) {
                final t = _ambient.value * 2 * math.pi;
                return LayoutBuilder(builder: (context, c) {
                  return Stack(fit: StackFit.expand, children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(math.cos(t) * 0.6, -1),
                          end: Alignment(-math.cos(t) * 0.6, 1),
                          colors: colors,
                        ),
                      ),
                    ),
                    _Glow(
                      left: c.maxWidth * (0.55 + 0.25 * math.sin(t)),
                      top: c.maxHeight * (0.12 + 0.08 * math.cos(t)),
                      size: c.maxWidth * 0.9,
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                    _Glow(
                      left: c.maxWidth * (-0.3 + 0.2 * math.cos(t * 1.3)),
                      top: c.maxHeight * (0.62 + 0.06 * math.sin(t)),
                      size: c.maxWidth * 0.8,
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ]);
                });
              },
            ),
            // Slide content.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                          begin: const Offset(0, 0.06), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: AnimatedBuilder(
                key: ValueKey('${widget.reel.id}-$index'),
                animation: _slide,
                builder: (context, _) => _SlideView(
                  slide: slide,
                  progress: index == _index ? _slide.value : 1.0,
                  reel: widget.reel,
                  accent: colors.first,
                  captionOverlay: widget.captionOverlay,
                ),
              ),
            ),
            // Progress segments.
            Positioned(
              left: 10,
              right: 10,
              top: 10,
              child: AnimatedBuilder(
                animation: _slide,
                builder: (context, _) => Row(
                  children: [
                    for (var i = 0; i < slides.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            minHeight: 2.5,
                            value: i < _index
                                ? 1.0
                                : i == _index
                                    ? _slide.value
                                    : 0.0,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.35),
                            valueColor:
                                const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_paused)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 46),
                ),
              ),
            Center(
              child: AnimatedScale(
                scale: _heart ? 1 : 0.4,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _heart ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white,
                      size: 110,
                      shadows: [Shadow(blurRadius: 18, color: Colors.black38)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
  });
  final double left;
  final double top;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Positioned(
        left: left - size / 2,
        top: top - size / 2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      );
}

/// Draws one slide. [progress] runs 0 → 1 over the slide's duration.
class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.progress,
    required this.reel,
    required this.accent,
    required this.captionOverlay,
  });

  final ReelSlide slide;
  final double progress;
  final FeedPost reel;
  final Color accent;
  final bool captionOverlay;

  /// 0 → 1 over the first [portion] of the slide (for entrance animations).
  double _intro(double start, [double portion = 0.18]) =>
      Curves.easeOutCubic
          .transform(((progress - start) / portion).clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final k = math
          .min(c.maxWidth / 360, c.maxHeight / 640)
          .clamp(0.4, 1.6)
          .toDouble();
      final pad = EdgeInsets.fromLTRB(
          26 * k, 40 * k, 26 * k, captionOverlay ? 150 * k : 52 * k);
      final white =
          TextStyle(color: Colors.white, height: 1.15, fontSize: 18 * k);

      // Content is laid out at full width, then scaled down if it is taller
      // than the space available, so a slide can never overflow.
      Widget fitted(Widget column) => Padding(
            padding: pad,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: math.max(1.0, c.maxWidth - pad.horizontal),
                  child: column,
                ),
              ),
            ),
          );

      Widget fadeUp(double start, Widget child) {
        final v = _intro(start);
        return Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 24 * (1 - v)), child: child),
        );
      }

      Widget bubble(double size) => Container(
            padding: EdgeInsets.all(size * 0.28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(reelIcon(slide.icon), color: Colors.white, size: size),
          );

      switch (slide.type) {
        case 'step':
          return fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                fadeUp(
                  0,
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14 * k, vertical: 7 * k),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(reelIcon(slide.icon), color: accent, size: 18 * k),
                      SizedBox(width: 6 * k),
                      Flexible(
                        child: Text(slide.title,
                            style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 15 * k)),
                      ),
                    ]),
                  ),
                ),
                SizedBox(height: 22 * k),
                fadeUp(
                  0.06,
                  Text(slide.body,
                      style: white.copyWith(
                          fontSize: 30 * k, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        case 'check':
          final items = slide.body
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
          return fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                fadeUp(
                    0,
                    Text(slide.title,
                        style: white.copyWith(
                            fontSize: 28 * k, fontWeight: FontWeight.w800))),
                SizedBox(height: 20 * k),
                for (var i = 0; i < items.length; i++)
                  fadeUp(
                    0.12 + i * (0.6 / items.length),
                    Padding(
                      padding: EdgeInsets.only(bottom: 14 * k),
                      child: Row(children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 26 * k),
                        SizedBox(width: 12 * k),
                        Expanded(
                          child: Text(items[i],
                              style: white.copyWith(
                                  fontSize: 21 * k,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        case 'stat':
          return fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                fadeUp(
                    0,
                    Text(slide.title,
                        textAlign: TextAlign.center,
                        style: white.copyWith(
                            fontSize: 96 * k,
                            fontWeight: FontWeight.w900,
                            height: 1))),
                SizedBox(height: 16 * k),
                fadeUp(
                    0.1,
                    Text(slide.body,
                        textAlign: TextAlign.center,
                        style: white.copyWith(
                            fontSize: 22 * k, fontWeight: FontWeight.w600))),
              ],
            ),
          );
        case 'breath':
          // 4 s in · 4 s hold · 4 s out · 4 s hold.
          final t = progress * slide.seconds;
          final phase = (t / 4).floor() % 4;
          final local = (t % 4) / 4;
          final scale = switch (phase) {
            0 => 0.55 + 0.45 * Curves.easeInOut.transform(local),
            1 => 1.0,
            2 => 1.0 - 0.45 * Curves.easeInOut.transform(local),
            _ => 0.55,
          };
          const labels = ['Breathe in', 'Hold', 'Breathe out', 'Hold'];
          final count = 4 - (local * 4).floor();
          final size = 230 * k;
          return fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(slide.title,
                    textAlign: TextAlign.center,
                    style: white.copyWith(
                        fontSize: 24 * k, fontWeight: FontWeight.w800)),
                SizedBox(height: 26 * k),
                SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: Container(
                      width: size * scale,
                      height: size * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                        border: Border.all(color: Colors.white, width: 3 * k),
                      ),
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(labels[phase],
                              style: white.copyWith(
                                  fontSize: 20 * k,
                                  fontWeight: FontWeight.w700)),
                          Text('$count',
                              style: white.copyWith(
                                  fontSize: 44 * k,
                                  fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 22 * k),
                Text(slide.body,
                    textAlign: TextAlign.center,
                    style: white.copyWith(color: Colors.white70)),
              ],
            ),
          );
        case 'pulse':
          // A heart beating at 110 per minute — the CPR rhythm.
          const period = 60 / 110;
          final elapsed = progress * slide.seconds;
          final beatPhase = (elapsed % period) / period;
          final beat =
              beatPhase < 0.3 ? math.sin(beatPhase / 0.3 * math.pi) : 0.0;
          final pushes = (elapsed / period).floor() + 1;
          return fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(slide.title,
                    textAlign: TextAlign.center,
                    style: white.copyWith(
                        fontSize: 28 * k, fontWeight: FontWeight.w800)),
                SizedBox(height: 24 * k),
                Transform.scale(
                  scale: 1 + 0.2 * beat,
                  child: Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 150 * k),
                ),
                SizedBox(height: 10 * k),
                Text('$pushes',
                    style: white.copyWith(
                        fontSize: 40 * k, fontWeight: FontWeight.w900)),
                SizedBox(height: 16 * k),
                Text(slide.body,
                    textAlign: TextAlign.center,
                    style: white.copyWith(
                        fontSize: 18 * k, color: Colors.white70)),
              ],
            ),
          );
        case 'outro':
          return fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 0.6 + 0.4 * _intro(0, 0.25),
                  child: FeedAvatar(author: reel.author, size: 96 * k),
                ),
                SizedBox(height: 18 * k),
                fadeUp(
                    0.08,
                    Text(slide.title,
                        textAlign: TextAlign.center,
                        style: white.copyWith(
                            fontSize: 26 * k, fontWeight: FontWeight.w800))),
                SizedBox(height: 8 * k),
                fadeUp(
                    0.14,
                    Text(slide.body,
                        textAlign: TextAlign.center,
                        style: white.copyWith(color: Colors.white70))),
              ],
            ),
          );
        case 'title':
        default:
          return fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                    scale: 0.5 + 0.5 * _intro(0, 0.22), child: bubble(56 * k)),
                SizedBox(height: 26 * k),
                fadeUp(
                    0.08,
                    Text(slide.title,
                        textAlign: TextAlign.center,
                        style: white.copyWith(
                            fontSize: 38 * k, fontWeight: FontWeight.w900))),
                SizedBox(height: 12 * k),
                if (slide.body.isNotEmpty)
                  fadeUp(
                      0.16,
                      Text(slide.body,
                          textAlign: TextAlign.center,
                          style: white.copyWith(
                              fontSize: 20 * k, color: Colors.white70))),
              ],
            ),
          );
      }
    });
  }
}

// ======================================================================
// Reels viewer — Instagram desktop "Reels" layout
// ======================================================================

Future<void> showReelsViewerDialog(
    BuildContext context, List<FeedPost> reels, int index) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, _, __) => Stack(
      children: [
        Positioned.fill(
          child: ReelsViewer(
              reels: reels,
              initialIndex:
                  reels.isEmpty ? 0 : index.clamp(0, reels.length - 1).toInt(),
              onDark: true,
              active: true),
        ),
        Positioned(
          top: 10,
          right: 14,
          child: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
          ),
        ),
      ],
    ),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class ReelsViewer extends StatefulWidget {
  const ReelsViewer({
    super.key,
    required this.reels,
    this.initialIndex = 0,
    this.onDark = false,
    this.active = true,
  });

  final List<FeedPost> reels;
  final int initialIndex;

  /// True when shown over a dark backdrop (dialog), so controls are white.
  final bool onDark;

  /// Only plays while true (e.g. while the Reels tab is visible).
  final bool active;

  @override
  State<ReelsViewer> createState() => _ReelsViewerState();
}

class _ReelsViewerState extends State<ReelsViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _comments = false;
  DateTime _lastWheel = DateTime.fromMillisecondsSinceEpoch(0);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    PostService.instance.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markViewed());
  }

  @override
  void dispose() {
    PostService.instance.removeListener(_refresh);
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReelsViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reel was deleted: stay inside the list.
    if (widget.reels.isNotEmpty && _index >= widget.reels.length) {
      _index = widget.reels.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) _pages.jumpToPage(_index);
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Opens comments beside the reel, or in a window when there is no room.
  void _openComments(FeedPost reel, bool fitsBeside) {
    if (fitsBeside) {
      setState(() => _comments = !_comments);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 380,
          height: 540,
          child: _ReelComments(
            reel: reel,
            onClose: () => Navigator.pop(dialogContext),
          ),
        ),
      ),
    );
  }

  void _markViewed() {
    if (!mounted || widget.reels.isEmpty || !widget.active) return;
    final user = PostService.userKey(context.read<PrototypeSession>().account);
    PostService.instance.markViewed(widget.reels[_index], user);
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.reels.length) return;
    _pages.animateToPage(next,
        duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reels.isEmpty) {
      return Center(
        child: Text('No reels yet — create the first one!',
            style: TextStyle(
                color: widget.onDark
                    ? Colors.white
                    : context.fdColor(const Color(0xFF262626)))),
      );
    }
    final fg = widget.onDark
        ? Colors.white
        : context.fdColor(const Color(0xFF262626));

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _go(1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _go(-1);
          return KeyEventResult.handled;
        }
        if (widget.onDark && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.maybePop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerSignal: (signal) {
          if (signal is! PointerScrollEvent) return;
          final now = DateTime.now();
          if (now.difference(_lastWheel).inMilliseconds < 450) return;
          _lastWheel = now;
          _go(signal.scrollDelta.dy > 0 ? 1 : -1);
        },
        child: LayoutBuilder(builder: (context, constraints) {
          var cardH = (constraints.maxHeight - 32).clamp(300.0, 880.0).toDouble();
          var cardW = cardH * 9 / 16;
          final wide = constraints.maxWidth >= cardW + 180;
          if (!wide) {
            cardW = (constraints.maxWidth - 24).clamp(220.0, 600.0).toDouble();
            cardH = math.min(cardW * 16 / 9, constraints.maxHeight - 24);
            cardW = cardH * 9 / 16;
          }
          final fitsBeside = constraints.maxWidth >= cardW + 80 + 360 + 40;
          final showComments = _comments && fitsBeside;

          return Stack(
            children: [
              PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.reels.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                  _markViewed();
                },
                itemBuilder: (context, i) {
                  final reel = widget.reels[i];
                  return Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ReelCard(
                          reel: reel,
                          width: cardW,
                          height: cardH,
                          playing: widget.active && i == _index,
                          actionsInside: !wide,
                          onComments: () => _openComments(reel, fitsBeside),
                          onDeleted: widget.onDark
                              ? () => Navigator.maybePop(context)
                              : null,
                        ),
                        if (wide) ...[
                          const SizedBox(width: 14),
                          _ReelActions(
                            reel: reel,
                            color: fg,
                            onComments: () => _openComments(reel, fitsBeside),
                            onDeleted: widget.onDark
                                ? () => Navigator.maybePop(context)
                                : null,
                          ),
                        ],
                        if (showComments && i == _index) ...[
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 360,
                            height: cardH,
                            child: _ReelComments(
                              reel: reel,
                              onClose: () => setState(() => _comments = false),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              if (wide)
                Positioned(
                  right: 26,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavButton(
                          icon: Icons.keyboard_arrow_up_rounded,
                          enabled: _index > 0,
                          onTap: () => _go(-1),
                        ),
                        const SizedBox(height: 12),
                        _NavButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          enabled: _index < widget.reels.length - 1,
                          onTap: () => _go(1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: context.fdColor(const Color(0xFFEFEFEF)),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon,
                size: 26, color: context.fdColor(const Color(0xFF262626))),
          ),
        ),
      ),
    );
  }
}

class _ReelCard extends StatelessWidget {
  const _ReelCard({
    required this.reel,
    required this.width,
    required this.height,
    required this.playing,
    required this.actionsInside,
    required this.onComments,
    this.onDeleted,
  });

  final FeedPost reel;
  final double width;
  final double height;
  final bool playing;
  final bool actionsInside;
  final VoidCallback onComments;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<PrototypeSession>().account;
    final user = PostService.userKey(account);
    final service = PostService.instance;
    final following = service.isFollowing(user, reel.author.handle);
    final isMe = account != null &&
        PostService.authorFor(account).handle == reel.author.handle;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ReelPlayer(reel: reel, playing: playing),
            // Bottom shade for legible text.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x99000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: actionsInside ? 64 : 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    FeedAvatar(author: reel.author, size: 32),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(reel.author.handle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    if (reel.author.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          size: 14, color: Colors.white),
                    ],
                    if (!isMe) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () =>
                            service.toggleFollow(user, reel.author.handle),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(following ? 'Following' : 'Follow',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  Text(reel.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, height: 1.3)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.music_note_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${reel.author.handle} · Original audio',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5)),
                    ),
                    if (reel.author.isDemo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Demo',
                            style:
                                TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            if (actionsInside)
              Positioned(
                right: 6,
                bottom: 12,
                child: _ReelActions(
                    reel: reel,
                    color: Colors.white,
                    onComments: onComments,
                    onDeleted: onDeleted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Vertical action column: like, comment, share, save, more, audio.
class _ReelActions extends StatelessWidget {
  const _ReelActions({
    required this.reel,
    required this.color,
    required this.onComments,
    this.onDeleted,
  });

  final FeedPost reel;
  final Color color;
  final VoidCallback onComments;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final user = PostService.userKey(context.watch<PrototypeSession>().account);
    final service = PostService.instance;
    final liked = reel.likedBy.contains(user);
    final saved = reel.savedBy.contains(user);
    final label = TextStyle(
        color: color, fontSize: 12.5, fontWeight: FontWeight.w600);

    Widget action(IconData icon, String? count, VoidCallback onTap,
            {Color? iconColor, String? tooltip}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(children: [
            IconButton(
              tooltip: tooltip,
              onPressed: onTap,
              icon: Icon(icon, color: iconColor ?? color, size: 28),
            ),
            if (count != null) Text(count, style: label),
          ]),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        action(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          PostService.count(reel.likes),
          () => service.toggleLike(reel, user),
          iconColor: liked ? const Color(0xFFFF3040) : null,
          tooltip: 'Like',
        ),
        action(Icons.mode_comment_outlined,
            PostService.count(reel.comments.length), onComments,
            tooltip: 'Comment'),
        action(Icons.send_outlined, null, () async {
          await Clipboard.setData(
              ClipboardData(text: 'findoctor://reel/${reel.id}'));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')));
          }
        }, tooltip: 'Share'),
        action(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            null, () => service.toggleSave(reel, user),
            tooltip: 'Save'),
        action(Icons.more_horiz_rounded, null,
            () => showPostOptions(context, reel, onDeleted: onDeleted),
            tooltip: 'More options'),
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 1.5),
            gradient: LinearGradient(colors: reelColors(reel)),
          ),
          child: const Icon(Icons.music_note_rounded,
              color: Colors.white, size: 14),
        ),
      ],
    );
  }
}

class _ReelComments extends StatefulWidget {
  const _ReelComments({required this.reel, required this.onClose});
  final FeedPost reel;
  final VoidCallback onClose;

  @override
  State<_ReelComments> createState() => _ReelCommentsState();
}

class _ReelCommentsState extends State<_ReelComments> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(AppAccount? account) async {
    if (account == null || _input.text.trim().isEmpty) return;
    await PostService.instance.addComment(widget.reel, account, _input.text);
    _input.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<PrototypeSession>().account;
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));
    final comments = widget.reel.comments;

    return Material(
      color: context.fdColor(Colors.white),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(children: [
              IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                icon: Icon(Icons.close_rounded, color: ink),
              ),
              Expanded(
                child: Text('Comments',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: ink)),
              ),
              const SizedBox(width: 48),
            ]),
          ),
          Divider(height: 1, color: context.fdColor(const Color(0xFFEFEFEF))),
          Expanded(
            child: comments.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('No comments yet.',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: ink)),
                      const SizedBox(height: 4),
                      Text('Start the conversation.',
                          style: TextStyle(color: muted)),
                    ]),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final comment in comments)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FeedAvatar(author: comment.author, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(children: [
                                        TextSpan(
                                            text: '${comment.author.handle}  ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        TextSpan(
                                            text: PostService.timeAgo(
                                                comment.createdAt),
                                            style: TextStyle(
                                                color: muted, fontSize: 12)),
                                      ]),
                                      style: TextStyle(color: ink, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(comment.text,
                                        style: TextStyle(
                                            color: ink,
                                            fontSize: 14,
                                            height: 1.3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          Divider(height: 1, color: context.fdColor(const Color(0xFFEFEFEF))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(account),
                  style: TextStyle(color: ink, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    hintStyle: TextStyle(color: muted),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    _input.text.trim().isEmpty ? null : () => _send(account),
                child: Text('Post',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _input.text.trim().isEmpty
                            ? kLinkBlue.withValues(alpha: 0.35)
                            : kLinkBlue)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
