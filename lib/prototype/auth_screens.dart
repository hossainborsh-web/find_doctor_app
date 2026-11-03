import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/malaysia_hospitals.dart';
import '../core/constants/route_names.dart';
import '../core/domain/entities/user_role.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_style.dart';
import '../core/theme/fd_palette.dart';
import '../core/widgets/fd_widgets.dart';
import '../services/account_service.dart';
import 'prototype_session.dart';

// ============================================================================
// START / WELCOME SCREEN  (redesigned)
// Wide (>= 900px): split layout — intro + actions on the left,
//                  animated teal "live booking" showcase on the right.
// Compact (phones): showcase header on top, intro + actions below.
// ============================================================================

const _kTealDeep = Color(0xFF3730A3); // indigo 800
const _kInk = Color(0xFF1E1B4B); // indigo 950

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void signIn() => Navigator.pushNamed(context, RouteNames.login);
    void createAccount() =>
        Navigator.pushNamed(context, RouteNames.createAccount);

    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: LayoutBuilder(
                        builder: (context, c) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: c.maxHeight),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 580),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 24),
                                  child: _Entrance(
                                    child: _IntroContent(
                                      wide: true,
                                      onSignIn: signIn,
                                      onCreateAccount: createAccount,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Expanded(flex: 10, child: _ShowcasePanel()),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 400,
                  child: _ShowcasePanel(compact: true),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                    child: _Entrance(
                      child: _IntroContent(
                        wide: false,
                        onSignIn: signIn,
                        onCreateAccount: createAccount,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left side / lower half: brand, headline, specialties, actions, stats
// ---------------------------------------------------------------------------
class _IntroContent extends StatelessWidget {
  const _IntroContent({
    required this.wide,
    required this.onSignIn,
    required this.onCreateAccount,
  });

  final bool wide;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final ink = context.fdColor(AppColors.neutralBlack);
    final muted = context.fdColor(AppColors.darkGrey);
    final accent = context.fdColor(AppColors.primaryBlue);
    final small = MediaQuery.sizeOf(context).width < 380;

    final buttons = [
      _CtaButton(
        label: 'Sign in',
        icon: Icons.arrow_forward_rounded,
        filled: true,
        onPressed: onSignIn,
      ),
      _CtaButton(
        label: 'Create account',
        filled: false,
        onPressed: onCreateAccount,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wide) ...[
          Row(
            children: [
              const FdMedicalMark(size: 42),
              const SizedBox(width: 12),
              Text(
                'Find Doctor',
                style: AppTextStyles.headline2.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              _Pill(
                icon: Icons.location_on_outlined,
                label: 'Malaysia',
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 56),
        ],

        // live status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: context.fdColor(AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PulseDot(),
              const SizedBox(width: 8),
              Text(
                '120+ doctors available today',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // headline
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Find the right\ndoctor, '),
              TextSpan(
                text: 'right now.',
                style: TextStyle(color: accent),
              ),
            ],
          ),
          style: TextStyle(
            color: ink,
            fontSize: wide ? 54 : (small ? 32 : 36),
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: wide ? -2 : -1.2,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'Search verified clinicians across Malaysia, book in seconds, '
            'and keep your whole care journey in one place.',
            style: TextStyle(
              color: muted,
              fontSize: wide ? 17 : 15,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 22),

        // quick specialties
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SpecialtyChip(
                icon: Icons.favorite_outline_rounded,
                label: 'Cardiology',
                onTap: onSignIn),
            _SpecialtyChip(
                icon: Icons.child_care_rounded,
                label: 'Pediatrics',
                onTap: onSignIn),
            _SpecialtyChip(
                icon: Icons.mood_rounded, label: 'Dental', onTap: onSignIn),
            _SpecialtyChip(
                icon: Icons.psychology_outlined,
                label: 'Mental health',
                onTap: onSignIn),
            _SpecialtyChip(
                icon: Icons.spa_outlined, label: 'Skin', onTap: onSignIn),
          ],
        ),
        SizedBox(height: wide ? 34 : 26),

        // actions
        if (wide)
          Row(
            children: [
              Expanded(child: buttons[0]),
              const SizedBox(width: 12),
              Expanded(child: buttons[1]),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [buttons[0], const SizedBox(height: 10), buttons[1]],
          ),
        const SizedBox(height: 10),
        Align(
          alignment: wide ? Alignment.centerLeft : Alignment.center,
          child: TextButton.icon(
            onPressed: onCreateAccount,
            style: TextButton.styleFrom(foregroundColor: accent),
            icon: const Icon(Icons.medical_information_outlined, size: 18),
            label: const Text(
              'Are you a clinician? Join as a doctor',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(height: wide ? 30 : 20),
        Divider(color: context.fdColor(AppColors.borderGrey), height: 1),
        const SizedBox(height: 20),

        // stats
        const Row(
          children: [
            Expanded(child: _Stat(value: '500+', label: 'Verified doctors')),
            Expanded(child: _Stat(value: '4.9★', label: 'User rating')),
            Expanded(child: _Stat(value: '13', label: 'States covered')),
          ],
        ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.filled,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool filled;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = context.fdColor(AppColors.primaryBlue);
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (icon != null) ...[
          const SizedBox(width: 8),
          Icon(icon, size: 19),
        ],
      ],
    );
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    if (filled) {
      return SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: shape,
          ),
          child: content,
        ),
      );
    }
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.fdColor(AppColors.neutralBlack),
          backgroundColor: context.fdColor(Colors.white),
          side: BorderSide(color: context.fdColor(AppColors.borderGrey)),
          shape: shape,
        ),
        child: content,
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.fdColor(AppColors.primaryBlue);
    return Material(
      color: context.fdColor(Colors.white),
      shape: StadiumBorder(
        side: BorderSide(color: context.fdColor(AppColors.borderGrey)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.fdColor(AppColors.neutralBlack),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: context.fdColor(AppColors.neutralBlack),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.fdColor(AppColors.darkGrey),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.fdColor(AppColors.borderGrey)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 6 + 8 * _c.value,
              height: 6 + 8 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: green.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: green),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade + slide-up on first build.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Right side / top header: teal showcase with a live booking preview
// ---------------------------------------------------------------------------
class _ShowcasePanel extends StatelessWidget {
  const _ShowcasePanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact
        ? const BorderRadius.vertical(bottom: Radius.circular(36))
        : BorderRadius.circular(36);

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBlue, _kTealDeep, _kInk],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
            Positioned(
              right: -120,
              top: -120,
              child: _Ring(size: 380, alpha: 0.10),
            ),
            Positioned(
              left: -90,
              bottom: -140,
              child: _Ring(size: 320, alpha: 0.08),
            ),
            SafeArea(
              bottom: !compact,
              child: Column(
                children: [
                  if (compact)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(22, 14, 22, 0),
                      child: Row(
                        children: [
                          FdMedicalMark(size: 36),
                          SizedBox(width: 10),
                          Text(
                            'Find Doctor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.location_on_outlined,
                              size: 15, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('Malaysia',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 12 : 32),
                      child: const Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _ShowcaseComposition(),
                        ),
                      ),
                    ),
                  ),
                  if (!compact)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 22,
                        runSpacing: 10,
                        children: [
                          _TrustPoint(
                              icon: Icons.verified_user_outlined,
                              label: 'Verified care'),
                          _TrustPoint(
                              icon: Icons.favorite_border_rounded,
                              label: 'People first'),
                          _TrustPoint(
                              icon: Icons.hub_outlined,
                              label: 'One connected platform'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: alpha),
          width: 40,
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07);
    const gap = 26.0;
    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fixed-size scene that is scaled to fit by a FittedBox.
class _ShowcaseComposition extends StatelessWidget {
  const _ShowcaseComposition();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 440,
      height: 500,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 60,
            top: 100,
            width: 330,
            child: _Floating(
              amplitude: 4,
              period: 5200,
              child: _DoctorPreviewCard(),
            ),
          ),
          Positioned(
            left: 0,
            top: 44,
            child: _Floating(
              amplitude: 7,
              period: 3800,
              child: _FloatChip(
                icon: Icons.videocam_rounded,
                iconBg: Color(0xFFE0E7FF),
                iconColor: AppColors.primaryBlue,
                title: 'Video consult',
                subtitle: 'Starts in 5 min',
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 6,
            child: _Floating(
              amplitude: 6,
              period: 4400,
              phase: 1.6,
              child: _FloatChip(
                icon: Icons.check_rounded,
                iconBg: Color(0xFFDCFCE7),
                iconColor: Color(0xFF16A34A),
                title: 'Appointment confirmed',
                subtitle: 'Tue, 12 Nov · 10:30 AM',
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _Floating(
              amplitude: 5,
              period: 3400,
              phase: 0.8,
              child: _RatingBubble(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorPreviewCard extends StatelessWidget {
  const _DoctorPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x401E1B4B),
            blurRadius: 40,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/doctor_emily_chen.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.lightBlue,
                    alignment: Alignment.center,
                    child: const Text(
                      'EC',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Dr. Emily Chen',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _kInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.verified_rounded,
                            size: 17, color: AppColors.primaryBlue),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Cardiologist · Gleneagles KL',
                      style: TextStyle(color: AppColors.darkGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _MiniInfo(icon: Icons.star_rounded, color: Color(0xFFF59E0B),
                  text: '4.9 (312)'),
              SizedBox(width: 8),
              _MiniInfo(icon: Icons.work_outline_rounded,
                  color: AppColors.primaryBlue, text: '12 yrs'),
              SizedBox(width: 8),
              _MiniInfo(icon: Icons.near_me_outlined,
                  color: AppColors.primaryBlue, text: '1.2 km'),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'NEXT AVAILABLE · TODAY',
            style: TextStyle(
              color: AppColors.darkGrey,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: _Slot(time: '9:30 AM')),
              SizedBox(width: 8),
              Expanded(child: _Slot(time: '10:30 AM', selected: true)),
              SizedBox(width: 8),
              Expanded(child: _Slot(time: '2:15 PM')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kInk,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Book visit · RM150',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: _kInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.time, this.selected = false});

  final String time;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryBlue : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primaryBlue : AppColors.borderGrey,
        ),
      ),
      child: Text(
        time,
        style: TextStyle(
          color: selected ? Colors.white : _kInk,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331E1B4B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style:
                    const TextStyle(color: AppColors.darkGrey, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingBubble extends StatelessWidget {
  const _RatingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
              Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
              Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
              Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
              Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '10k+ reviews',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gentle up-and-down float animation.
class _Floating extends StatefulWidget {
  const _Floating({
    required this.child,
    this.amplitude = 6,
    this.period = 4000,
    this.phase = 0,
  });

  final Widget child;
  final double amplitude;
  final int period;
  final double phase;

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.period),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          math.sin(_c.value * 2 * math.pi + widget.phase) * widget.amplitude,
        ),
        child: child,
      ),
    );
  }
}

class _TrustPoint extends StatelessWidget {
  const _TrustPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.aqua, size: 17),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                color: Color(0xFFE0ECF7),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.borderGrey),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText2
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  size: 17, color: AppColors.primaryBlue),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscure = true;
  bool isLoading = false;
  String? errorMessage;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Enter your email address and password.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final account = await AccountService.instance.signIn(
        email: email,
        password: password,
      );
      if (!mounted) return;
      context.read<PrototypeSession>().signInWithAccount(account);
      if (account.mustChangePassword) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.changePassword,
          (_) => false,
          arguments: password,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.explore,
          (_) => false,
        );
      }
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = error.message;
        if (error.code == 'WRONG_PASSWORD') _passwordController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Sign-in could not be completed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.fdColor(AppColors.neutralBlack);
    final muted = context.fdColor(AppColors.darkGrey);
    final accent = context.fdColor(AppColors.primaryBlue);
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: context.isNightMode
                  ? const [
                      Color(0xFF151933),
                      Color(0xFF0F1222),
                      Color(0xFF1A1636),
                    ]
                  : const [
                      Color(0xFFEEF0FF),
                      Color(0xFFFAFAFF),
                      Color(0xFFEDE9FE),
                    ],
              stops: const [0, .56, 1]),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: _CenteredMax(
                minHeight: constraints.maxHeight - 30,
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    const _FindDoctorLogo(),
                    const SizedBox(height: 42),
                    Text('Sign in to your Find Doctor account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, color: muted, letterSpacing: -.1)),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      decoration: BoxDecoration(
                          color: context
                              .fdColor(Colors.white)
                              .withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(17),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x1413455B),
                                blurRadius: 24,
                                offset: Offset(0, 9))
                          ]),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email Address',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ink)),
                            const SizedBox(height: 5),
                            _LoginInput(
                                controller: _emailController,
                                hint: 'you@example.com',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 18),
                            Row(children: [
                              Text('Password',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ink)),
                              const Spacer(),
                              InkWell(
                                  onTap: () => Navigator.pushNamed(
                                      context, RouteNames.forgotPassword),
                                  child: Text('Forgot Password?',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: accent))),
                            ]),
                            const SizedBox(height: 5),
                            _LoginInput(
                                controller: _passwordController,
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                obscure: obscure,
                                suffix: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        setState(() => obscure = !obscure),
                                    icon: Icon(
                                        obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                        color: muted))),
                            if (errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFF6CBC7)),
                                ),
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                      color: Color(0xFF9B2C27), fontSize: 12),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: isLoading ? null : _signIn,
                                child: isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Sign In'),
                              ),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 17),
                    Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text("Don't have an account? ",
                              style: TextStyle(fontSize: 13, color: muted)),
                          GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, RouteNames.createAccount),
                              child: Text('Sign Up',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: accent))),
                        ]),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal padding that keeps forms ~620px wide on desktop windows.
EdgeInsets _formPadding(BuildContext context, double top, double bottom) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(20.0, (width - 620) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Centers auth content and caps its width so forms don't stretch across a
/// wide desktop window.
class _CenteredMax extends StatelessWidget {
  const _CenteredMax({required this.minHeight, required this.child});

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          minHeight: math.max(0, minHeight),
        ),
        child: child,
      ),
    );
  }
}

class _FindDoctorLogo extends StatelessWidget {
  const _FindDoctorLogo();

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FdMedicalMark(size: 78),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: 'Find ',
                  style: TextStyle(
                      color: context.fdColor(const Color(0xFF1E1B4B)))),
              TextSpan(
                  text: 'Doctor',
                  style: TextStyle(
                      color: context.fdColor(const Color(0xFF4F46E5))))
            ]),
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.7),
          ),
        ],
      );
}

class _LoginInput extends StatelessWidget {
  const _LoginInput(
      {this.controller,
      required this.hint,
      required this.icon,
      this.keyboardType,
      this.obscure = false,
      this.suffix});
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 42,
      child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: TextStyle(
              fontSize: 13, color: context.fdColor(AppColors.neutralBlack)),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: context.isNightMode
                      ? const Color(0xFF6B7192)
                      : const Color(0xFFBEC8D8)),
              prefixIcon: Icon(icon,
                  size: 17, color: context.fdColor(AppColors.darkGrey)),
              prefixIconConstraints: const BoxConstraints(minWidth: 38),
              suffixIcon: suffix,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
              filled: true,
              fillColor: context.fdColor(Colors.white),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: context.isNightMode
                          ? const Color(0xFF33385A)
                          : const Color(0xFFC9D3E1))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: context.fdColor(AppColors.primaryBlue),
                      width: 1.4)))));
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => const SizedBox(
      width: 18,
      height: 18,
      child: Center(
          child: Text('G',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4285F4)))));
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _universityController = TextEditingController();
  final _graduationYearController = TextEditingController();
  final _previousHospitalController = TextEditingController();
  UserRole _role = UserRole.patient;
  DoctorKind _doctorKind = DoctorKind.student;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  /// Students and New Doctors (job seekers). Doctor, Doctor Manager and
  /// Manager can't be chosen here: HR gives them.
  bool get _isDoctor => _role == UserRole.doctor;
  bool get _isStudent => _isDoctor && _doctorKind == DoctorKind.student;
  bool get _isNewDoctor => _isDoctor && _doctorKind == DoctorKind.newDoctor;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _birthdayController.dispose();
    _specialtyController.dispose();
    _universityController.dispose();
    _graduationYearController.dispose();
    _previousHospitalController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = null);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AccountService.instance.register(
        fullName: _nameController.text,
        email: _emailController.text,
        role: _role,
        doctorKind: _isDoctor ? _doctorKind : null,
        specialty: _isNewDoctor ? _specialtyController.text : '',
        birthday: _birthdayController.text,
        university: _isStudent ? _universityController.text : '',
        graduationYear: _isStudent ? _graduationYearController.text : '',
        previousHospital:
            _isNewDoctor ? _previousHospitalController.text : '',
        password: _passwordController.text,
      );
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pushReplacementNamed(context, RouteNames.login);
      messenger.showSnackBar(SnackBar(
        content: Text(_isDoctor
            ? 'Account created. Sign in, upload your graduation certificate '
                'and ask hospitals for work.'
            : 'Account created. You can sign in now.'),
      ));
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not create the account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const buttonLabel = 'Create account';

    return Scaffold(
      appBar: const FdAppBar(title: 'Create account', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: _formPadding(context, 18, 28),
          children: [
            Text('Register with Find Doctor', style: AppTextStyles.headline2),
            const SizedBox(height: 8),
            Text(
              'Choose your account type.',
              style: AppTextStyles.secondary,
            ),
            const SizedBox(height: 20),
            for (final option in const [
              (
                UserRole.patient,
                Icons.person_outline_rounded,
                'Find verified doctors, book visits and chat with them.'
              ),
              (
                UserRole.doctor,
                Icons.school_outlined,
                'Student or New Doctor looking to work at a hospital.'
              ),
            ])
              _RoleOption(
                role: option.$1,
                selected: _role,
                icon: option.$2,
                title: option.$1 == UserRole.doctor
                    ? 'Graduate or doctor'
                    : option.$1.displayName,
                description: option.$3,
                onTap: _isLoading
                    ? () {}
                    : () => setState(() {
                          _role = option.$1;
                          _errorMessage = null;
                        }),
              ),
            if (_isDoctor) ...[
              const SizedBox(height: 4),
              Text('Which one are you?',
                  style: AppTextStyles.bodyText2
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _DoctorKindSelector(
                selected: _doctorKind,
                enabled: !_isLoading,
                onChanged: (kind) => setState(() {
                  _doctorKind = kind;
                  _errorMessage = null;
                }),
              ),
              const SizedBox(height: 12),
              const FdPreviewNotice(
                message: 'After signing up, upload your graduation '
                    'certificate and ask hospitals for work. Hospital HR '
                    'hires you as a Doctor after your join day. Doctor and '
                    'Doctor Manager roles are given by HR only.',
              ),
            ],
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your full name.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(email)
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) <
                              AccountService.minPasswordLength
                          ? 'Use at least ${AccountService.minPasswordLength} characters.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password'),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _BirthdayField(controller: _birthdayController),
                  if (_isStudent) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _universityController,
                      enabled: !_isLoading,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'University',
                          hintText: 'e.g. Universiti Malaya'),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter the university you graduated from.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _graduationYearController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Graduation year', hintText: '2026'),
                      validator: (value) {
                        final year = int.tryParse(value?.trim() ?? '');
                        final now = DateTime.now().year;
                        return year == null || year < 1950 || year > now + 1
                            ? 'Enter your graduation year.'
                            : null;
                      },
                    ),
                  ],
                  if (_isNewDoctor) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _specialtyController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                          labelText: 'Specialty', hintText: 'Cardiology'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter your specialty.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _previousHospitalController,
                      enabled: !_isLoading,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Previous hospital (optional)',
                          hintText: 'Where you worked before'),
                    ),
                  ],
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.errorRed)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _createAccount,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(buttonLabel),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.pushReplacementNamed(
                        context, RouteNames.login),
                child: const Text('Already have an account? Sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorKindSelector extends StatelessWidget {
  const _DoctorKindSelector({
    required this.selected,
    required this.onChanged,
    required this.enabled,
  });

  final DoctorKind selected;
  final ValueChanged<DoctorKind> onChanged;
  final bool enabled;

  static const _icons = {
    DoctorKind.student: Icons.school_outlined,
    DoctorKind.newDoctor: Icons.medical_services_outlined,
    DoctorKind.doctor: Icons.medical_services_outlined,
    DoctorKind.doctorManager: Icons.admin_panel_settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final accent = context.fdColor(AppColors.primaryBlue);
    return Column(
      children: [
        for (final kind in DoctorKind.values.where((kind) => kind.canSignUp))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: kind == selected
                  ? context.fdColor(AppColors.surfaceMuted)
                  : context.fdColor(Colors.white),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: enabled ? () => onChanged(kind) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: kind == selected
                          ? accent
                          : context.fdColor(AppColors.borderGrey),
                      width: kind == selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_icons[kind], color: accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind.displayName,
                                style: AppTextStyles.bodyText1.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context
                                        .fdColor(AppColors.neutralBlack))),
                            const SizedBox(height: 2),
                            Text(kind.description,
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Icon(
                        kind == selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: kind == selected
                            ? accent
                            : context.fdColor(AppColors.darkGrey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tappable field that opens a searchable list of Malaysian hospitals.
class _HospitalPickerField extends StatelessWidget {
  const _HospitalPickerField({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _HospitalPickerDialog(initial: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    MalaysiaHospital? hospital;
    for (final item in malaysiaHospitals) {
      if (item.name == value) hospital = item;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: const InputDecoration(
          labelText: 'Hospital',
          hintText: 'Choose your hospital in Malaysia',
          prefixIcon: Icon(Icons.local_hospital_outlined),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded),
        ),
        child: value == null
            ? null
            : Text(
                hospital == null ? value! : '${hospital.name} · ${hospital.state}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}

/// Opens the searchable list of Malaysian hospitals; returns the name.
Future<String?> showHospitalPicker(BuildContext context, {String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _HospitalPickerDialog(initial: initial),
    );

class _HospitalPickerDialog extends StatefulWidget {
  const _HospitalPickerDialog({this.initial});

  final String? initial;

  @override
  State<_HospitalPickerDialog> createState() => _HospitalPickerDialogState();
}

class _HospitalPickerDialogState extends State<_HospitalPickerDialog> {
  String _query = '';
  String _state = 'All states';

  @override
  Widget build(BuildContext context) {
    final states = <String>{'All states', ...malaysiaHospitals.map((h) => h.state)}
        .toList();
    final query = _query.trim().toLowerCase();
    final results = malaysiaHospitals.where((hospital) {
      final matchesState = _state == 'All states' || hospital.state == _state;
      final matchesQuery = query.isEmpty ||
          hospital.name.toLowerCase().contains(query) ||
          hospital.state.toLowerCase().contains(query);
      return matchesState && matchesQuery;
    }).toList();
    final accent = context.fdColor(AppColors.primaryBlue);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Choose your hospital',
                        style: AppTextStyles.subtitle2),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text('${malaysiaHospitals.length} public and private hospitals in Malaysia',
                  style: AppTextStyles.caption),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search by hospital name or state',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: states.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, index) {
                    final state = states[index];
                    final selected = state == _state;
                    return ChoiceChip(
                      label: Text(state),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : context.fdColor(AppColors.neutralBlack),
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: accent,
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _state = state),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text('No hospitals match "$_query".',
                            style: AppTextStyles.secondary),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (_, index) {
                          final hospital = results[index];
                          final selected = hospital.name == widget.initial;
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            selected: selected,
                            selectedTileColor:
                                context.fdColor(AppColors.surfaceMuted),
                            leading: Icon(
                              hospital.isPublic
                                  ? Icons.account_balance_outlined
                                  : Icons.local_hospital_outlined,
                              color: accent,
                            ),
                            title: Text(hospital.name),
                            subtitle: Text(
                                '${hospital.state} · ${hospital.isPublic ? 'Public' : 'Private'}'),
                            trailing: selected
                                ? Icon(Icons.check_rounded, color: accent)
                                : null,
                            onTap: () => Navigator.pop(context, hospital.name),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final UserRole role;
  final UserRole selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = role == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.fdColor(Colors.white),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? context.fdColor(AppColors.primaryBlue)
                    : context.fdColor(AppColors.borderGrey),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: context.fdColor(AppColors.primaryBlue)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.subtitle2.copyWith(
                              fontSize: 16,
                              color: context.fdColor(AppColors.neutralBlack))),
                      const SizedBox(height: 4),
                      Text(description,
                          style: AppTextStyles.caption.copyWith(
                              color: context.fdColor(AppColors.darkGrey))),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? context.fdColor(AppColors.primaryBlue)
                      : context.fdColor(AppColors.darkGrey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum DocumentUploadKind { certificate, ownership }

/// Passed from sign-up to the document upload step.
class DocumentUploadArgs {
  const DocumentUploadArgs({
    required this.kind,
    required this.email,
    required this.awaitingApproval,
    this.hospital = '',
  });

  final DocumentUploadKind kind;
  final String email;

  /// True for New Doctors and Doctors (a Doctor Manager must approve them).
  final bool awaitingApproval;
  final String hospital;
}

/// Shown after a New Doctor / Doctor sends their sign-up request.
class DoctorRequestSentScreen extends StatelessWidget {
  const DoctorRequestSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as DocumentUploadArgs?;
    final hospital = args?.hospital ?? '';
    final accent = context.fdColor(AppColors.primaryBlue);
    final ink = context.fdColor(AppColors.primaryBlueDark);

    Widget step(IconData icon, String text, {bool done = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.successGreen.withValues(alpha: 0.12)
                      : context.fdColor(AppColors.surfaceMuted),
                  shape: BoxShape.circle,
                ),
                child: Icon(done ? Icons.check_rounded : icon,
                    size: 18, color: done ? AppColors.successGreen : accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: AppTextStyles.bodyText2.copyWith(color: ink))),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      body: SafeArea(
        child: ListView(
          padding: _formPadding(context, 48, 28),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mark_email_read_outlined,
                    size: 46, color: accent),
              ),
            ),
            const SizedBox(height: 20),
            Text('Request sent',
                textAlign: TextAlign.center, style: AppTextStyles.headline2),
            const SizedBox(height: 8),
            Text(
              hospital.isEmpty
                  ? 'Your request was sent to the Doctor Managers. When one of them approves it, they will send you a password.'
                  : 'Your request was sent to the Doctor Manager of $hospital. When they approve it, they will send you a password.',
              textAlign: TextAlign.center,
              style: AppTextStyles.secondary,
            ),
            const SizedBox(height: 14),
            const Center(
              child: FdStatusChip(
                  label: 'Waiting for approval', tone: FdStatusTone.warning),
            ),
            const SizedBox(height: 24),
            FdCard(
              child: Column(
                children: [
                  step(Icons.send_outlined, 'Request sent', done: true),
                  step(Icons.fact_check_outlined,
                      'A Doctor Manager reviews your request'),
                  step(Icons.key_outlined,
                      'You receive your password from the Doctor Manager'),
                  step(Icons.lock_reset_outlined,
                      'Sign in with your email and that password, then set your own'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FdButton(
              label: 'Go to sign in',
              icon: Icons.login_rounded,
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, RouteNames.login, (route) => route.isFirst),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, RouteNames.initial, (_) => false),
                child: const Text('Back to start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets a signed-in user replace their password. When opened right after
/// signing in with a password from a Doctor Manager, that password is passed
/// as the route argument so the user only types the new one.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  String? get _issuedPassword =>
      ModalRoute.of(context)?.settings.arguments as String?;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _goToApp() => Navigator.pushNamedAndRemoveUntil(
      context, RouteNames.explore, (_) => false);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AccountService.instance.changePassword(
        currentPassword: _issuedPassword ?? _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed.')),
      );
      if (_issuedPassword != null) {
        _goToApp();
      } else {
        Navigator.pop(context);
      }
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstSignIn = _issuedPassword != null;
    final toggle = IconButton(
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
    );

    return Scaffold(
      appBar: FdAppBar(title: 'Change password', showBack: !firstSignIn),
      body: SafeArea(
        child: ListView(
          padding: _formPadding(context, 18, 28),
          children: [
            if (firstSignIn) ...[
              const FdPreviewNotice(
                  message:
                      'You signed in with the password your Doctor Manager sent. Set your own password now, or keep it for later.'),
              const SizedBox(height: 18),
            ],
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!firstSignIn) ...[
                    TextFormField(
                      controller: _currentController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                          labelText: 'Current password', suffixIcon: toggle),
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Enter your current password.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _newController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                        labelText: 'New password', suffixIcon: toggle),
                    validator: (value) => (value?.length ?? 0) <
                            AccountService.minPasswordLength
                        ? 'Use at least ${AccountService.minPasswordLength} characters.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscure,
                    decoration:
                        const InputDecoration(labelText: 'Confirm new password'),
                    validator: (value) => value != _newController.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
            ],
            const SizedBox(height: 22),
            FdButton(
              label: _saving ? 'Saving…' : 'Save new password',
              icon: Icons.lock_reset_outlined,
              onPressed: _saving ? null : _save,
            ),
            if (firstSignIn) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _goToApp,
                  child: const Text('Keep this password for now'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

/// Demo-only upload step: accepts ANY image (or any file), shows a preview,
/// and never validates or sends anything anywhere.
class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  static const _imageExtensions = {
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'tif', 'tiff', 'ico',
  };

  String? _filePath;
  String? _fileName;
  bool _picking = false;

  bool get _hasFile => _fileName != null;

  bool get _isImage {
    final path = _filePath;
    if (path == null || !path.contains('.')) return false;
    return _imageExtensions.contains(path.split('.').last.toLowerCase());
  }

  Future<void> _chooseFile() async {
    if (_picking) return;
    setState(() => _picking = true);

    String? path;
    var dialogAvailable = false;
    if (!kIsWeb && Platform.isWindows) {
      dialogAvailable = true;
      try {
        path = await _openWindowsFileDialog();
      } catch (_) {
        dialogAvailable = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _picking = false;
      if (path != null && path.isNotEmpty) {
        _filePath = path;
        _fileName = path.split(RegExp(r'[\\/]')).last;
      } else if (!dialogAvailable) {
        // No native dialog on this platform: accept a placeholder file.
        _filePath = null;
        _fileName = 'sample-document.png';
      }
    });
  }

  /// Shows the standard Windows "Open" dialog (always on top) and returns the
  /// chosen path, or null if the user cancelled. No packages required.
  static Future<String?> _openWindowsFileDialog() async {
    const script = r"[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
        r"Add-Type -AssemblyName System.Windows.Forms; "
        r"$owner = New-Object System.Windows.Forms.Form -Property @{TopMost = $true; ShowInTaskbar = $false}; "
        r"$dialog = New-Object System.Windows.Forms.OpenFileDialog; "
        r"$dialog.Title = 'Choose any image'; "
        r"$dialog.Filter = 'Images|*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.webp|All files|*.*'; "
        r"$dialog.InitialDirectory = [Environment]::GetFolderPath('MyPictures'); "
        r"if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::Out.Write($dialog.FileName) }; "
        r"$owner.Dispose()";
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command', script],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    final output = (result.stdout as String).trim();
    return output.isEmpty ? null : output;
  }

  void _removeFile() => setState(() {
        _filePath = null;
        _fileName = null;
      });

  Object? get _args => ModalRoute.of(context)?.settings.arguments;

  bool get _awaitingApproval {
    final args = _args;
    return args is DocumentUploadArgs && args.awaitingApproval;
  }

  Future<void> _submit() async {
    final args = _args;
    if (args is! DocumentUploadArgs) {
      Navigator.pushNamedAndRemoveUntil(
          context, RouteNames.verificationPending, (_) => false);
      return;
    }
    final fileName = _fileName;
    if (fileName != null) {
      await AccountService.instance.attachDocument(args.email, fileName);
    }
    if (!mounted) return;
    if (args.awaitingApproval) {
      Navigator.pushNamedAndRemoveUntil(
          context, RouteNames.requestSent, (route) => route.isFirst,
          arguments: args);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pushNamedAndRemoveUntil(
        context, RouteNames.login, (route) => route.isFirst);
    messenger.showSnackBar(const SnackBar(
        content: Text('Account created. Sign in with your email and password.')));
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    final kind = args is DocumentUploadArgs
        ? args.kind
        : args is DocumentUploadKind
            ? args
            : DocumentUploadKind.certificate;
    final title = switch (kind) {
      DocumentUploadKind.certificate => 'Medical Graduation Certificate',
      DocumentUploadKind.ownership => 'Hospital License',
    };
    final requirement = switch (kind) {
      DocumentUploadKind.certificate =>
        'Upload a photo of your medical graduation certificate. Any image is accepted in this version.',
      DocumentUploadKind.ownership =>
        'Upload a photo of your hospital license. Any image is accepted in this version.',
    };
    final accent = context.fdColor(AppColors.primaryBlue);
    final ink = context.fdColor(AppColors.primaryBlueDark);
    final muted = context.fdColor(AppColors.darkGrey);

    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(title: title, showBack: true),
      body: ListView(
        padding: _formPadding(context, 18, 28),
        children: [
          const FdPreviewNotice(
              message:
                  'Demo upload: any image is accepted and nothing is sent or checked.'),
          const SizedBox(height: 16),
          FdCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload requirements',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 8),
                Text(requirement,
                    style: TextStyle(fontSize: 13, height: 1.55, color: muted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          CustomPaint(
            painter: _DashedBorderPainter(
                color: _hasFile
                    ? accent
                    : context.fdColor(const Color(0xFFB9C4D1))),
            child: Container(
              constraints: const BoxConstraints(minHeight: 270),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.fdColor(Colors.white),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _hasFile
                  ? _buildPreview(accent, ink, muted)
                  : _buildEmptyPicker(accent, ink, muted),
            ),
          ),
          const SizedBox(height: 22),
          FdButton(
            label: _hasFile
                ? (_awaitingApproval ? 'Send request' : 'Submit')
                : 'Choose an image first',
            icon: _hasFile ? Icons.check_rounded : null,
            onPressed: _hasFile ? _submit : null,
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _submit,
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPicker(Color accent, Color ink, Color muted) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.fdColor(AppColors.surfaceMuted),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add_photo_alternate_outlined,
              color: accent, size: 30),
        ),
        const SizedBox(height: 16),
        Text('Choose any image',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 6),
        Text('PNG, JPG, screenshots — anything works',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _picking ? null : _chooseFile,
          icon: _picking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(_picking ? 'Opening…' : 'Browse files'),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(Color accent, Color ink, Color muted) {
    final path = _filePath;
    final Widget preview;
    if (path != null && _isImage) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(path),
          height: 220,
          fit: BoxFit.contain,
          cacheHeight: 600,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.image_outlined, size: 72, color: accent),
        ),
      );
    } else {
      preview = Icon(Icons.insert_drive_file_outlined, size: 72, color: accent);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        preview,
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.successGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _fileName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Accepted', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _picking ? null : _chooseFile,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Change'),
            ),
            TextButton.icon(
              onPressed: _removeFile,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove'),
              style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    void drawHorizontal(double y) {
      for (double x = 8; x < size.width - 8; x += dash + gap) {
        canvas.drawLine(Offset(x, y),
            Offset((x + dash).clamp(0, size.width - 8).toDouble(), y), paint);
      }
    }

    void drawVertical(double x) {
      for (double y = 8; y < size.height - 8; y += dash + gap) {
        canvas.drawLine(Offset(x, y),
            Offset(x, (y + dash).clamp(0, size.height - 8).toDouble()), paint);
      }
    }

    drawHorizontal(1);
    drawHorizontal(size.height - 1);
    drawVertical(1);
    drawVertical(size.width - 1);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    return Scaffold(
      appBar: const FdAppBar(title: 'Verification'),
      body: Padding(
        padding: _formPadding(context, 24, 24),
        child: Column(
          children: [
            const FdPreviewNotice(
                message: 'Example status only · no submission is under review'),
            const SizedBox(height: 16),
            const Icon(Icons.hourglass_empty,
                size: 48, color: AppColors.warningOrange),
            const SizedBox(height: 16),
            Text('Account under review',
                style: AppTextStyles.headline2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'This is a sample pending state. Nothing was sent for review.',
              style: AppTextStyles.secondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const FdStatusChip(label: 'Pending', tone: FdStatusTone.warning),
            const Spacer(),
            if (session.role == UserRole.doctor && !session.doctorApproved)
              FdButton(
                label: 'View pending doctor access',
                outlined: true,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.doctorPendingGate),
              ),
            const SizedBox(height: 12),
            FdButton(
              label: session.role?.usesPatientWorkspace ?? false
                  ? 'Continue to app'
                  : 'Return to start',
              onPressed: () {
                if (session.role?.usesPatientWorkspace ?? false) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, RouteNames.explore, (_) => false);
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                      context, RouteNames.initial, (_) => false);
                }
              },
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.verificationRejected),
              child: const Text('View rejection example'),
            ),
          ],
        ),
      ),
    );
  }
}

class VerificationRejectedScreen extends StatelessWidget {
  const VerificationRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Verification rejected', showBack: true),
      body: Padding(
        padding: _formPadding(context, 24, 24),
        child: Column(
          children: [
            const FdPreviewNotice(
                message:
                    'Example rejection state · no application was reviewed'),
            const SizedBox(height: 16),
            const Icon(Icons.cancel_outlined,
                size: 48, color: AppColors.errorRed),
            const SizedBox(height: 16),
            Text('Documents could not be verified',
                style: AppTextStyles.headline2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Example rejection reason: the certificate needs certification. No document was submitted or reviewed.',
              style: AppTextStyles.secondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const FdStatusChip(label: 'Rejected', tone: FdStatusTone.danger),
            const Spacer(),
            FdButton(
              label: 'Upload again',
              onPressed: () => Navigator.pushReplacementNamed(
                context,
                RouteNames.documentUpload,
                arguments: DocumentUploadKind.certificate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DoctorPendingGateScreen extends StatelessWidget {
  const DoctorPendingGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Doctor access pending', showBack: true),
      body: Padding(
        padding: _formPadding(context, 24, 24),
        child: Column(
          children: [
            Text(
              'Doctor accounts remain pending until an authorised manager approves them.',
              style: AppTextStyles.bodyText1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const FdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Restricted until approval'),
                  SizedBox(height: 8),
                  Text(
                      'Consultations, operations, and public posting stay unavailable.'),
                ],
              ),
            ),
            const Spacer(),
            FdButton(
              label: 'Return to sign in',
              onPressed: () async {
                await context.read<PrototypeSession>().signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, RouteNames.initial, (_) => false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String _sentMessage = '';
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final message =
          await AccountService.instance.passwordHelp(_emailController.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _sent = true;
        _sentMessage = message;
      });
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.fdColor(AppColors.neutralBlack);
    final muted = context.fdColor(AppColors.darkGrey);
    final accent = context.fdColor(AppColors.primaryBlue);
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: context.isNightMode
                  ? const [
                      Color(0xFF0F1222),
                      Color(0xFF0F1222),
                      Color(0xFF161A31),
                    ]
                  : const [
                      Color(0xFFF7F9FC),
                      Colors.white,
                      Color(0xFFEEF0FF),
                    ]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                decoration: BoxDecoration(
                    color: context.fdColor(Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x10173B5A),
                          blurRadius: 22,
                          offset: Offset(0, 8))
                    ]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: Icon(Icons.arrow_back_rounded, color: ink)),
                    const SizedBox(width: 6),
                    Text('Reset Password',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: accent)),
                  ]),
                  Divider(
                      height: 1,
                      color: context.fdColor(AppColors.borderGrey)),
                  const SizedBox(height: 20),
                  Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: context.fdColor(AppColors.surfaceMuted),
                          shape: BoxShape.circle),
                      child: Icon(Icons.lock_reset_rounded,
                          color: accent, size: 30)),
                  const SizedBox(height: 17),
                  Text('Forgot your password?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: ink)),
                  const SizedBox(height: 8),
                  Text(
                      _sent
                          ? _sentMessage
                          : "Enter your email address and we'll send password reset instructions.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, height: 1.5, color: muted)),
                  const SizedBox(height: 27),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Email Address',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ink))),
                  const SizedBox(height: 6),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading && !_sent,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter a valid email address.',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.errorRed)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading || _sent ? null : _sendResetEmail,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_sent ? 'Done' : 'Get help'),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Wrap(alignment: WrapAlignment.center, children: [
                    Text('Remember your password? ',
                        style: TextStyle(fontSize: 12, color: muted)),
                    GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Log in here',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerificationCodeScreen extends StatelessWidget {
  const VerificationCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Verification code', showBack: true),
      body: Padding(
        padding: _formPadding(context, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FdPreviewNotice(
                message: 'No verification code has been sent in this preview.'),
            const SizedBox(height: 16),
            Text('Enter the 6-digit code', style: AppTextStyles.headline2),
            const SizedBox(height: 8),
            Text(
                'Sent to your registered email. The code expires in 10 minutes.',
                style: AppTextStyles.secondary),
            const SizedBox(height: 24),
            const FdTextField(
                label: 'Verification code',
                hint: '••••••',
                keyboardType: TextInputType.number),
            const Spacer(),
            const FdButton(label: 'Verification unavailable in preview'),
          ],
        ),
      ),
    );
  }
}

class NewPasswordScreen extends StatelessWidget {
  const NewPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'New password', showBack: true),
      body: Padding(
        padding: _formPadding(context, 16, 24),
        child: Column(
          children: [
            const FdPreviewNotice(
                message: 'Password updates are not connected in this preview.'),
            const SizedBox(height: 16),
            const FdTextField(label: 'New password', obscure: true),
            const SizedBox(height: 16),
            const FdTextField(label: 'Confirm new password', obscure: true),
            const Spacer(),
            const FdButton(label: 'Password update unavailable in preview'),
          ],
        ),
      ),
    );
  }
}

class PasswordResetSuccessScreen extends StatelessWidget {
  const PasswordResetSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: _formPadding(context, 48, 24),
          child: Column(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 56, color: AppColors.primaryBlue),
              const SizedBox(height: 16),
              Text('Password not updated', style: AppTextStyles.headline2),
              const SizedBox(height: 8),
              Text('Password recovery is not connected in this preview.',
                  style: AppTextStyles.secondary, textAlign: TextAlign.center),
              const Spacer(),
              FdButton(
                label: 'Back to sign in',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, RouteNames.login, (_) => false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Birthday input for sign-up: tapping opens a date picker.
class _BirthdayField extends StatefulWidget {
  const _BirthdayField({required this.controller});

  final TextEditingController controller;

  @override
  State<_BirthdayField> createState() => _BirthdayFieldState();
}

class _BirthdayFieldState extends State<_BirthdayField> {
  TextEditingController get _controller => widget.controller;

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Select your birthday',
    );
    if (picked == null) return;
    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    _controller.text = '$dd/$mm/${picked.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          readOnly: true,
          onTap: _pick,
          validator: (value) => value == null || value.isEmpty
              ? 'Select your birthday.'
              : null,
          decoration: const InputDecoration(
            labelText: 'Birthday',
            hintText: 'DD/MM/YYYY',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
        ),
      ],
    );
  }
}
