import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/constants/route_names.dart';
import 'auth_screens.dart' show showHospitalPicker;
import '../core/domain/entities/user_role.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_style.dart';
import '../core/theme/fd_palette.dart';
import '../core/widgets/fd_image.dart';
import '../core/widgets/fd_widgets.dart';
import '../services/account_service.dart';
import '../services/connect_service.dart';
import '../services/hr_service.dart';
import '../services/image_picker_service.dart';
import '../services/inventory_service.dart';
import 'prototype_session.dart';

part 'hospital_screens.dart';
part 'hr_screens.dart';
part 'visit_screens.dart';

// ===========================================================================
// Small shared pieces
// ===========================================================================

const _statusColors = {
  DayStatus.available: Color(0xFF16A34A),
  DayStatus.busy: Color(0xFFD97706),
  DayStatus.off: Color(0xFF64748B),
};

Color _ink(BuildContext context) => context.fdColor(AppColors.neutralBlack);
Color _muted(BuildContext context) => context.fdColor(AppColors.darkGrey);
Color _line(BuildContext context) => context.fdColor(AppColors.borderGrey);
Color _surface(BuildContext context) => context.fdColor(Colors.white);

ButtonStyle _segmentStyle(BuildContext context) => SegmentedButton.styleFrom(
      selectedBackgroundColor: context.fdColor(AppColors.primaryBlue),
      selectedForegroundColor: Colors.white,
      foregroundColor: context.fdColor(AppColors.neutralBlack),
      backgroundColor: context.fdColor(Colors.white),
      side: BorderSide(color: context.fdColor(AppColors.borderGrey)),
    );

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));

/// Coloured circle with initials (or an icon for groups).
class ConnectAvatar extends StatelessWidget {
  const ConnectAvatar({super.key, required this.name, this.size = 44, this.icon});

  final String name;
  final double size;
  final IconData? icon;

  static const _palette = [
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
    Color(0xFF0D9488),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    final initials = name
        .replaceAll('Dr. ', '')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.5)
          : Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.36,
              ),
            ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.fdColor(AppColors.primaryBlue),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(count > 99 ? '99+' : '$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w800,
                    color: _muted(context),
                  )),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

Widget _unavailable(BuildContext context, String message, {bool back = true}) {
  final body = Center(
    child: FdEmptyState(
      title: 'Not available',
      message: message,
      icon: Icons.lock_outline_rounded,
    ),
  );
  if (!back) return body;
  return Scaffold(
    appBar: const FdAppBar(title: 'Chat', showBack: true),
    body: body,
  );
}

void openConversation(BuildContext context, String conversationId) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ConversationScreen(conversationId: conversationId),
  ));
}

void openDoctorProfile(BuildContext context, String email) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ConnectDoctorProfileScreen(doctorEmail: email),
  ));
}

// ===========================================================================
// Weekly schedule
// ===========================================================================

/// Seven day tiles (Mon–Sun) showing available / busy / off days.
class WeekScheduleView extends StatelessWidget {
  const WeekScheduleView({super.key, required this.days});
  final List<DaySchedule> days;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1;
    Widget tile(int index, {required bool compact}) {
      final day = days[index];
      final color = _statusColors[day.status]!;
      final isToday = index == today;
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 8, vertical: compact ? 12 : 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? context.fdColor(AppColors.primaryBlue)
                : color.withValues(alpha: 0.25),
            width: isToday ? 2 : 1,
          ),
        ),
        child: compact
            ? Row(children: [
                SizedBox(
                  width: 96,
                  child: Text(ConnectService.weekdays[index],
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: _ink(context))),
                ),
                _Tag(day.status.label, color),
                const Spacer(),
                Text(day.hours,
                    style: TextStyle(color: _ink(context), fontSize: 13)),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  _Tag('Today', context.fdColor(AppColors.primaryBlue)),
                ],
              ])
            : Column(children: [
                Text(ConnectService.weekdays[index].substring(0, 3),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: _ink(context))),
                const SizedBox(height: 2),
                Text(isToday ? 'Today' : ' ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.fdColor(AppColors.primaryBlue))),
                const SizedBox(height: 8),
                Icon(
                  switch (day.status) {
                    DayStatus.available => Icons.check_circle_rounded,
                    DayStatus.busy => Icons.schedule_rounded,
                    DayStatus.off => Icons.do_not_disturb_on_rounded,
                  },
                  color: color,
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(day.status.label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                    day.status == DayStatus.off
                        ? '—'
                        : '${day.start}\n${day.end}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5, color: _muted(context), height: 1.3)),
              ]),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 620) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tile(i, compact: false)),
            ],
          ],
        );
      }
      return Column(children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: tile(i, compact: true),
          ),
      ]);
    });
  }
}

class _ScheduleLegend extends StatelessWidget {
  const _ScheduleLegend();

  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, children: [
        for (final status in DayStatus.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: _statusColors[status], shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(status.label,
                style: TextStyle(fontSize: 12, color: _muted(context))),
          ]),
      ]);
}

/// Lets a doctor set each weekday as available, busy or off.
class ScheduleEditorScreen extends StatefulWidget {
  const ScheduleEditorScreen({super.key});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  late List<DaySchedule> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<PrototypeSession>().account;
    _days = ConnectService.instance.scheduleFor(me?.email ?? '');
  }

  Future<void> _pickTime(int index, bool start) async {
    final day = _days[index];
    final parts = (start ? day.start : day.end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (picked == null) return;
    final text =
        '${ConnectService.two(picked.hour)}:${ConnectService.two(picked.minute)}';
    setState(() {
      if (start) {
        day.start = text;
      } else {
        day.end = text;
      }
    });
  }

  Future<void> _save() async {
    final me = context.read<PrototypeSession>().account;
    if (me == null) return;
    for (var i = 0; i < 7; i++) {
      final day = _days[i];
      if (day.status != DayStatus.off && day.end.compareTo(day.start) <= 0) {
        _toast(context,
            '${ConnectService.weekdays[i]}: the end time must be after the start time.');
        return;
      }
    }
    setState(() => _saving = true);
    await ConnectService.instance.saveSchedule(me.email, _days);
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(context, 'Schedule saved. Users can see it on your profile.');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(
        title: 'My weekly schedule',
        subtitle: 'Users see this on your profile',
        showBack: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              WeekScheduleView(days: _days),
              const SizedBox(height: 10),
              const _ScheduleLegend(),
              const _SectionTitle('Edit each day'),
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FdCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 104,
                          child: Text(ConnectService.weekdays[i],
                              style: AppTextStyles.bodyText2.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _ink(context))),
                        ),
                        SegmentedButton<DayStatus>(
                          showSelectedIcon: false,
                          style: _segmentStyle(context),
                          segments: [
                            for (final status in DayStatus.values)
                              ButtonSegment(
                                value: status,
                                label: Text(status.label),
                              ),
                          ],
                          selected: {_days[i].status},
                          onSelectionChanged: (value) =>
                              setState(() => _days[i].status = value.first),
                        ),
                        if (_days[i].status != DayStatus.off)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickTime(i, true),
                              icon: const Icon(Icons.schedule_rounded,
                                  size: 16),
                              label: Text(_days[i].start),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('to',
                                  style: TextStyle(color: _muted(context))),
                            ),
                            OutlinedButton(
                              onPressed: () => _pickTime(i, false),
                              child: Text(_days[i].end),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FdButton(
                label: _saving ? 'Saving…' : 'Save schedule',
                icon: Icons.check_rounded,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Doctor directory and profile
// ===========================================================================

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    ConnectService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final q = _query.trim().toLowerCase();
    final doctors = connect.doctors
        .where((doctor) =>
            doctor.email != me?.email &&
            '${doctor.fullName} ${doctor.specialty} ${doctor.hospital} '
                    '${doctor.typeLabel}'
                .toLowerCase()
                .contains(q))
        .toList();

    return Scaffold(
      appBar: const FdAppBar(
        title: 'Find a doctor',
        subtitle: 'Doctors on Find Doctor',
        showBack: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search by name, specialty or hospital',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (doctors.isEmpty)
                FdEmptyState(
                  title: connect.doctors.isEmpty
                      ? 'No doctors yet'
                      : 'No doctors found',
                  message: connect.doctors.isEmpty
                      ? 'Doctors appear here as soon as they create a Find '
                          'Doctor account and are approved.'
                      : 'Try another name, specialty or hospital.',
                  icon: Icons.person_search_outlined,
                )
              else
                for (final doctor in doctors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RealDoctorTile(doctor: doctor),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class RealDoctorTile extends StatelessWidget {
  const RealDoctorTile({super.key, required this.doctor});
  final AppAccount doctor;

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final today = connect.todayFor(doctor.email);
    final name = ConnectService.displayName(doctor);
    return FdCard(
      onTap: () => openDoctorProfile(context, doctor.email),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        ConnectAvatar(name: name, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText1.copyWith(
                          fontWeight: FontWeight.w700, color: _ink(context))),
                ),
                const SizedBox(width: 6),
                Icon(Icons.verified_rounded,
                    size: 16, color: context.fdColor(AppColors.primaryBlue)),
              ]),
              const SizedBox(height: 2),
              Text(
                [
                  doctor.typeLabel,
                  if (doctor.specialty.isNotEmpty) doctor.specialty,
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
              Text(
                doctor.hospital.isEmpty ? 'No hospital yet' : doctor.hospital,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Tag(connect.statusNowLabel(doctor.email).split(' ').take(2).join(' '),
            _statusColors[today.status]!),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: _muted(context)),
      ]),
    );
  }
}

/// A real doctor's profile: details, the week's schedule, and a button for
/// patients to send a chat request.
class ConnectDoctorProfileScreen extends StatelessWidget {
  const ConnectDoctorProfileScreen({super.key, required this.doctorEmail});
  final String doctorEmail;

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final doctor = connect.accountByEmail(doctorEmail);
    if (doctor == null) {
      return _unavailable(context, 'This doctor\'s account was not found.');
    }
    final name = ConnectService.displayName(doctor);
    final days = connect.scheduleFor(doctor.email);
    final today = connect.todayFor(doctor.email);
    final isSelf = me?.email == doctor.email;
    final isPatient = me != null && !ConnectService.isStaff(me);
    final chat = me == null ? null : connect.directBetween(me.email, doctor.email);
    final latest =
        me == null ? null : connect.latestRequest(me.email, doctor.email);
    Visit? myVisit;
    if (me != null) {
      for (final visit in connect.upcomingVisitsFor(me.email)) {
        if (visit.doctorEmail == doctor.email) {
          myVisit = visit;
          break;
        }
      }
    }
    final canBook = doctor.hospital.trim().isNotEmpty;

    Widget action;
    if (isSelf) {
      action = FdButton(
        label: 'Edit my schedule',
        icon: Icons.edit_calendar_outlined,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ScheduleEditorScreen())),
      );
    } else if (!isPatient) {
      action = Text(
        'Users can book visits and send chat requests from this profile.',
        style: AppTextStyles.caption.copyWith(color: _muted(context)),
      );
    } else if (chat != null) {
      action = FdButton(
        label: 'Open chat',
        icon: Icons.chat_bubble_outline_rounded,
        onPressed: () => openConversation(context, chat.id),
      );
    } else if (latest != null && latest.status == RequestStatus.pending) {
      action = FdCard(
        child: Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Request sent ${ConnectService.shortTime(latest.createdAt)} · '
              'waiting for $name to accept.',
              style: AppTextStyles.bodyText2.copyWith(color: _ink(context)),
            ),
          ),
        ]),
      );
    } else {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (latest != null && latest.status == RequestStatus.rejected)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                latest.reason.isEmpty
                    ? 'Your last request was declined. You can send a new one.'
                    : 'Your last request was declined: “${latest.reason}”',
                style: AppTextStyles.caption
                    .copyWith(color: context.fdColor(AppColors.errorRed)),
              ),
            ),
          FdButton(
            label: 'Send chat request',
            icon: Icons.send_rounded,
            outlined: canBook,
            onPressed: () => showChatRequestDialog(context, doctor),
          ),
        ],
      );
    }

    Widget? visitBox;
    if (isPatient && !isSelf) {
      final booked = myVisit;
      if (booked != null) {
        visitBox = FdCard(
          onTap: () => openVisits(context),
          child: Row(children: [
            Icon(Icons.event_available_rounded,
                color: visitStatusColor(context, booked)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your visit: ${visitDayLabel(booked.start)} at '
                '${visitClock(booked.start)} · ${booked.statusLabel}',
                style: AppTextStyles.bodyText2.copyWith(color: _ink(context)),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _muted(context)),
          ]),
        );
      } else if (canBook) {
        visitBox = FdButton(
          label: 'Book a visit',
          icon: Icons.event_available_rounded,
          onPressed: () => showBookVisitDialog(context, doctor),
        );
      }
    }

    return Scaffold(
      appBar: FdAppBar(title: name, subtitle: doctor.typeLabel, showBack: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              FdCard(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  ConnectAvatar(name: name, size: 84),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(name,
                                style: AppTextStyles.headline2.copyWith(
                                    fontSize: 22, color: _ink(context))),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.verified_rounded,
                              color: context.fdColor(AppColors.primaryBlue)),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          [
                            doctor.typeLabel,
                            if (doctor.specialty.isNotEmpty) doctor.specialty,
                          ].join(' · '),
                          style: AppTextStyles.bodyText2
                              .copyWith(color: _muted(context)),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.local_hospital_outlined,
                              size: 16, color: _muted(context)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              doctor.hospital.isEmpty
                                  ? 'No hospital yet'
                                  : doctor.hospital,
                              style: AppTextStyles.bodyText2
                                  .copyWith(color: _ink(context)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        _Tag(connect.statusNowLabel(doctor.email),
                            _statusColors[today.status]!),
                      ],
                    ),
                  ),
                ]),
              ),
              _SectionTitle('Weekly schedule',
                  trailing: const _ScheduleLegend()),
              WeekScheduleView(days: days),
              const SizedBox(height: 22),
              if (visitBox != null) ...[
                visitBox,
                const SizedBox(height: 12),
              ],
              action,
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showChatRequestDialog(BuildContext context, AppAccount doctor) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ChatRequestDialog(doctor: doctor),
  );
}

class _ChatRequestDialog extends StatefulWidget {
  const _ChatRequestDialog({required this.doctor});
  final AppAccount doctor;

  @override
  State<_ChatRequestDialog> createState() => _ChatRequestDialogState();
}

class _ChatRequestDialogState extends State<_ChatRequestDialog> {
  final _message = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = context.read<PrototypeSession>().account;
    if (me == null) return;
    if (_message.text.trim().length < 5) {
      setState(() => _error = 'Tell the doctor briefly what you need.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ConnectService.instance.sendRequest(
          patient: me, doctor: widget.doctor, message: _message.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(SnackBar(
          content: Text(
              'Request sent to ${ConnectService.displayName(widget.doctor)}')));
    } on ConnectException catch (error) {
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connect = ConnectService.instance;
    final name = ConnectService.displayName(widget.doctor);
    final today = connect.todayFor(widget.doctor.email);
    return AlertDialog(
      title: Text('Chat request to $name'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The doctor gets a notification and can accept or decline. '
              'Once accepted, you can chat.',
              style: AppTextStyles.caption.copyWith(color: _muted(context)),
            ),
            if (today.status != DayStatus.available) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: _statusColors[today.status]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    today.status == DayStatus.off
                        ? '$name is off today — they\'ll see your request '
                            'when they\'re back.'
                        : '$name is busy today, so the reply may take longer.',
                    style: TextStyle(
                        fontSize: 12.5, color: _statusColors[today.status]),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _message,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Describe what you need help with',
              ),
            ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(
                      color: context.fdColor(AppColors.errorRed),
                      fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'For an emergency call 999 — don\'t wait for a chat reply.',
              style: AppTextStyles.caption.copyWith(color: _muted(context)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(_sending ? 'Sending…' : 'Send request'),
        ),
      ],
    );
  }
}

// ===========================================================================
// Chat requests (doctor side)
// ===========================================================================

class ChatRequestCard extends StatefulWidget {
  const ChatRequestCard({super.key, required this.request, this.onAccepted});
  final ChatRequest request;

  /// Opens the new chat. Defaults to pushing the conversation screen.
  final ValueChanged<Conversation>? onAccepted;

  @override
  State<ChatRequestCard> createState() => _ChatRequestCardState();
}

class _ChatRequestCardState extends State<ChatRequestCard> {
  bool _busy = false;

  Future<void> _accept() async {
    final me = context.read<PrototypeSession>().account;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      final conversation =
          await ConnectService.instance.acceptRequest(widget.request.id, me);
      if (!mounted) return;
      if (widget.onAccepted != null) {
        widget.onAccepted!(conversation);
      } else {
        openConversation(context, conversation.id);
      }
    } on ConnectException catch (error) {
      if (mounted) _toast(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final me = context.read<PrototypeSession>().account;
    if (me == null) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Decline ${widget.request.patientName}?'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: reason,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reason (optional), e.g. “Please see your GP first”',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.fdColor(AppColors.errorRed)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (confirmed != true || !mounted) return;
    await ConnectService.instance
        .rejectRequest(widget.request.id, me, reason: text);
    if (mounted) _toast(context, 'Request declined');
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return FdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ConnectAvatar(name: request.patientName, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.patientName,
                      style: AppTextStyles.bodyText1.copyWith(
                          fontWeight: FontWeight.w700, color: _ink(context))),
                  Text(
                      'Wants to chat · ${ConnectService.shortTime(request.createdAt)}',
                      style: AppTextStyles.caption
                          .copyWith(color: _muted(context))),
                ],
              ),
            ),
            const _Tag('New request', Color(0xFFD97706)),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.fdColor(AppColors.surfaceMuted),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(request.message,
                style: AppTextStyles.bodyText2.copyWith(color: _ink(context))),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _decline,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Decline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.fdColor(AppColors.errorRed),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _accept,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Accept'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ===========================================================================
// Chat hub (the Chat tab)
// ===========================================================================

class ChatHubTab extends StatefulWidget {
  const ChatHubTab({super.key, required this.role});
  final UserRole role;

  @override
  State<ChatHubTab> createState() => _ChatHubTabState();
}

class _ChatHubTabState extends State<ChatHubTab> {
  bool _groups = false;
  String _query = '';
  String? _selectedId;
  bool _wide = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final connect = ConnectService.instance;
    await connect.load();
    await connect.refresh();
    if (!mounted) return;
    await connect.ensureStaffRoom(context.read<PrototypeSession>().account);
  }

  void _open(Conversation conversation) {
    if (_wide) {
      setState(() => _selectedId = conversation.id);
    } else {
      openConversation(context, conversation.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final session = context.watch<PrototypeSession>();
    final me = session.account;

    final appBar = FdAppBar(
      title: 'Chat',
      subtitle: ConnectService.isStaff(me)
          ? 'Users, hospital groups and communities'
          : 'Your doctors and communities',
      notificationCount: connect.unreadNotifications(me?.email),
      onNotificationTap: () =>
          Navigator.pushNamed(context, RouteNames.notifications),
      actions: [
        if (ConnectService.isDoctor(me))
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'My weekly schedule',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const ScheduleEditorScreen())),
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
          ),
      ],
    );

    if (me == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(
          child: FdEmptyState(
            title: 'Sign in to chat',
            message: 'Chats, requests and groups need a Find Doctor account.',
            icon: Icons.forum_outlined,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: LayoutBuilder(builder: (context, constraints) {
        _wide = constraints.maxWidth >= 980;
        final list = _buildList(context, connect, me);
        if (!_wide) return list;
        final selected =
            _selectedId == null ? null : connect.conversationById(_selectedId!);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 400, child: list),
            VerticalDivider(width: 1, color: _line(context)),
            Expanded(
              child: selected == null
                  ? Center(
                      child: FdEmptyState(
                        title: 'Select a chat',
                        message: ConnectService.isDoctor(me)
                            ? 'Accept a user\'s request or open a group to '
                                'start talking.'
                            : 'Find a doctor and send a chat request, or join '
                                'a community.',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                    )
                  : ConversationView(
                      key: ValueKey(selected.id),
                      conversationId: selected.id,
                      embedded: true,
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildList(
      BuildContext context, ConnectService connect, AppAccount me) {
    final isDoctor = ConnectService.isDoctor(me);
    final isStaff = ConnectService.isStaff(me);
    final pending = isDoctor ? connect.pendingRequestsFor(me.email) : const <ChatRequest>[];
    final myRequests = isStaff
        ? const <ChatRequest>[]
        : connect
            .requestsByPatient(me.email)
            .where((request) => request.status != RequestStatus.accepted)
            .take(4)
            .toList();
    final q = _query.trim().toLowerCase();
    bool matches(Conversation conversation) =>
        q.isEmpty ||
        connect.titleFor(conversation, me.email).toLowerCase().contains(q);

    final chats = connect.directChatsFor(me.email).where(matches).toList();
    final hospitalGroups =
        connect.hospitalGroupsFor(me).where(matches).toList();
    final communities = connect.communities.where(matches).toList();
    final myCommunities =
        communities.where((c) => connect.isMember(c, me)).toList();
    final discover =
        communities.where((c) => !connect.isMember(c, me)).toList();

    Widget tile(Conversation conversation) => _ConversationTile(
          conversation: conversation,
          me: me,
          selected: _wide && conversation.id == _selectedId,
          onTap: () => _open(conversation),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (!isStaff)
          FdCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const DoctorDirectoryScreen())),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_search_rounded,
                    color: context.fdColor(AppColors.primaryBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Find a doctor',
                        style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _ink(context))),
                    Text('See their weekly schedule and send a chat request',
                        style: AppTextStyles.caption
                            .copyWith(color: _muted(context))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _muted(context)),
            ]),
          ),
        if (pending.isNotEmpty) ...[
          _SectionTitle('Chat requests', trailing: _CountBadge(pending.length)),
          for (final request in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChatRequestCard(
                request: request,
                onAccepted: (conversation) {
                  setState(() => _groups = false);
                  _open(conversation);
                },
              ),
            ),
        ],
        if (myRequests.isNotEmpty) ...[
          const _SectionTitle('Your requests'),
          for (final request in myRequests)
            _MyRequestTile(request: request),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: _segmentStyle(context),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(
                      'Chats${connect.directChatsFor(me.email).isEmpty ? '' : ' (${connect.directChatsFor(me.email).length})'}'),
                ),
                const ButtonSegment(
                  value: true,
                  icon: Icon(Icons.groups_2_outlined, size: 18),
                  label: Text('Groups'),
                ),
              ],
              selected: {_groups},
              onSelectionChanged: (value) =>
                  setState(() => _groups = value.first),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: _groups ? 'Search groups' : 'Search chats',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
        if (!_groups) ...[
          const SizedBox(height: 8),
          if (chats.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: FdEmptyState(
                title: 'No chats yet',
                message: isDoctor
                    ? 'When you accept a user\'s request, the chat appears '
                        'here.'
                    : isStaff
                        ? 'Your hospital groups and communities are under '
                            'Groups.'
                        : 'Find a doctor and send a chat request to start.',
                icon: Icons.forum_outlined,
              ),
            )
          else
            for (final chat in chats) tile(chat),
        ] else ...[
          if (isStaff) ...[
            _SectionTitle(
              me.hospital.isEmpty
                  ? 'Hospital groups'
                  : 'Private · ${me.hospital}',
              trailing: me.hospital.isEmpty
                  ? null
                  : TextButton.icon(
                      onPressed: () async {
                        final group =
                            await showCreateGroupDialog(context, community: false);
                        if (group != null) _open(group);
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New group'),
                    ),
            ),
            if (me.hospital.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Private hospital groups appear once you are assigned to a '
                  'hospital.',
                  style: AppTextStyles.caption.copyWith(color: _muted(context)),
                ),
              )
            else
              for (final group in hospitalGroups)
                connect.isMember(group, me)
                    ? tile(group)
                    : _ConversationTile(
                        conversation: group,
                        me: me,
                        selected: false,
                        onTap: () => _open(group),
                        joinable: true,
                      ),
          ],
          _SectionTitle(
            'Communities',
            trailing: isDoctor
                ? TextButton.icon(
                    onPressed: () async {
                      final group =
                          await showCreateGroupDialog(context, community: true);
                      if (group != null) _open(group);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New community'),
                  )
                : null,
          ),
          if (myCommunities.isEmpty && discover.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isDoctor
                    ? 'No communities yet. Create one — anyone can join and '
                        'post, and you lead it.'
                    : 'No communities yet. Doctors create them, and their posts '
                        'show on Explore.',
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
            ),
          for (final group in myCommunities) tile(group),
          if (discover.isNotEmpty) ...[
            const _SectionTitle('Discover communities'),
            for (final group in discover)
              _ConversationTile(
                conversation: group,
                me: me,
                selected: _wide && group.id == _selectedId,
                onTap: () => _open(group),
                joinable: true,
              ),
          ],
        ],
      ],
    );
  }
}

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({required this.request});
  final ChatRequest request;

  @override
  Widget build(BuildContext context) {
    final declined = request.status == RequestStatus.rejected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FdCard(
        onTap: () => openDoctorProfile(context, request.doctorEmail),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ConnectAvatar(name: request.doctorName, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.doctorName,
                    style: AppTextStyles.bodyText2.copyWith(
                        fontWeight: FontWeight.w700, color: _ink(context))),
                Text(
                  declined && request.reason.isNotEmpty
                      ? '“${request.reason}”'
                      : request.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: _muted(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          declined
              ? _Tag('Declined', context.fdColor(AppColors.errorRed))
              : const _Tag('Waiting', Color(0xFFD97706)),
        ]),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.me,
    required this.selected,
    required this.onTap,
    this.joinable = false,
  });

  final Conversation conversation;
  final AppAccount me;
  final bool selected;
  final VoidCallback onTap;
  final bool joinable;

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final title = connect.titleFor(conversation, me.email);
    final unread = joinable ? 0 : connect.unreadCount(conversation, me.email);
    final last = conversation.messages.isEmpty ? null : conversation.messages.last;
    final members = connect.membersOf(conversation).length;
    String preview;
    if (joinable) {
      preview = conversation.description.isNotEmpty
          ? conversation.description
          : '$members member${members == 1 ? '' : 's'}';
    } else if (last == null) {
      preview = 'No messages yet';
    } else if (last.isReport) {
      preview = '📄 Medical report';
    } else if (last.isSystem || conversation.isDirect) {
      preview = last.senderEmail == me.email ? 'You: ${last.text}' : last.text;
    } else {
      preview = last.senderEmail == me.email
          ? 'You: ${last.text}'
          : '${last.senderName}: ${last.text}';
    }
    final icon = conversation.isDirect
        ? null
        : conversation.isHospital
            ? (conversation.staffRoom
                ? Icons.local_hospital_rounded
                : Icons.lock_rounded)
            : Icons.groups_rounded;
    final other = conversation.isDirect
        ? connect.accountByEmail(connect.otherMember(conversation, me.email))
        : null;
    final subtitle = conversation.isDirect
        ? (other == null
            ? ''
            : ConnectService.isDoctor(other)
                ? '${other.typeLabel}${other.hospital.isEmpty ? '' : ' · ${other.hospital}'}'
                : 'User')
        : conversation.isHospital
            ? 'Private · $members member${members == 1 ? '' : 's'}'
            : 'Community · $members member${members == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? context.fdColor(AppColors.surfaceMuted)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(children: [
              ConnectAvatar(name: title, size: 50, icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText1.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _ink(context))),
                      ),
                      if (last != null && !joinable)
                        Text(ConnectService.shortTime(last.createdAt),
                            style: AppTextStyles.caption.copyWith(
                                color: unread > 0
                                    ? context.fdColor(AppColors.primaryBlue)
                                    : _muted(context),
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                    ]),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                              color: context.fdColor(AppColors.accentTeal),
                              fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText2.copyWith(
                            color: unread > 0 ? _ink(context) : _muted(context),
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ],
                ),
              ),
              if (joinable) ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    try {
                      await connect.join(conversation, me);
                      if (context.mounted) {
                        _toast(context, 'You joined ${conversation.title}');
                      }
                      onTap();
                    } on ConnectException catch (error) {
                      if (context.mounted) _toast(context, error.message);
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Join'),
                ),
              ] else if (unread > 0) ...[
                const SizedBox(width: 8),
                _CountBadge(unread),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Conversation
// ===========================================================================

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.fdColor(AppColors.background),
        body: SafeArea(child: ConversationView(conversationId: conversationId)),
      );
}

class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  final String conversationId;

  /// True inside the Chat tab's split view (no back button).
  final bool embedded;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(Conversation conversation, AppAccount me) async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    setState(() {});
    try {
      await ConnectService.instance.sendMessage(conversation, me, text);
    } on ConnectException catch (error) {
      if (mounted) _toast(context, error.message);
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final conversation = connect.conversationById(widget.conversationId);
    if (conversation == null || me == null) {
      return _unavailable(
          context, 'This chat or group no longer exists.',
          back: !widget.embedded);
    }
    if (!connect.canSee(conversation, me)) {
      return _unavailable(
          context,
          'This private group is only for doctors and managers of '
          '${conversation.hospital}.',
          back: !widget.embedded);
    }
    final member = connect.isMember(conversation, me);
    if (member && connect.unreadCount(conversation, me.email) > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => connect.markRead(conversation, me.email));
    }

    final title = connect.titleFor(conversation, me.email);
    final other = conversation.isDirect
        ? connect.accountByEmail(connect.otherMember(conversation, me.email))
        : null;
    final members = connect.membersOf(conversation).length;
    final subtitle = conversation.isDirect
        ? (other == null
            ? ''
            : ConnectService.isDoctor(other)
                ? '${other.typeLabel}${other.hospital.isEmpty ? '' : ' · ${other.hospital}'} · ${connect.statusNowLabel(other.email)}'
                : 'User${other.birthday.isEmpty ? '' : ' · born ${other.birthday}'}')
        : conversation.isHospital
            ? '${conversation.staffRoom ? 'Staff room' : 'Private group'} · '
                '${conversation.hospital} · $members members'
            : 'Community · $members member${members == 1 ? '' : 's'}';
    final canReport =
        conversation.isDirect && ConnectService.isDoctor(me) && other != null;

    final header = Container(
      padding: EdgeInsets.fromLTRB(widget.embedded ? 18 : 6, 10, 12, 10),
      decoration: BoxDecoration(
        color: _surface(context),
        border: Border(bottom: BorderSide(color: _line(context))),
      ),
      child: Row(children: [
        if (!widget.embedded)
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const BackButtonIcon(),
          ),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: other != null && ConnectService.isDoctor(other)
              ? () => openDoctorProfile(context, other.email)
              : null,
          child: ConnectAvatar(
            name: title,
            size: 44,
            icon: conversation.isDirect
                ? null
                : conversation.isHospital
                    ? (conversation.staffRoom
                        ? Icons.local_hospital_rounded
                        : Icons.lock_rounded)
                    : Icons.groups_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText1.copyWith(
                      fontWeight: FontWeight.w800, color: _ink(context))),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTextStyles.caption.copyWith(color: _muted(context))),
            ],
          ),
        ),
        if (canReport)
          FilledButton.icon(
            onPressed: () => showMedicalReportForm(context, conversation, me),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Medical report'),
          ),
        if (other != null && ConnectService.isDoctor(other))
          IconButton(
            tooltip: 'Doctor profile & schedule',
            onPressed: () => openDoctorProfile(context, other.email),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        if (!conversation.isDirect)
          IconButton(
            tooltip: 'Group info',
            onPressed: () => showGroupInfo(context, conversation.id),
            icon: const Icon(Icons.info_outline_rounded),
          ),
      ]),
    );

    final messages = conversation.messages;
    final list = messages.isEmpty
        ? Center(
            child: Text('No messages yet. Say hello 👋',
                style: TextStyle(color: _muted(context))),
          )
        : ListView.builder(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final i = messages.length - 1 - index;
              final message = messages[i];
              final previous = i > 0 ? messages[i - 1] : null;
              final newDay = previous == null ||
                  !_sameDay(previous.createdAt, message.createdAt);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (newDay) _DayDivider(message.createdAt),
                  _MessageRow(
                    message: message,
                    conversation: conversation,
                    mine: message.senderEmail == me.email,
                    showSender: !conversation.isDirect &&
                        (previous == null ||
                            previous.senderEmail != message.senderEmail ||
                            newDay),
                  ),
                ],
              );
            },
          );

    final Widget footer;
    if (member) {
      footer = Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: _surface(context),
          border: Border(top: BorderSide(color: _line(context))),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _send(conversation, me),
              decoration: InputDecoration(
                hintText: conversation.isCommunity
                    ? 'Write a post for the community…'
                    : 'Message…',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: _input.text.trim().isEmpty
                ? null
                : () => _send(conversation, me),
            icon: const Icon(Icons.send_rounded),
          ),
        ]),
      );
    } else {
      footer = Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        decoration: BoxDecoration(
          color: _surface(context),
          border: Border(top: BorderSide(color: _line(context))),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              conversation.isCommunity
                  ? 'Join this community to post and get updates.'
                  : 'Join this private group to post.',
              style: AppTextStyles.bodyText2.copyWith(color: _muted(context)),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                await connect.join(conversation, me);
              } on ConnectException catch (error) {
                if (context.mounted) _toast(context, error.message);
              }
            },
            icon: const Icon(Icons.group_add_rounded, size: 18),
            label: const Text('Join'),
          ),
        ]),
      );
    }

    return Material(
      color: context.fdColor(AppColors.background),
      child: Column(children: [
        header,
        if (!conversation.isDirect && conversation.description.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: context.fdColor(AppColors.surfaceMuted),
            child: Text(conversation.description,
                style: AppTextStyles.caption.copyWith(color: _ink(context))),
          ),
        Expanded(child: list),
        footer,
      ]),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DayDivider extends StatelessWidget {
  const _DayDivider(this.time);
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = _sameDay(time, now)
        ? 'Today'
        : _sameDay(time, now.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : ConnectService.fullDate(time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _muted(context))),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.conversation,
    required this.mine,
    required this.showSender,
  });

  final ConnectMessage message;
  final Conversation conversation;
  final bool mine;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: context.fdColor(AppColors.surfaceMuted),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(message.text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted(context))),
          ),
        ),
      );
    }
    final time =
        '${ConnectService.two(message.createdAt.hour)}:${ConnectService.two(message.createdAt.minute)}';
    if (message.isReport) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: MedicalReportCard(
            report: message.report!,
            onOpen: () => showMedicalReport(context, message.report!),
          ),
        ),
      );
    }
    final bubbleColor = mine
        ? context.fdColor(AppColors.primaryBlue)
        : _surface(context);
    final textColor = mine ? Colors.white : _ink(context);
    return Padding(
      padding: EdgeInsets.only(top: showSender ? 8 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && !conversation.isDirect) ...[
            showSender
                ? ConnectAvatar(name: message.senderName, size: 28)
                : const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18),
                  ),
                  border: mine ? null : Border.all(color: _line(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSender && !mine && !conversation.isDirect)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(message.senderName,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: context.fdColor(AppColors.accentTeal))),
                      ),
                    SelectableText(message.text,
                        style: TextStyle(
                            color: textColor, fontSize: 14.5, height: 1.35)),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(time,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: mine
                                  ? Colors.white70
                                  : _muted(context))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Medical reports
// ===========================================================================

class MedicalReportCard extends StatelessWidget {
  const MedicalReportCard({super.key, required this.report, required this.onOpen});
  final MedicalReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Material(
        color: _surface(context),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.description_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('MEDICAL REPORT',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ),
                  Text(report.code,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11.5)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.diagnosis,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: FontWeight.w800, color: _ink(context))),
                    const SizedBox(height: 6),
                    Text('For ${report.patientName}',
                        style: AppTextStyles.caption
                            .copyWith(color: _muted(context))),
                    Text('${report.doctorName} · ${report.hospitalLabel}',
                        style: AppTextStyles.caption.copyWith(
                            color: _ink(context), fontWeight: FontWeight.w600)),
                    Text(ConnectService.fullDateTime(report.issuedAt),
                        style: AppTextStyles.caption
                            .copyWith(color: _muted(context))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 16,
                          color: context.fdColor(AppColors.primaryBlue)),
                      const SizedBox(width: 6),
                      Text('View report',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.fdColor(AppColors.primaryBlue))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMedicalReportForm(
    BuildContext context, Conversation conversation, AppAccount doctor) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _ReportFormDialog(conversation: conversation, doctor: doctor),
  );
}

class _ReportFormDialog extends StatefulWidget {
  const _ReportFormDialog({required this.conversation, required this.doctor});
  final Conversation conversation;
  final AppAccount doctor;

  @override
  State<_ReportFormDialog> createState() => _ReportFormDialogState();
}

class _ReportFormDialogState extends State<_ReportFormDialog> {
  final _diagnosis = TextEditingController();
  final _findings = TextEditingController();
  final _treatment = TextEditingController();
  final _followUp = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _diagnosis.dispose();
    _findings.dispose();
    _treatment.dispose();
    _followUp.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_diagnosis.text.trim().isEmpty) {
      setState(() => _error = 'Enter the diagnosis.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ConnectService.instance.issueReport(
        conversation: widget.conversation,
        doctor: widget.doctor,
        diagnosis: _diagnosis.text,
        findings: _findings.text,
        treatment: _treatment.text,
        leaveDays: 0,
        followUp: _followUp.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
          const SnackBar(content: Text('Medical report sent in the chat')));
    } on ConnectException catch (error) {
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connect = ConnectService.instance;
    final patient = widget.conversation.nameOf(
        connect.otherMember(widget.conversation, widget.doctor.email));
    final hospital = widget.doctor.hospital.trim().isEmpty
        ? 'No hospital listed'
        : widget.doctor.hospital.trim();
    InputDecoration field(String label, String hint) =>
        InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: true);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.description_outlined,
                    color: context.fdColor(AppColors.primaryBlue)),
                const SizedBox(width: 10),
                Text('Medical report',
                    style: AppTextStyles.headline2
                        .copyWith(fontSize: 21, color: _ink(context))),
              ]),
              const SizedBox(height: 6),
              Text('For $patient',
                  style: AppTextStyles.bodyText2.copyWith(color: _ink(context))),
              Text(
                  'Signed as ${ConnectService.displayName(widget.doctor)} · $hospital',
                  style: AppTextStyles.caption.copyWith(color: _muted(context))),
              const SizedBox(height: 18),
              TextField(
                controller: _diagnosis,
                autofocus: true,
                decoration: field('Diagnosis *', 'e.g. Acute upper respiratory tract infection'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _findings,
                minLines: 2,
                maxLines: 4,
                decoration: field('Clinical findings', 'Symptoms, examination, test results'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _treatment,
                minLines: 2,
                maxLines: 4,
                decoration: field('Treatment & advice', 'Medication, rest, what to watch for'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _followUp,
                decoration: field('Follow-up', 'e.g. Review in 1 week'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: context.fdColor(AppColors.primaryBlue)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kTeleconsultNotice,
                        style: AppTextStyles.caption.copyWith(
                            color: context.fdColor(AppColors.darkGrey),
                            height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(
                        color: context.fdColor(AppColors.errorRed))),
              ],
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(_busy ? 'Sending…' : 'Send report'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Malaysian Medical Council rule: a medical certificate (MC) may not be
/// issued after a chat or video consultation alone, so reports issued from
/// chat never carry medical leave.
const kTeleconsultNotice =
    'Teleconsultation report. This is not a medical certificate (MC) and '
    'does not grant medical leave. For an MC, the patient must be examined '
    'in person.';

String reportPlainText(MedicalReport report) {
  final lines = <String>[
    report.hospitalLabel.toUpperCase(),
    'MEDICAL REPORT  ${report.code}',
    'Issued: ${ConnectService.fullDateTime(report.issuedAt)}',
    '',
    'Patient: ${report.patientName}',
    if (report.patientBirthday.isNotEmpty) 'Date of birth: ${report.patientBirthday}',
    'Doctor: ${report.doctorName} (${report.doctorType}'
        '${report.specialty.isEmpty ? '' : ', ${report.specialty}'})',
    'Hospital: ${report.hospitalLabel}',
    '',
    'Diagnosis: ${report.diagnosis}',
    if (report.findings.isNotEmpty) 'Clinical findings: ${report.findings}',
    if (report.treatment.isNotEmpty) 'Treatment & advice: ${report.treatment}',
    if (report.followUp.isNotEmpty) 'Follow-up: ${report.followUp}',
    '',
    'Issued by ${report.doctorName}, ${report.hospitalLabel}, via Find Doctor.',
    kTeleconsultNotice,
  ];
  return lines.join('\n');
}

String _reportHtml(MedicalReport report) {
  const escape = HtmlEscape();
  String e(String text) => escape.convert(text).replaceAll('\n', '<br>');
  String row(String label, String value) => value.isEmpty
      ? ''
      : '<div class="row"><div class="label">${e(label)}</div>'
          '<div class="value">${e(value)}</div></div>';
  return '''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>Medical report ${e(report.code)}</title>
<style>
body{font-family:"Segoe UI",Arial,sans-serif;color:#0f172a;margin:0;background:#f4f5fb}
.page{max-width:780px;margin:32px auto;background:#fff;padding:48px 56px;border-radius:12px;box-shadow:0 8px 30px rgba(30,27,75,.12)}
.head{display:flex;justify-content:space-between;border-bottom:3px solid #4f46e5;padding-bottom:18px}
.hospital{font-size:22px;font-weight:800;color:#1e1b4b}
.sub{color:#64748b;font-size:13px}
h1{font-size:18px;letter-spacing:2px;color:#4f46e5;margin:26px 0 6px}
.row{display:flex;padding:9px 0;border-bottom:1px solid #eef0ff}
.label{width:190px;color:#64748b;font-size:13px;flex-shrink:0}
.value{font-size:14.5px;line-height:1.45}
.sign{margin-top:46px;display:flex;justify-content:flex-end}
.sign div{border-top:1px solid #0f172a;padding-top:8px;min-width:260px;text-align:center;font-size:13px}
.note{margin-top:30px;color:#64748b;font-size:12px}
button{margin:18px auto;display:block;background:#4f46e5;color:#fff;border:0;border-radius:8px;padding:10px 22px;font-size:14px;cursor:pointer}
@media print{body{background:#fff}.page{box-shadow:none;margin:0;border-radius:0}button{display:none}}
</style></head><body>
<button onclick="window.print()">Print or save as PDF</button>
<div class="page">
<div class="head"><div><div class="hospital">${e(report.hospitalLabel)}</div>
<div class="sub">Issued through Find Doctor</div></div>
<div class="sub" style="text-align:right">Report no. <b>${e(report.code)}</b><br>${e(ConnectService.fullDateTime(report.issuedAt))}</div></div>
<h1>MEDICAL REPORT</h1>
${row('Patient', report.patientName)}
${row('Date of birth', report.patientBirthday)}
${row('Doctor', '${report.doctorName} (${report.doctorType}${report.specialty.isEmpty ? '' : ', ${report.specialty}'})')}
${row('Hospital', report.hospitalLabel)}
${row('Diagnosis', report.diagnosis)}
${row('Clinical findings', report.findings)}
${row('Treatment & advice', report.treatment)}
${row('Follow-up', report.followUp)}
<div class="sign"><div><b>${e(report.doctorName)}</b><br>${e(report.doctorType)} · ${e(report.hospitalLabel)}</div></div>
<div class="note">This report was issued electronically by the doctor named above through Find Doctor.<br>${e(kTeleconsultNotice)}</div>
</div></body></html>''';
}

Future<void> showMedicalReport(BuildContext context, MedicalReport report) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Widget row(String label, String value) => value.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 13, color: _muted(dialogContext))),
                  ),
                  Expanded(
                    child: SelectableText(value,
                        style: TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: _ink(dialogContext))),
                  ),
                ],
              ),
            );

      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.hospitalLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        const Text('MEDICAL REPORT',
                            style: TextStyle(
                                color: Colors.white70,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(report.code,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      Text(ConnectService.fullDateTime(report.issuedAt),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row('Patient', report.patientName),
                      row('Date of birth', report.patientBirthday),
                      row('Doctor',
                          '${report.doctorName} (${report.doctorType}${report.specialty.isEmpty ? '' : ', ${report.specialty}'})'),
                      row('Hospital', report.hospitalLabel),
                      const Divider(height: 24),
                      row('Diagnosis', report.diagnosis),
                      row('Clinical findings', report.findings),
                      row('Treatment & advice', report.treatment),
                      row('Follow-up', report.followUp),
                      const SizedBox(height: 26),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(color: _ink(dialogContext))),
                          ),
                          child: Column(children: [
                            Text(report.doctorName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _ink(dialogContext))),
                            Text(
                                '${report.doctorType} · ${report.hospitalLabel}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _muted(dialogContext))),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Issued electronically by the doctor named above '
                        'through Find Doctor.\n$kTeleconsultNotice',
                        style: TextStyle(
                            fontSize: 11.5, color: _muted(dialogContext)),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: reportPlainText(report)));
                      if (dialogContext.mounted) {
                        _toast(dialogContext, 'Report copied');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 6),
                  // Printing opens the report in a desktop browser.
                  if (Platform.isWindows)
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        final path = await saveReportFile(report);
                        if (dialogContext.mounted) {
                          _toast(dialogContext,
                              'Report opened in your browser · saved to $path');
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          _toast(dialogContext,
                              'Could not save the report: $error');
                        }
                      }
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Save & print'),
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Saves the report as a printable page in the app's own folder
/// (%APPDATA%\\Find Doctor\\Find Doctor\\reports) and opens it in the
/// default browser, where it can be printed or saved as PDF.
Future<String> saveReportFile(MedicalReport report) async {
  final base = await getApplicationSupportDirectory();
  final folder =
      Directory('${base.path}${Platform.pathSeparator}reports');
  await folder.create(recursive: true);
  final file = File(
      '${folder.path}${Platform.pathSeparator}FindDoctor-${report.code}.html');
  await file.writeAsString(_reportHtml(report), flush: true);
  if (Platform.isWindows) {
    // Same route as the photo picker: PowerShell opens the page in the
    // default browser (launching explorer.exe directly can be blocked).
    // Edge is opened explicitly because .html may have no default app.
    final safePath = file.path.replaceAll("'", "''");
    final uri = Uri.file(file.path).toString().replaceAll("'", '%27');
    try {
      await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        "try { Start-Process -FilePath 'msedge' -ArgumentList '$uri' "
            "-ErrorAction Stop } catch { Start-Process -FilePath '$safePath' }",
      ]);
    } catch (_) {
      // The report is still saved; the toast shows where.
    }
  }
  return file.path;
}

// ===========================================================================
// Groups
// ===========================================================================

Future<Conversation?> showCreateGroupDialog(BuildContext context,
    {required bool community}) {
  return showDialog<Conversation>(
    context: context,
    builder: (_) => _CreateGroupDialog(community: community),
  );
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.community});
  final bool community;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final me = context.read<PrototypeSession>().account;
    if (me == null) return;
    if (_name.text.trim().length < 3) {
      setState(() => _error = 'Give the group a name (at least 3 letters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await ConnectService.instance.createGroup(
        creator: me,
        title: _name.text,
        description: _description.text,
        community: widget.community,
      );
      if (mounted) Navigator.pop(context, group);
    } on ConnectException catch (error) {
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<PrototypeSession>().account;
    return AlertDialog(
      title: Text(widget.community ? 'New community' : 'New private group'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                widget.community ? Icons.public_rounded : Icons.lock_rounded,
                size: 18,
                color: _muted(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.community
                      ? 'Anyone on Find Doctor can see it, join and post. Its '
                          'posts appear on Explore. You lead it: you can add '
                          'and remove members.'
                      : 'Only doctors and managers at ${me?.hospital ?? 'your hospital'} '
                          'can see and join it. Nobody from other hospitals can.',
                  style: AppTextStyles.caption.copyWith(color: _muted(context)),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Group name',
                hintText: widget.community
                    ? 'e.g. Living with diabetes'
                    : 'e.g. Cardiology team',
              ),
            ),
            TextField(
              controller: _description,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)'),
            ),
            if (_error != null)
              Text(_error!,
                  style:
                      TextStyle(color: context.fdColor(AppColors.errorRed))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(_busy ? 'Creating…' : 'Create'),
        ),
      ],
    );
  }
}

Future<void> showGroupInfo(BuildContext context, String conversationId) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GroupInfoDialog(conversationId: conversationId),
  );
}

class _GroupInfoDialog extends StatelessWidget {
  const _GroupInfoDialog({required this.conversationId});
  final String conversationId;

  Future<bool> _confirm(BuildContext context, String title, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.fdColor(AppColors.errorRed)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final conversation = connect.conversationById(conversationId);
    if (conversation == null || me == null) {
      return AlertDialog(
        content: const Text('This group no longer exists.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      );
    }
    final members = connect.membersOf(conversation);
    final leader = connect.isLeader(conversation, me);
    final member = connect.isMember(conversation, me);
    final kind = conversation.isCommunity
        ? 'Community group · anyone can join and post'
        : conversation.staffRoom
            ? 'Staff room · every doctor and manager of ${conversation.hospital}'
            : 'Private group · only ${conversation.hospital} staff can see it';

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                ConnectAvatar(
                  name: conversation.title,
                  size: 52,
                  icon: conversation.isCommunity
                      ? Icons.groups_rounded
                      : conversation.staffRoom
                          ? Icons.local_hospital_rounded
                          : Icons.lock_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(conversation.title,
                          style: AppTextStyles.bodyText1.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: _ink(context))),
                      Text(kind,
                          style: AppTextStyles.caption
                              .copyWith(color: _muted(context))),
                    ],
                  ),
                ),
              ]),
              if (conversation.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(conversation.description,
                    style: AppTextStyles.bodyText2.copyWith(color: _ink(context))),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Text(
                      '${members.length} member${members.length == 1 ? '' : 's'}',
                      style: AppTextStyles.bodyText2.copyWith(
                          fontWeight: FontWeight.w700, color: _ink(context))),
                ),
                if (leader)
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _AddMemberDialog(conversationId: conversation.id),
                    ),
                    icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                    label: const Text('Add member'),
                  ),
              ]),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final email in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ConnectAvatar(
                            name: connect.memberName(conversation, email),
                            size: 38),
                        title: Text(
                          connect.memberName(conversation, email) +
                              (email == me.email ? ' (you)' : ''),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _ink(context)),
                        ),
                        subtitle: Text(
                          [
                            connect.accountByEmail(email)?.typeLabel ?? '',
                            if ((connect.accountByEmail(email)?.hospital ?? '')
                                .isNotEmpty)
                              connect.accountByEmail(email)!.hospital,
                          ].where((part) => part.isNotEmpty).join(' · '),
                          style: TextStyle(color: _muted(context), fontSize: 12),
                        ),
                        trailing: email == conversation.leaderEmail
                            ? _Tag('Leader',
                                context.fdColor(AppColors.primaryBlue))
                            : leader
                                ? IconButton(
                                    tooltip: 'Remove from group',
                                    onPressed: () async {
                                      if (!await _confirm(
                                          context,
                                          'Remove ${connect.memberName(conversation, email)}?',
                                          'Remove')) {
                                        return;
                                      }
                                      await connect.removeMember(
                                          conversation, me, email);
                                    },
                                    icon: Icon(
                                        Icons.person_remove_alt_1_outlined,
                                        color: context
                                            .fdColor(AppColors.errorRed)),
                                  )
                                : null,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                if (leader)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: context.fdColor(AppColors.errorRed)),
                    onPressed: () async {
                      if (!await _confirm(context,
                          'Delete ${conversation.title}?', 'Delete')) {
                        return;
                      }
                      await connect.deleteGroup(conversation, me);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete group'),
                  )
                else if (member && !conversation.staffRoom)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: context.fdColor(AppColors.errorRed)),
                    onPressed: () async {
                      if (!await _confirm(context,
                          'Leave ${conversation.title}?', 'Leave')) {
                        return;
                      }
                      try {
                        await connect.leave(conversation, me);
                      } on ConnectException catch (error) {
                        if (context.mounted) _toast(context, error.message);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Leave group'),
                  )
                else if (!member && !conversation.staffRoom)
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await connect.join(conversation, me);
                      } on ConnectException catch (error) {
                        if (context.mounted) _toast(context, error.message);
                      }
                    },
                    icon: const Icon(Icons.group_add_rounded, size: 18),
                    label: const Text('Join'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.conversationId});
  final String conversationId;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final conversation = connect.conversationById(widget.conversationId);
    if (conversation == null || me == null) return const SizedBox.shrink();
    final q = _query.trim().toLowerCase();
    final people = connect
        .addableTo(conversation, me)
        .where((account) => '${account.fullName} ${account.email}'
            .toLowerCase()
            .contains(q))
        .toList();
    return AlertDialog(
      title: const Text('Add member'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(children: [
          if (conversation.isHospital)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Only doctors and managers of ${conversation.hospital} can be '
                'added.',
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
            ),
          TextField(
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search people',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: people.isEmpty
                ? Center(
                    child: Text('Nobody else can be added right now.',
                        style: TextStyle(color: _muted(context))))
                : ListView(
                    children: [
                      for (final account in people)
                        ListTile(
                          leading: ConnectAvatar(
                              name: ConnectService.displayName(account),
                              size: 36),
                          title: Text(ConnectService.displayName(account)),
                          subtitle: Text(
                            [
                              account.typeLabel,
                              if (account.hospital.isNotEmpty) account.hospital,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.add_circle_outline_rounded),
                          onTap: () async {
                            try {
                              await connect.addMember(conversation, me, account);
                              if (context.mounted) {
                                _toast(context,
                                    'Added ${ConnectService.displayName(account)}');
                              }
                            } on ConnectException catch (error) {
                              if (context.mounted) _toast(context, error.message);
                            }
                          },
                        ),
                    ],
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// A community post shown on Explore, with a Join button.
class GroupPostCard extends StatelessWidget {
  const GroupPostCard({
    super.key,
    required this.conversation,
    required this.message,
  });

  final Conversation conversation;
  final ConnectMessage message;

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final member = connect.isMember(conversation, me);
    final members = connect.membersOf(conversation).length;
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));
    const blue = Color(0xFF0095F6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            ConnectAvatar(
                name: conversation.title, size: 38, icon: Icons.groups_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(conversation.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: ink)),
                    ),
                    Text(
                        '  •  ${ConnectService.shortTime(message.createdAt)}',
                        style: TextStyle(fontSize: 14, color: muted)),
                  ]),
                  Text('Community · $members member${members == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: ink)),
                ],
              ),
            ),
            if (!member && me != null)
              TextButton(
                onPressed: () async {
                  try {
                    await connect.join(conversation, me);
                    if (context.mounted) {
                      _toast(context, 'You joined ${conversation.title}');
                    }
                  } on ConnectException catch (error) {
                    if (context.mounted) _toast(context, error.message);
                  }
                },
                child: const Text('Join',
                    style:
                        TextStyle(color: blue, fontWeight: FontWeight.w700)),
              )
            else
              TextButton(
                onPressed: () => openConversation(context, conversation.id),
                child: Text('Open',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => openConversation(context, conversation.id),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              constraints: const BoxConstraints(minHeight: 150),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.10),
                    const Color(0xFFDB2777).withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                    color: context.fdColor(const Color(0xFFDBDBDB)),
                    width: 0.6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ConnectAvatar(name: message.senderName, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(message.senderName,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: ink)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(message.text,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 16, height: 1.45, color: ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => openConversation(context, conversation.id),
            child: Text(
              member
                  ? 'Open the group to reply'
                  : 'Join ${conversation.title} to post and reply',
              style: TextStyle(fontSize: 14, color: muted),
            ),
          ),
          Divider(height: 26, color: context.fdColor(const Color(0xFFDBDBDB))),
        ],
      ),
    );
  }
}

/// "Communities to join" for the Explore side rail.
class CommunitySuggestions extends StatelessWidget {
  const CommunitySuggestions({super.key});

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final open = connect.communities
        .where((group) => !connect.isMember(group, me))
        .take(4)
        .toList();
    if (open.isEmpty || me == null) return const SizedBox.shrink();
    final muted = context.fdColor(const Color(0xFF737373));
    final ink = context.fdColor(const Color(0xFF262626));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Text('Communities to join',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
        const SizedBox(height: 6),
        for (final group in open)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              ConnectAvatar(
                  name: group.title, size: 40, icon: Icons.groups_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ink)),
                    Text('${connect.membersOf(group).length} members',
                        style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ),
              InkWell(
                onTap: () async {
                  try {
                    await connect.join(group, me);
                  } on ConnectException catch (error) {
                    if (context.mounted) _toast(context, error.message);
                  }
                },
                child: const Text('Join',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0095F6))),
              ),
            ]),
          ),
      ],
    );
  }
}

// ===========================================================================
// Notifications
// ===========================================================================

class ConnectNotificationsScreen extends StatefulWidget {
  const ConnectNotificationsScreen({super.key});

  @override
  State<ConnectNotificationsScreen> createState() =>
      _ConnectNotificationsScreenState();
}

class _ConnectNotificationsScreenState
    extends State<ConnectNotificationsScreen> {
  String? _email;

  @override
  void initState() {
    super.initState();
    _email = context.read<PrototypeSession>().account?.email;
    ConnectService.instance.load();
  }

  @override
  void dispose() {
    final email = _email;
    if (email != null) ConnectService.instance.markNotificationsRead(email);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    if (me == null) {
      return _unavailable(context, 'Sign in to see your notifications.');
    }
    final pending = ConnectService.isDoctor(me)
        ? connect.pendingRequestsFor(me.email)
        : const <ChatRequest>[];
    final pendingIds = pending.map((request) => request.id).toSet();
    final items = connect
        .notificationsFor(me.email)
        .where((notification) => !pendingIds.contains(notification.refId))
        .toList();

    IconData iconFor(String type) => switch (type) {
          'chat_request' => Icons.mark_chat_unread_outlined,
          'request_accepted' => Icons.check_circle_outline_rounded,
          'request_rejected' => Icons.cancel_outlined,
          'report' => Icons.description_outlined,
          'group_added' => Icons.group_add_outlined,
          'group_removed' => Icons.group_remove_outlined,
          'visit_request' => Icons.event_note_outlined,
          'visit_confirmed' => Icons.event_available_rounded,
          'visit_declined' || 'visit_cancelled' => Icons.event_busy_outlined,
          'hr_hired' => Icons.how_to_reg_rounded,
          'hr_role' => Icons.badge_outlined,
          _ when type.startsWith('hr_') => Icons.work_outline_rounded,
          _ => Icons.notifications_none_rounded,
        };
    Color colorFor(String type) => switch (type) {
          'request_rejected' ||
          'group_removed' ||
          'visit_declined' ||
          'visit_cancelled' =>
            context.fdColor(AppColors.errorRed),
          'request_accepted' ||
          'visit_confirmed' ||
          'hr_hired' ||
          'hr_accepted' ||
          'hr_offer_accepted' =>
            const Color(0xFF16A34A),
          'hr_declined' || 'hr_cancelled' || 'hr_offer_declined' =>
            context.fdColor(AppColors.errorRed),
          'chat_request' || 'visit_request' => const Color(0xFFD97706),
          _ => context.fdColor(AppColors.primaryBlue),
        };

    return Scaffold(
      appBar: const FdAppBar(title: 'Notifications', showBack: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionTitle('Chat requests',
                    trailing: _CountBadge(pending.length)),
                for (final request in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ChatRequestCard(request: request),
                  ),
              ],
              const _SectionTitle('Recent'),
              if (items.isEmpty)
                const FdEmptyState(
                  title: 'No notifications yet',
                  message: 'Visit bookings, chat requests, replies, reports '
                      'and group updates show up here.',
                  icon: Icons.notifications_none_rounded,
                )
              else
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FdCard(
                      padding: const EdgeInsets.all(14),
                      onTap: item.type.startsWith('visit_')
                          ? () => openVisits(context)
                          : item.type == 'hr_hired'
                              ? () => openScheduleEditor(context)
                              : item.type.startsWith('hr_') &&
                                      AccountService.isHr(me)
                                  ? () => openHrCenter(context)
                                  : item.type.startsWith('hr_') &&
                                          me.isJobSeeker
                                      ? () => openCareer(context)
                                      : connect.conversationById(
                                                  item.refId) !=
                                              null
                                          ? () => openConversation(
                                              context, item.refId)
                                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorFor(item.type).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconFor(item.type),
                                color: colorFor(item.type), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title,
                                    style: AppTextStyles.bodyText2.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: _ink(context))),
                                const SizedBox(height: 2),
                                Text(item.body,
                                    style: AppTextStyles.bodyText2
                                        .copyWith(color: _muted(context))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(ConnectService.shortTime(item.createdAt),
                                  style: AppTextStyles.caption
                                      .copyWith(color: _muted(context))),
                              if (!item.read) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: context
                                        .fdColor(AppColors.primaryBlue),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
