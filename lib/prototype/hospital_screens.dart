part of 'connect_screens.dart';

// ===========================================================================
// Manager workspace, built from the accounts, schedules, visits and stock
// saved on this PC.
// ===========================================================================

/// Doctor Managers look after their own hospital; General Managers see every
/// hospital (the same rule as doctor applications).
bool managerCovers(AppAccount manager, String hospital) {
  if (!manager.isDoctorManager) return true;
  final mine = ConnectService.hospitalKey(manager.hospital);
  return mine.isNotEmpty && mine == ConnectService.hospitalKey(hospital);
}

List<AppAccount> hospitalDoctorsFor(ConnectService connect, AppAccount manager) =>
    connect.doctors
        .where((doctor) => managerCovers(manager, doctor.hospital))
        .toList();

List<Visit> hospitalVisitsFor(ConnectService connect, AppAccount manager) =>
    connect.allVisits
        .where((visit) => managerCovers(manager, visit.hospital))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

/// Visits holding a slot today, in the manager's scope.
List<Visit> visitsTodayFor(ConnectService connect, AppAccount manager) {
  final now = DateTime.now();
  return hospitalVisitsFor(connect, manager)
      .where((visit) => visit.status.holdsSlot && _sameDay(visit.start, now))
      .toList();
}

String _scopeLabel(AppAccount manager) => manager.isDoctorManager
    ? (manager.hospital.trim().isEmpty ? 'No hospital set' : manager.hospital)
    : 'All hospitals';

class HospitalAlert {
  const HospitalAlert({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final void Function(BuildContext context)? onTap;
}

/// Things a manager should act on, worked out from live data.
List<HospitalAlert> hospitalAlertsFor(
  ConnectService connect,
  InventoryService inventory,
  AppAccount manager,
) {
  const amber = Color(0xFFD97706);
  const red = Color(0xFFC62828);
  const slate = Color(0xFF64748B);
  final alerts = <HospitalAlert>[];
  final now = DateTime.now();
  final doctors = hospitalDoctorsFor(connect, manager);

  for (final doctor in doctors) {
    final waiting = connect
        .visitRequestsFor(doctor.email)
        .where((visit) => now.difference(visit.createdAt).inHours >= 24)
        .toList();
    if (waiting.isEmpty) continue;
    final name = ConnectService.displayName(doctor);
    alerts.add(HospitalAlert(
      icon: Icons.hourglass_bottom_rounded,
      color: amber,
      title: waiting.length == 1
          ? '$name has 1 visit request waiting over a day'
          : '$name has ${waiting.length} visit requests waiting over a day',
      body: 'Next one: ${waiting.first.patientName}, '
          '${visitDayLabel(waiting.first.start)} at '
          '${visitClock(waiting.first.start)}.',
      onTap: (context) => openDoctorProfile(context, doctor.email),
    ));
  }

  final expired = hospitalVisitsFor(connect, manager)
      .where((visit) =>
          visit.isExpired && now.difference(visit.start).inDays < 7)
      .length;
  if (expired > 0) {
    alerts.add(HospitalAlert(
      icon: Icons.event_busy_outlined,
      color: red,
      title: expired == 1
          ? '1 visit request expired without an answer this week'
          : '$expired visit requests expired without an answer this week',
      body: 'Users booked these times but no doctor confirmed them.',
      onTap: (context) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const HospitalSchedulesScreen())),
    ));
  }

  final noSchedule =
      doctors.where((doctor) => !connect.hasCustomSchedule(doctor.email)).toList();
  if (noSchedule.isNotEmpty) {
    alerts.add(HospitalAlert(
      icon: Icons.edit_calendar_outlined,
      color: slate,
      title: noSchedule.length == 1
          ? '1 doctor hasn\'t set a weekly schedule'
          : '${noSchedule.length} doctors haven\'t set a weekly schedule',
      body: '${noSchedule.take(3).map(ConnectService.displayName).join(', ')}'
          '${noSchedule.length > 3 ? ' and others' : ''} can be booked on the '
          'default hours (Mon–Fri 09:00–17:00) until they set their own.',
      onTap: (context) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const HospitalSchedulesScreen())),
    ));
  }

  final hrCases = HrService.instance.casesFor(manager);
  final waiting =
      hrCases.where((item) => item.status == HrStatus.requested).length;
  if (waiting > 0) {
    alerts.add(HospitalAlert(
      icon: Icons.inbox_outlined,
      color: amber,
      title: waiting == 1
          ? '1 work request waiting for HR'
          : '$waiting work requests waiting for HR',
      body: 'Students and New Doctors asked to work here.',
      onTap: (context) => openHrCenter(context),
    ));
  }
  final ready = hrCases.where((item) => item.canComplete).length;
  if (ready > 0) {
    alerts.add(HospitalAlert(
      icon: Icons.how_to_reg_rounded,
      color: const Color(0xFF16A34A),
      title: ready == 1
          ? '1 hiring ready to complete'
          : '$ready hirings ready to complete',
      body: 'The join day has come. Complete the hiring to make them Doctors.',
      onTap: (context) => openHrCenter(context),
    ));
  }

  final low = inventory.lowStockFor(manager.hospital);
  if (low.isNotEmpty) {
    final critical = low.where((item) => item['status'] == 'Critical').length;
    alerts.add(HospitalAlert(
      icon: Icons.inventory_2_outlined,
      color: critical > 0 ? red : amber,
      title: low.length == 1
          ? '1 inventory item is low on stock'
          : '${low.length} inventory items are low on stock',
      body: low.take(3).map((item) => '${item['name']} (${item['stock']})').join(', '),
      onTap: (context) => Navigator.pushNamed(
          context,
          low.first['category'] == 'Medication'
              ? RouteNames.medication
              : RouteNames.equipment),
    ));
  }
  return alerts;
}

Widget _managerOnly(BuildContext context, String title) => Scaffold(
      appBar: FdAppBar(title: title, showBack: true),
      body: const Center(
        child: FdEmptyState(
          title: 'Managers only',
          message: 'Sign in with a manager account to see this page.',
          icon: Icons.lock_outline_rounded,
        ),
      ),
    );

// ---------------------------------------------------------------- doctors

class HospitalDoctorsScreen extends StatefulWidget {
  const HospitalDoctorsScreen({super.key});

  @override
  State<HospitalDoctorsScreen> createState() => _HospitalDoctorsScreenState();
}

class _HospitalDoctorsScreenState extends State<HospitalDoctorsScreen> {
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
    if (me == null) return _managerOnly(context, 'Doctors');
    final all = hospitalDoctorsFor(connect, me);
    final q = _query.trim().toLowerCase();
    final doctors = all
        .where((doctor) =>
            '${doctor.fullName} ${doctor.specialty} ${doctor.hospital} '
                    '${doctor.typeLabel}'
                .toLowerCase()
                .contains(q))
        .toList();
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(
          title: 'Doctors', subtitle: _scopeLabel(me), showBack: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search doctors',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => openHrCenter(context),
                  icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                  label: const Text('Hiring'),
                ),
              ]),
              _SectionTitle('Active doctors',
                  trailing: all.isEmpty ? null : _CountBadge(all.length)),
              if (doctors.isEmpty)
                FdEmptyState(
                  title: all.isEmpty ? 'No doctors yet' : 'No doctors found',
                  message: all.isEmpty
                      ? 'Doctors appear here once you hire them from '
                          'Hiring & staff.'
                      : 'Try another name or specialty.',
                  icon: Icons.medical_services_outlined,
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

// -------------------------------------------------- schedules and today

class HospitalSchedulesScreen extends StatelessWidget {
  const HospitalSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    if (me == null) return _managerOnly(context, 'Schedules');
    final doctors = hospitalDoctorsFor(connect, me);
    final today = visitsTodayFor(connect, me);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final weekEnd = DateTime(now.year, now.month, now.day + 8);
    final coming = hospitalVisitsFor(connect, me)
        .where((visit) =>
            visit.isUpcoming &&
            !visit.start.isBefore(tomorrow) &&
            visit.start.isBefore(weekEnd))
        .toList();
    Widget visitRows(List<Visit> visits, {required bool showDay}) => FdCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (var i = 0; i < visits.length; i++) ...[
              if (i > 0) Divider(height: 1, color: _line(context)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(
                    width: showDay ? 210 : 112,
                    child: Text(
                        showDay
                            ? '${visitDayLabel(visits[i].start)}, '
                                '${visitClock(visits[i].start)}'
                            : visitTimeRange(visits[i]),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink(context))),
                  ),
                  Expanded(
                    child: Text(
                      '${visits[i].patientName} with ${visits[i].doctorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _ink(context)),
                    ),
                  ),
                  _Tag(visits[i].statusLabel,
                      visitStatusColor(context, visits[i])),
                ]),
              ),
            ],
          ]),
        );
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(
          title: 'Schedules & visits',
          subtitle: _scopeLabel(me),
          showBack: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _SectionTitle(visitDayLabel(now),
                  trailing: today.isEmpty ? null : _CountBadge(today.length)),
              if (today.isEmpty)
                FdCard(
                  child: Text('No visits booked for today.',
                      style: TextStyle(color: _muted(context))),
                )
              else
                visitRows(today, showDay: false),
              _SectionTitle('Next 7 days',
                  trailing:
                      coming.isEmpty ? null : _CountBadge(coming.length)),
              if (coming.isEmpty)
                FdCard(
                  child: Text('No visits booked for the coming week.',
                      style: TextStyle(color: _muted(context))),
                )
              else
                visitRows(coming, showDay: true),
              _SectionTitle('Weekly schedules',
                  trailing: const _ScheduleLegend()),
              if (doctors.isEmpty)
                const FdEmptyState(
                  title: 'No doctors yet',
                  message: 'Approved doctors and their weekly schedules '
                      'appear here.',
                  icon: Icons.calendar_month_outlined,
                )
              else
                for (final doctor in doctors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FdCard(
                      onTap: () => openDoctorProfile(context, doctor.email),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            ConnectAvatar(
                                name: ConnectService.displayName(doctor),
                                size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ConnectService.displayName(doctor),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _ink(context))),
                                  Text(
                                    [
                                      doctor.typeLabel,
                                      if (doctor.specialty.isNotEmpty)
                                        doctor.specialty,
                                      if (!me.isDoctorManager) doctor.hospital,
                                    ].join(' · '),
                                    style: AppTextStyles.caption
                                        .copyWith(color: _muted(context)),
                                  ),
                                ],
                              ),
                            ),
                            if (!connect.hasCustomSchedule(doctor.email))
                              _Tag('Default hours', _muted(context)),
                          ]),
                          const SizedBox(height: 12),
                          WeekScheduleView(
                              days: connect.scheduleFor(doctor.email)),
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

// --------------------------------------------------------------- overview

class HospitalOverviewScreen extends StatelessWidget {
  const HospitalOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final inventory = context.watch<InventoryService>();
    final me = context.watch<PrototypeSession>().account;
    if (me == null) return _managerOnly(context, 'Overview');
    final now = DateTime.now();
    final doctors = hospitalDoctorsFor(connect, me);
    final visits = hospitalVisitsFor(connect, me);
    final thisMonth = visits
        .where((visit) =>
            visit.start.year == now.year && visit.start.month == now.month)
        .toList();
    final users = {for (final visit in visits) visit.patientEmail}.length;
    int count(bool Function(Visit visit) test) => thisMonth.where(test).length;
    final breakdown = [
      ('Confirmed', count((v) => v.status == VisitStatus.confirmed),
          const Color(0xFF16A34A)),
      ('Waiting for doctor',
          count((v) => v.status == VisitStatus.requested && !v.isExpired),
          const Color(0xFFD97706)),
      ('Completed', count((v) => v.status == VisitStatus.completed),
          context.fdColor(AppColors.primaryBlue)),
      ('Cancelled or declined',
          count((v) =>
              v.status == VisitStatus.cancelled ||
              v.status == VisitStatus.declined ||
              v.isExpired),
          const Color(0xFF64748B)),
    ];
    final perDoctor = <String, int>{};
    for (final visit in thisMonth) {
      perDoctor.update(visit.doctorName, (n) => n + 1, ifAbsent: () => 1);
    }
    final busiest = perDoctor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final items = inventory.itemsFor(me.hospital);
    final low = inventory.lowStockFor(me.hospital);

    Widget stat(String label, String value, IconData icon) => SizedBox(
          width: 200,
          child: FdCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: context.fdColor(AppColors.primaryBlue)),
                const SizedBox(height: 12),
                Text(value,
                    style: AppTextStyles.headline2
                        .copyWith(fontSize: 24, color: _ink(context))),
                const SizedBox(height: 2),
                Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: _muted(context))),
              ],
            ),
          ),
        );

    final monthName = _visitMonths[now.month - 1];
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(
          title: 'Hospital overview', subtitle: _scopeLabel(me), showBack: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                stat('Active doctors', '${doctors.length}',
                    Icons.medical_services_outlined),
                stat('Visits in $monthName', '${thisMonth.length}',
                    Icons.event_note_outlined),
                stat('Visits today', '${visitsTodayFor(connect, me).length}',
                    Icons.today_outlined),
                stat('Users who booked', '$users', Icons.people_outline),
                stat('Stock items', '${items.length}',
                    Icons.inventory_2_outlined),
                stat('Low on stock', '${low.length}',
                    Icons.warning_amber_rounded),
              ]),
              _SectionTitle('Visits in $monthName by status'),
              FdCard(
                child: thisMonth.isEmpty
                    ? Text('No visits booked this month yet.',
                        style: TextStyle(color: _muted(context)))
                    : Column(children: [
                        for (final row in breakdown)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(children: [
                              SizedBox(
                                width: 170,
                                child: Text(row.$1,
                                    style: TextStyle(color: _ink(context))),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: row.$2 / thisMonth.length,
                                    minHeight: 10,
                                    color: row.$3,
                                    backgroundColor:
                                        row.$3.withValues(alpha: 0.12),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text('${row.$2}',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _ink(context))),
                              ),
                            ]),
                          ),
                      ]),
              ),
              _SectionTitle('Busiest doctors in $monthName'),
              FdCard(
                child: busiest.isEmpty
                    ? Text('No visits yet.',
                        style: TextStyle(color: _muted(context)))
                    : Column(children: [
                        for (final entry in busiest.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              ConnectAvatar(name: entry.key, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(entry.key,
                                    style: TextStyle(color: _ink(context))),
                              ),
                              Text(
                                  entry.value == 1
                                      ? '1 visit'
                                      : '${entry.value} visits',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _ink(context))),
                            ]),
                          ),
                      ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- alerts

class HospitalAlertsScreen extends StatelessWidget {
  const HospitalAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final inventory = context.watch<InventoryService>();
    context.watch<HrService>();
    final me = context.watch<PrototypeSession>().account;
    if (me == null) return _managerOnly(context, 'Alerts');
    final alerts = hospitalAlertsFor(connect, inventory, me);
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(title: 'Alerts', subtitle: _scopeLabel(me), showBack: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (alerts.isEmpty)
                const FdEmptyState(
                  title: 'All clear',
                  message: 'Unanswered visit requests, missing schedules and '
                      'low stock show up here.',
                  icon: Icons.verified_outlined,
                )
              else
                for (final alert in alerts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AlertTile(alert: alert),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});
  final HospitalAlert alert;

  @override
  Widget build(BuildContext context) => FdCard(
        padding: const EdgeInsets.all(14),
        onTap: alert.onTap == null ? null : () => alert.onTap!(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(alert.icon, color: alert.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title,
                      style: AppTextStyles.bodyText2.copyWith(
                          fontWeight: FontWeight.w700, color: _ink(context))),
                  const SizedBox(height: 2),
                  Text(alert.body,
                      style: AppTextStyles.bodyText2
                          .copyWith(color: _muted(context))),
                ],
              ),
            ),
            if (alert.onTap != null)
              Icon(Icons.chevron_right_rounded, color: _muted(context)),
          ],
        ),
      );
}
