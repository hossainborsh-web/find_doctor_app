part of 'connect_screens.dart';

// ===========================================================================
// Visits: users book a time inside a doctor's weekly schedule; the doctor
// confirms, declines, or marks the visit completed.
// ===========================================================================

const _visitDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _visitMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "09:30".
String visitClock(DateTime time) =>
    '${ConnectService.two(time.hour)}:${ConnectService.two(time.minute)}';

/// "09:30 – 10:00".
String visitTimeRange(Visit visit) =>
    '${visitClock(visit.start)} – ${visitClock(visit.end)}';

/// "Today · Mon, 2 Nov", "Tomorrow · …" or "Wed, 4 Nov".
String visitDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  var label =
      '${_visitDays[date.weekday - 1]}, ${date.day} ${_visitMonths[date.month - 1]}';
  if (date.year != now.year) label = '$label ${date.year}';
  if (diff == 0) return 'Today · $label';
  if (diff == 1) return 'Tomorrow · $label';
  return label;
}

Color visitStatusColor(BuildContext context, Visit visit) {
  if (visit.isExpired) return const Color(0xFF64748B);
  return switch (visit.status) {
    VisitStatus.requested => const Color(0xFFD97706),
    VisitStatus.confirmed => const Color(0xFF16A34A),
    VisitStatus.declined => context.fdColor(AppColors.errorRed),
    VisitStatus.cancelled => const Color(0xFF64748B),
    VisitStatus.completed => context.fdColor(AppColors.primaryBlue),
  };
}

void openVisits(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const VisitsScreen()));

void openDoctorDirectory(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const DoctorDirectoryScreen()));

void openScheduleEditor(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ScheduleEditorScreen()));

/// Optional reason prompt. Returns null when the person backs out.
Future<String?> _askVisitReason(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = true,
  String keepLabel = 'Keep visit',
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message,
                style: TextStyle(color: _muted(dialogContext), height: 1.35)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(keepLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: dialogContext.fdColor(AppColors.errorRed),
                  foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(action),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- booking

Future<void> showBookVisitDialog(BuildContext context, AppAccount doctor) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BookVisitDialog(doctor: doctor),
  );
}

class _BookVisitDialog extends StatefulWidget {
  const _BookVisitDialog({required this.doctor});
  final AppAccount doctor;

  @override
  State<_BookVisitDialog> createState() => _BookVisitDialogState();
}

class _BookVisitDialogState extends State<_BookVisitDialog> {
  final _reason = TextEditingController();
  DateTime? _day;
  DateTime? _slot;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _book(DateTime slot) async {
    final me = context.read<PrototypeSession>().account;
    if (me == null) return;
    if (_reason.text.trim().length < 5) {
      setState(() => _error = 'Please tell the doctor why you\'re coming.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final visit = await ConnectService.instance.bookVisit(
        patient: me,
        doctor: widget.doctor,
        start: slot,
        reason: _reason.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(SnackBar(
        content: Text('Visit requested for ${visitDayLabel(visit.start)} at '
            '${visitClock(visit.start)}. You\'ll get a notification when '
            '${visit.doctorName} confirms.'),
      ));
    } on ConnectException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
          _slot = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final doctor = widget.doctor;
    final name = ConnectService.displayName(doctor);
    final schedule = connect.scheduleFor(doctor.email);
    final days = ConnectService.bookingWindow();
    final open = {
      for (final day in days) day: connect.openSlots(doctor.email, day),
    };
    final anyOpen = open.values.any((slots) => slots.isNotEmpty);
    final day = _day ??
        days.firstWhere((day) => open[day]!.isNotEmpty,
            orElse: () => days.first);
    final slots = open[day] ?? const <DateTime>[];
    final slot = _slot != null && slots.contains(_slot) ? _slot : null;
    final accent = context.fdColor(AppColors.primaryBlue);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text.toUpperCase(),
              style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w800,
                  color: _muted(context))),
        );

    return Dialog(
      backgroundColor: _surface(context),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 10, 14),
              child: Row(children: [
                ConnectAvatar(name: name, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Book a visit',
                          style: AppTextStyles.headline2
                              .copyWith(fontSize: 19, color: _ink(context))),
                      Text('$name · ${doctor.hospital}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption
                              .copyWith(color: _muted(context))),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: _muted(context)),
                ),
              ]),
            ),
            Divider(height: 1, color: _line(context)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!anyOpen)
                      FdEmptyState(
                        title: 'No free times',
                        message: '$name has no free visit times in the next '
                            'two weeks. You can send a chat request instead.',
                        icon: Icons.event_busy_outlined,
                      )
                    else ...[
                      label('Day'),
                      SizedBox(
                        height: 82,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = days[index];
                            final free = open[item]!;
                            final status = schedule[item.weekday - 1].status;
                            final selected = item == day;
                            final enabled = free.isNotEmpty;
                            final closesAt = item.add(Duration(
                                minutes: ConnectService.minutesOf(
                                    schedule[item.weekday - 1].end)));
                            final note = enabled
                                ? '${free.length} free'
                                : switch (status) {
                                    DayStatus.off => 'Off',
                                    DayStatus.busy => 'Busy',
                                    DayStatus.available => closesAt.isBefore(
                                            DateTime.now()
                                                .add(const Duration(hours: 1)))
                                        ? 'Closed'
                                        : 'Full',
                                  };
                            final fg = selected ? Colors.white : _ink(context);
                            return Opacity(
                              opacity: enabled ? 1 : .45,
                              child: Material(
                                color: selected ? accent : _surface(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                      color: selected ? accent : _line(context)),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: enabled
                                      ? () => setState(() {
                                            _day = item;
                                            _slot = null;
                                          })
                                      : null,
                                  child: SizedBox(
                                    width: 66,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(_visitDays[item.weekday - 1],
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: selected
                                                    ? Colors.white70
                                                    : _muted(context))),
                                        const SizedBox(height: 2),
                                        Text('${item.day}',
                                            style: TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w800,
                                                color: fg)),
                                        const SizedBox(height: 2),
                                        Text(note,
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: selected
                                                    ? Colors.white
                                                    : enabled
                                                        ? const Color(
                                                            0xFF16A34A)
                                                        : _muted(context))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      label('Time · ${visitDayLabel(day)}'),
                      if (slots.isEmpty)
                        Text('No free times on this day.',
                            style: TextStyle(color: _muted(context)))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final time in slots)
                              ChoiceChip(
                                label: Text(visitClock(time)),
                                selected: time == slot,
                                showCheckmark: false,
                                selectedColor: accent,
                                backgroundColor: _surface(context),
                                side: BorderSide(
                                    color: time == slot
                                        ? accent
                                        : _line(context)),
                                labelStyle: TextStyle(
                                  color: time == slot
                                      ? Colors.white
                                      : _ink(context),
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) =>
                                    setState(() => _slot = time),
                              ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      label('Reason for the visit'),
                      TextField(
                        controller: _reason,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Follow-up for high blood pressure',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.fdColor(AppColors.surfaceMuted),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18, color: accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'The visit is in person at ${doctor.hospital}. '
                                '$name confirms the time first. Any fees are '
                                'paid at the hospital.',
                                style: AppTextStyles.caption.copyWith(
                                    color: _muted(context), height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: context.fdColor(AppColors.errorRed))),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        _busy || slot == null ? null : () => _book(slot),
                    icon: const Icon(Icons.event_available_rounded, size: 18),
                    label: Text(_busy
                        ? 'Booking…'
                        : slot == null
                            ? 'Choose a time'
                            : 'Request ${visitClock(slot)}'),
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

// ------------------------------------------------------------------ cards

/// One visit, with the actions that fit the viewer (user or doctor).
class VisitCard extends StatefulWidget {
  const VisitCard({super.key, required this.visit});
  final Visit visit;

  @override
  State<VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<VisitCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _toast(context, done);
    } on ConnectException catch (error) {
      if (mounted) _toast(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    if (me == null) return const SizedBox.shrink();
    final visit = widget.visit;
    final asDoctor = me.email == visit.doctorEmail;
    final detail = asDoctor
        ? 'In-person visit'
        : [
            visit.doctorType,
            if (visit.specialty.isNotEmpty) visit.specialty,
          ].join(' · ');
    final other = asDoctor ? visit.patientName : visit.doctorName;
    final color = visitStatusColor(context, visit);
    final chat = connect.directBetween(visit.patientEmail, visit.doctorEmail);
    final accent = context.fdColor(AppColors.primaryBlue);

    final actions = <Widget>[
      if (chat != null)
        TextButton.icon(
          onPressed: () => openConversation(context, chat.id),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
          label: const Text('Message'),
        )
      else if (!asDoctor)
        TextButton.icon(
          onPressed: () => openDoctorProfile(context, visit.doctorEmail),
          icon: const Icon(Icons.badge_outlined, size: 17),
          label: const Text('Doctor profile'),
        ),
      if (visit.isUpcoming &&
          (!asDoctor || visit.status == VisitStatus.confirmed))
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  final reason = await _askVisitReason(
                    context,
                    title: 'Cancel this visit?',
                    message: '$other will be told that the visit on '
                        '${visitDayLabel(visit.start)} at '
                        '${visitClock(visit.start)} is cancelled.',
                    action: 'Cancel visit',
                  );
                  if (reason == null || !mounted) return;
                  await _run(
                      () => connect.cancelVisit(visit.id, me, reason: reason),
                      'Visit cancelled.');
                },
          style: TextButton.styleFrom(
              foregroundColor: context.fdColor(AppColors.errorRed)),
          child: const Text('Cancel visit'),
        ),
      if (asDoctor && visit.status == VisitStatus.requested && !visit.isExpired)
        ...[
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  final reason = await _askVisitReason(
                    context,
                    title: 'Decline this visit?',
                    message: '${visit.patientName} will be told you can\'t '
                        'see them at this time.',
                    action: 'Decline',
                  );
                  if (reason == null || !mounted) return;
                  await _run(
                      () => connect.declineVisit(visit.id, me, reason: reason),
                      'Visit declined.');
                },
          child: const Text('Decline'),
        ),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => connect.confirmVisit(visit.id, me),
                  'Visit confirmed. ${visit.patientName} has been notified.'),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Confirm'),
        ),
      ],
      if (asDoctor && visit.canComplete)
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => connect.completeVisit(visit.id, me),
                  'Visit marked as completed.'),
          icon: const Icon(Icons.task_alt_rounded, size: 18),
          label: const Text('Mark completed'),
        ),
    ];

    return FdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Text(_visitMonths[visit.start.month - 1].toUpperCase(),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                          color: accent)),
                  Text('${visit.start.day}',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: _ink(context))),
                  Text(_visitDays[visit.start.weekday - 1],
                      style: TextStyle(fontSize: 11, color: _muted(context))),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(other,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: FontWeight.w700, color: _ink(context))),
                    const SizedBox(height: 2),
                    Text(
                      '${visitTimeRange(visit)} · $detail',
                      style: AppTextStyles.caption
                          .copyWith(color: _muted(context)),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.local_hospital_outlined,
                          size: 14, color: _muted(context)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(visit.hospital,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption
                                .copyWith(color: _muted(context))),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('“${visit.reason}”',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText2
                            .copyWith(color: _ink(context), height: 1.35)),
                    if (visit.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${visit.status == VisitStatus.declined ? 'Declined' : 'Cancelled'}: ${visit.note}',
                        style: AppTextStyles.caption.copyWith(color: color),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Tag(visit.statusLabel, color),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- screen

/// "My visits" for users (upcoming / past) and doctors (requests /
/// upcoming / past).
class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    ConnectService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    if (me == null) {
      return _unavailable(context, 'Sign in to see your visits.');
    }
    final isDoctor = ConnectService.isDoctor(me);
    final upcoming = connect.upcomingVisitsFor(me.email);
    final past = connect.pastVisitsFor(me.email);
    final requests = isDoctor
        ? connect.visitRequestsFor(me.email)
        : const <Visit>[];
    final tabs = isDoctor
        ? [
            ('Requests', requests),
            (
              'Upcoming',
              upcoming
                  .where((visit) => visit.status == VisitStatus.confirmed)
                  .toList()
            ),
            ('Past', past),
          ]
        : [('Upcoming', upcoming), ('Past', past)];
    final tab = _tab.clamp(0, tabs.length - 1);
    final items = tabs[tab].$2;

    Widget empty() {
      final label = tabs[tab].$1;
      if (label == 'Requests') {
        return const FdEmptyState(
          title: 'No visit requests',
          message: 'When a user books a time from your weekly schedule, the '
              'request shows up here for you to confirm.',
          icon: Icons.inbox_outlined,
        );
      }
      if (label == 'Past') {
        return const FdEmptyState(
          title: 'No past visits',
          message: 'Completed, cancelled and declined visits are kept here.',
          icon: Icons.history_rounded,
        );
      }
      return isDoctor
          ? FdEmptyState(
              title: 'No confirmed visits',
              message: 'Confirmed visits appear here. Keep your weekly '
                  'schedule up to date so users can book you.',
              icon: Icons.event_available_outlined,
              actionLabel: 'Edit weekly schedule',
              onAction: () => openScheduleEditor(context),
            )
          : FdEmptyState(
              title: 'No upcoming visits',
              message: 'Find a doctor on Find Doctor and book a time from '
                  'their weekly schedule.',
              icon: Icons.event_available_outlined,
              actionLabel: 'Find a doctor',
              onAction: () => openDoctorDirectory(context),
            );
    }

    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(
        title: 'My visits',
        subtitle: isDoctor
            ? 'Requests and visits booked with you'
            : 'Visits you booked with doctors',
        showBack: Navigator.of(context).canPop(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: _segmentStyle(context),
                      segments: [
                        for (var i = 0; i < tabs.length; i++)
                          ButtonSegment<int>(
                            value: i,
                            label: Text(tabs[i].$2.isEmpty
                                ? tabs[i].$1
                                : '${tabs[i].$1} (${tabs[i].$2.length})'),
                          ),
                      ],
                      selected: {tab},
                      onSelectionChanged: (value) =>
                          setState(() => _tab = value.first),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (isDoctor)
                  OutlinedButton.icon(
                    onPressed: () => openScheduleEditor(context),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Weekly schedule'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => openDoctorDirectory(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Book a visit'),
                  ),
              ]),
              const SizedBox(height: 16),
              if (items.isEmpty)
                empty()
              else
                for (final visit in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: VisitCard(key: ValueKey(visit.id), visit: visit),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- people

/// A small card about someone in a directory, with the ways to reach them.
Future<void> showPersonCard(
  BuildContext context, {
  required String email,
  required String name,
  required String subtitle,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final connect = dialogContext.watch<ConnectService>();
      final me = dialogContext.watch<PrototypeSession>().account;
      final account = connect.accountByEmail(email);
      final chat = me == null ? null : connect.directBetween(me.email, email);
      final shared = me == null
          ? const <Visit>[]
          : connect
              .visitsFor(me.email)
              .where((visit) =>
                  visit.patientEmail == email || visit.doctorEmail == email)
              .toList();
      final isDoctor = ConnectService.isDoctor(account);
      return AlertDialog(
        backgroundColor: _surface(dialogContext),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConnectAvatar(name: name, size: 72),
              const SizedBox(height: 12),
              Text(name,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline2
                      .copyWith(fontSize: 20, color: _ink(dialogContext))),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted(dialogContext))),
              if (shared.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Tag(
                    shared.length == 1
                        ? '1 visit with you'
                        : '${shared.length} visits with you',
                    dialogContext.fdColor(AppColors.primaryBlue)),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (isDoctor)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                openDoctorProfile(context, email);
              },
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Profile'),
            ),
          if (chat != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                openConversation(context, chat.id);
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Message'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
        ],
      );
    },
  );
}
