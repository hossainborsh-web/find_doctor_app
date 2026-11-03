part of 'connect_screens.dart';

// ===========================================================================
// Hiring: "My career" for Students and New Doctors, and "Hiring & staff"
// for HR (General Managers and Doctor Managers). The rules live in
// HrService and AccountService; these screens only show what is allowed.
// ===========================================================================

Color hrStatusColor(BuildContext context, HrCase item) =>
    switch (item.status) {
      HrStatus.requested => const Color(0xFFD97706),
      HrStatus.offered => context.fdColor(AppColors.primaryBlue),
      HrStatus.scheduled => const Color(0xFF0D9488),
      HrStatus.hired => const Color(0xFF16A34A),
      HrStatus.declined ||
      HrStatus.cancelled =>
        context.fdColor(AppColors.errorRed),
      HrStatus.withdrawn || HrStatus.closed => const Color(0xFF64748B),
    };

void openCareer(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const CareerScreen()));

void openHrCenter(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const HrCenterScreen()));

Future<bool> _hrRun(
  BuildContext context,
  Future<void> Function() action,
  String done,
) async {
  try {
    await action();
    if (context.mounted) _toast(context, done);
    return true;
  } on HrException catch (error) {
    if (context.mounted) _toast(context, error.message);
  } on AccountException catch (error) {
    if (context.mounted) _toast(context, error.message);
  }
  return false;
}

Future<bool> _confirmHr(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Text(message,
            style: TextStyle(color: _muted(dialogContext), height: 1.4)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Back'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: dialogContext.fdColor(AppColors.errorRed),
                  foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

String _seekerDetails(AppAccount account) {
  if (account.doctorKind == DoctorKind.student) {
    return [
      if (account.university.isNotEmpty) account.university,
      if (account.graduationYear.isNotEmpty)
        'Graduated ${account.graduationYear}',
    ].join(' · ');
  }
  return [
    if (account.specialty.isNotEmpty) account.specialty,
    if (account.previousHospital.isNotEmpty)
      'Before: ${account.previousHospital}',
  ].join(' · ');
}

// ------------------------------------------------------------ certificate

Future<void> showCertificate(BuildContext context, String path, String name) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: _surface(dialogContext),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Text('Graduation certificate · $name',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink(dialogContext))),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: Icon(Icons.close_rounded, color: _muted(dialogContext)),
                ),
              ]),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: FdImage(
                  path,
                  fit: BoxFit.contain,
                  placeholder: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('This image could not be opened.',
                        style: TextStyle(color: _muted(dialogContext))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

class _CertificateThumb extends StatelessWidget {
  const _CertificateThumb({required this.path, required this.name});
  final String path;
  final String name;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 92,
      height: 66,
      decoration: BoxDecoration(
        color: context.fdColor(AppColors.surfaceMuted),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line(context)),
      ),
      child: Icon(Icons.workspace_premium_outlined, color: _muted(context)),
    );
    if (path.isEmpty) return placeholder;
    return Tooltip(
      message: 'Open certificate',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showCertificate(context, path, name),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FdImage(
            path,
            width: 92,
            height: 66,
            fit: BoxFit.cover,
            cacheWidth: 200,
            placeholder: placeholder,
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- join day

typedef JoinDayChoice = ({
  String hospital,
  DateTime joinAt,
  String place,
  String message,
});

Future<JoinDayChoice?> _showJoinDayDialog(
  BuildContext context, {
  required String title,
  required String action,
  required String intro,
  String? hospital,
  bool chooseHospital = false,
  DateTime? initial,
  String? place,
  bool askMessage = true,
}) {
  return showDialog<JoinDayChoice>(
    context: context,
    builder: (_) => _JoinDayDialog(
      title: title,
      action: action,
      intro: intro,
      hospital: hospital,
      chooseHospital: chooseHospital,
      initial: initial,
      place: place,
      askMessage: askMessage,
    ),
  );
}

class _JoinDayDialog extends StatefulWidget {
  const _JoinDayDialog({
    required this.title,
    required this.action,
    required this.intro,
    required this.hospital,
    required this.chooseHospital,
    required this.initial,
    required this.place,
    required this.askMessage,
  });

  final String title;
  final String action;
  final String intro;
  final String? hospital;
  final bool chooseHospital;
  final DateTime? initial;
  final String? place;
  final bool askMessage;

  @override
  State<_JoinDayDialog> createState() => _JoinDayDialogState();
}

class _JoinDayDialogState extends State<_JoinDayDialog> {
  late String? _hospital = widget.hospital;
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _place;
  final _message = TextEditingController();
  bool _placeEdited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initial ??
        DateTime(now.year, now.month, now.day + 1, 9, 0);
    _date = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay(hour: initial.hour, minute: initial.minute);
    _place = TextEditingController(
        text: widget.place ??
            (_hospital == null ? '' : 'HR office, $_hospital'));
    _placeEdited = widget.place != null;
  }

  @override
  void dispose() {
    _place.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickHospital() async {
    final picked = await showHospitalPicker(context, initial: _hospital);
    if (picked == null || !mounted) return;
    setState(() {
      _hospital = picked;
      if (!_placeEdited) _place.text = 'HR office, $picked';
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: HrService.maxJoinDays)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _submit() {
    final hospital = _hospital;
    if (hospital == null || hospital.isEmpty) {
      setState(() => _error = 'Choose the hospital.');
      return;
    }
    final joinAt = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (joinAt.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      setState(() =>
          _error = 'Choose a day and time at least 30 minutes from now.');
      return;
    }
    if (_place.text.trim().length < 3) {
      setState(() => _error = 'Say where to come on the join day.');
      return;
    }
    Navigator.pop<JoinDayChoice>(context, (
      hospital: hospital,
      joinAt: joinAt,
      place: _place.text.trim(),
      message: _message.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${ConnectService.two(_time.hour)}:${ConnectService.two(_time.minute)}';
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.intro,
                  style: TextStyle(color: _muted(context), height: 1.35)),
              const SizedBox(height: 16),
              if (widget.chooseHospital)
                OutlinedButton.icon(
                  onPressed: _pickHospital,
                  icon: const Icon(Icons.local_hospital_outlined, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_hospital ?? 'Choose the hospital',
                        overflow: TextOverflow.ellipsis),
                  ),
                )
              else
                Row(children: [
                  Icon(Icons.local_hospital_outlined,
                      size: 18, color: _muted(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_hospital ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: _ink(context))),
                  ),
                ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(visitDayLabel(_date),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(time),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _place,
                onChanged: (_) => _placeEdited = true,
                decoration: const InputDecoration(
                  labelText: 'Where to come',
                  hintText: 'e.g. HR office, Block A, level 2',
                ),
              ),
              if (widget.askMessage) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _message,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 400,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                    hintText: 'What to bring, who to ask for…',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: context.fdColor(AppColors.errorRed))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

// ==================================================================
// Job seekers: My career
// ==================================================================

Future<void> _showApplyDialog(BuildContext context, AppAccount me) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ApplyDialog(me: me),
  );
}

class _ApplyDialog extends StatefulWidget {
  const _ApplyDialog({required this.me});
  final AppAccount me;

  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  final _message = TextEditingController();
  String? _hospital;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final hospital = _hospital;
    if (hospital == null) {
      setState(() => _error = 'Choose a hospital.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await HrService.instance.sendRequest(
          seeker: widget.me, hospital: hospital, message: _message.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(SnackBar(
          content: Text('Request sent to $hospital. Their HR will answer.')));
    } on HrException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = HrService.instance.openRequestCount(widget.me.email);
    return AlertDialog(
      title: const Text('Ask a hospital for work'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your graduation certificate is sent with the request. You have '
              '$open of ${HrService.maxOpenRequests} open requests.',
              style: TextStyle(color: _muted(context), height: 1.35),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final picked =
                          await showHospitalPicker(context, initial: _hospital);
                      if (picked != null && mounted) {
                        setState(() => _hospital = picked);
                      }
                    },
              icon: const Icon(Icons.local_hospital_outlined, size: 18),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(_hospital ?? 'Choose a hospital',
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Message to HR (optional)',
                hintText: 'Why you want to work there, when you can start…',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: context.fdColor(AppColors.errorRed))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(_busy ? 'Sending…' : 'Send request'),
        ),
      ],
    );
  }
}

Future<void> _showCareerDetailsDialog(BuildContext context, AppAccount me) {
  final isStudent = me.doctorKind == DoctorKind.student;
  final first =
      TextEditingController(text: isStudent ? me.university : me.specialty);
  final second = TextEditingController(
      text: isStudent ? me.graduationYear : me.previousHospital);
  String? error;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Career details'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                decoration: InputDecoration(
                    labelText: isStudent ? 'University' : 'Specialty'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: second,
                keyboardType:
                    isStudent ? TextInputType.number : TextInputType.text,
                decoration: InputDecoration(
                    labelText: isStudent
                        ? 'Graduation year'
                        : 'Previous hospital (optional)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: TextStyle(
                        color: dialogContext.fdColor(AppColors.errorRed))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final updated = await AccountService.instance.updateCareer(
                  me.email,
                  university: isStudent ? first.text : null,
                  graduationYear: isStudent ? second.text : null,
                  specialty: isStudent ? null : first.text,
                  previousHospital: isStudent ? null : second.text,
                );
                if (!dialogContext.mounted) return;
                dialogContext.read<PrototypeSession>().signInWithAccount(updated);
                Navigator.pop(dialogContext);
              } on AccountException catch (e) {
                setState(() => error = e.message);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Home for Students and New Doctors: certificate, requests, offers and
/// the join day.
class CareerScreen extends StatelessWidget {
  const CareerScreen({super.key, this.asTab = false});
  final bool asTab;

  Future<void> _uploadCertificate(BuildContext context, AppAccount me) async {
    final path =
        await pickImageFromComputer(title: 'Choose your graduation certificate');
    if (path == null || !context.mounted) return;
    try {
      final updated = await AccountService.instance.setCertificate(me.email, path);
      if (!context.mounted) return;
      context.read<PrototypeSession>().signInWithAccount(updated);
      _toast(context, 'Certificate saved.');
    } on AccountException catch (error) {
      if (context.mounted) _toast(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrService>();
    final connect = context.watch<ConnectService>();
    final session = context.watch<PrototypeSession>();
    final me = session.account;
    if (me == null || !me.isJobSeeker) {
      return _unavailable(
          context, 'My career is for Students and New Doctors looking for work.',
          back: !asTab);
    }
    final cases = hr.casesForSeeker(me.email);
    final scheduled =
        cases.where((item) => item.status == HrStatus.scheduled).toList();
    final offers =
        cases.where((item) => item.status == HrStatus.offered).toList();
    final requests =
        cases.where((item) => item.status == HrStatus.requested).toList();
    final history = cases.where((item) => !item.status.isOpen).toList();
    final accent = context.fdColor(AppColors.primaryBlue);
    final details = _seekerDetails(me);

    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(
        title: 'My career',
        subtitle: '${me.typeLabel} · '
            '${me.openToWork ? 'Open to work' : 'Not looking right now'}',
        showBack: !asTab,
        notificationCount: connect.unreadNotifications(me.email),
        onNotificationTap: () =>
            Navigator.pushNamed(context, RouteNames.notifications),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              FdCard(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  ConnectAvatar(name: me.fullName, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(me.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.headline2.copyWith(
                                    fontSize: 20, color: _ink(context))),
                          ),
                          const SizedBox(width: 8),
                          _Tag(me.typeLabel, accent),
                        ]),
                        const SizedBox(height: 4),
                        Text(details.isEmpty ? 'Add your career details' : details,
                            style: AppTextStyles.bodyText2
                                .copyWith(color: _muted(context))),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact),
                          onPressed: () => _showCareerDetailsDialog(context, me),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit details'),
                        ),
                      ],
                    ),
                  ),
                  Column(children: [
                    Switch(
                      value: me.openToWork,
                      onChanged: (value) async {
                        try {
                          final updated = await AccountService.instance
                              .updateCareer(me.email, openToWork: value);
                          if (context.mounted) {
                            context
                                .read<PrototypeSession>()
                                .signInWithAccount(updated);
                          }
                        } on AccountException catch (error) {
                          if (context.mounted) _toast(context, error.message);
                        }
                      },
                    ),
                    Text('Open to work',
                        style: AppTextStyles.caption
                            .copyWith(color: _muted(context))),
                  ]),
                ]),
              ),
              for (final item in scheduled) ...[
                const _SectionTitle('Your join day'),
                _SeekerCaseCard(item: item, me: me, highlight: true),
              ],
              if (offers.isNotEmpty) ...[
                _SectionTitle('Job offers', trailing: _CountBadge(offers.length)),
                for (final item in offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SeekerCaseCard(item: item, me: me),
                  ),
              ],
              const _SectionTitle('Graduation certificate'),
              FdCard(
                child: Row(children: [
                  _CertificateThumb(path: me.certificatePath, name: me.fullName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      me.hasCertificate
                          ? 'Hospitals see this certificate with your requests '
                              'and in the talent pool.'
                          : 'Upload a photo or scan of your graduation '
                              'certificate. You need it to ask hospitals for '
                              'work and to receive job offers.',
                      style: AppTextStyles.bodyText2
                          .copyWith(color: _muted(context), height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _uploadCertificate(context, me),
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(me.hasCertificate ? 'Replace' : 'Upload'),
                  ),
                ]),
              ),
              _SectionTitle(
                'My requests',
                trailing: FilledButton.icon(
                  onPressed: () => _showApplyDialog(context, me),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Ask a hospital'),
                ),
              ),
              if (requests.isEmpty)
                FdCard(
                  child: Text(
                    'No open requests. Ask up to '
                    '${HrService.maxOpenRequests} hospitals for work, or wait '
                    'for HR to offer you a job from the talent pool.',
                    style: TextStyle(color: _muted(context)),
                  ),
                )
              else
                for (final item in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SeekerCaseCard(item: item, me: me),
                  ),
              if (history.isNotEmpty) ...[
                const _SectionTitle('History'),
                for (final item in history.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SeekerCaseCard(item: item, me: me),
                  ),
              ],
              const _SectionTitle('How hiring works'),
              FdCard(
                child: Text(
                  '1. Upload your graduation certificate.\n'
                  '2. Ask hospitals for work, or wait for HR to offer you a '
                  'job.\n'
                  '3. When HR accepts, you get a join day: go to the hospital '
                  'on that day.\n'
                  '4. After the join day, HR completes your hiring and you '
                  'become a Doctor at that hospital.\n\n'
                  'Only Students and New Doctors can ask for work. Doctor '
                  'Manager permission is given by a General Manager only.',
                  style: AppTextStyles.bodyText2
                      .copyWith(color: _muted(context), height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekerCaseCard extends StatelessWidget {
  const _SeekerCaseCard(
      {required this.item, required this.me, this.highlight = false});
  final HrCase item;
  final AppAccount me;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = hrStatusColor(context, item);
    final join = item.joinAt;
    final actions = <Widget>[
      if (item.status == HrStatus.offered) ...[
        OutlinedButton(
          onPressed: () => _hrRun(
              context,
              () => HrService.instance
                  .respondToOffer(seeker: me, caseId: item.id, accept: false),
              'Offer declined.'),
          child: const Text('Decline'),
        ),
        FilledButton.icon(
          onPressed: () => _hrRun(
              context,
              () => HrService.instance
                  .respondToOffer(seeker: me, caseId: item.id, accept: true),
              'Offer accepted. See you on your join day.'),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Accept offer'),
        ),
      ] else if (item.status == HrStatus.requested ||
          item.status == HrStatus.scheduled)
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor: context.fdColor(AppColors.errorRed)),
          onPressed: () async {
            final ok = await _confirmHr(context,
                title: 'Withdraw?',
                message: item.status == HrStatus.scheduled
                    ? 'You will not join ${item.hospital}. Their HR will be '
                        'told.'
                    : 'Your request to ${item.hospital} will be withdrawn.',
                action: 'Withdraw',
                destructive: true);
            if (!ok || !context.mounted) return;
            await _hrRun(
                context,
                () => HrService.instance
                    .withdraw(seeker: me, caseId: item.id),
                'Withdrawn.');
          },
          child: const Text('Withdraw'),
        ),
    ];
    return Container(
      decoration: highlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color, width: 2),
            )
          : null,
      child: FdCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              ConnectAvatar(
                  name: item.hospital,
                  size: 40,
                  icon: Icons.local_hospital_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.hospital,
                        style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: FontWeight.w700, color: _ink(context))),
                    Text(
                      item.fromHospital
                          ? 'Offered by ${item.hrName} · '
                              '${ConnectService.fullDate(item.createdAt)}'
                          : 'You asked · ${ConnectService.fullDate(item.createdAt)}',
                      style: AppTextStyles.caption
                          .copyWith(color: _muted(context)),
                    ),
                  ],
                ),
              ),
              _Tag(item.status.label, color),
            ]),
            if (join != null && item.status.isOpen) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.event_available_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Join day: ${visitDayLabel(join)} at ${visitClock(join)} · '
                    '${item.place}',
                    style: AppTextStyles.bodyText2.copyWith(
                        fontWeight: FontWeight.w600, color: _ink(context)),
                  ),
                ),
              ]),
            ],
            if (item.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('“${item.message}”',
                  style: AppTextStyles.bodyText2.copyWith(color: _ink(context))),
            ],
            if (item.reply.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('HR: ${item.reply}',
                  style:
                      AppTextStyles.bodyText2.copyWith(color: _muted(context))),
            ],
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.note,
                  style: AppTextStyles.caption.copyWith(color: color)),
            ],
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
      ),
    );
  }
}

// ==================================================================
// HR: Hiring & staff
// ==================================================================

/// Card on the manager dashboard.
class HrSummaryCard extends StatelessWidget {
  const HrSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrService>();
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    if (!AccountService.isHr(me)) return const SizedBox.shrink();
    final cases = hr.casesFor(me);
    final waiting =
        cases.where((item) => item.status == HrStatus.requested).length;
    final ready = cases.where((item) => item.canComplete).length;
    final pool = connect.accounts
        .where((account) =>
            account.isJobSeeker &&
            account.openToWork &&
            account.status == AccountStatus.active)
        .toList();
    final students = pool
        .where((account) => account.doctorKind == DoctorKind.student)
        .length;
    final accent = context.fdColor(AppColors.primaryBlue);
    return FdCard(
      onTap: () => openHrCenter(context),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: context.fdColor(AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.badge_outlined, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hiring & staff',
                  style: AppTextStyles.bodyText1.copyWith(
                      fontWeight: FontWeight.w700, color: _ink(context))),
              const SizedBox(height: 2),
              Text(
                '$waiting request${waiting == 1 ? '' : 's'} waiting · '
                '$students student${students == 1 ? '' : 's'} and '
                '${pool.length - students} new doctor'
                '${pool.length - students == 1 ? '' : 's'} available'
                '${ready > 0 ? ' · $ready ready to hire' : ''}',
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
            ],
          ),
        ),
        if (waiting + ready > 0) ...[
          _CountBadge(waiting + ready),
          const SizedBox(width: 8),
        ],
        Icon(Icons.chevron_right_rounded, color: _muted(context)),
      ]),
    );
  }
}

class HrCenterScreen extends StatefulWidget {
  const HrCenterScreen({super.key});

  @override
  State<HrCenterScreen> createState() => _HrCenterScreenState();
}

class _HrCenterScreenState extends State<HrCenterScreen> {
  int _tab = 0;
  String _query = '';
  String _kind = 'All';

  @override
  void initState() {
    super.initState();
    HrService.instance.load();
    ConnectService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrService>();
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    if (me == null || !AccountService.isHr(me)) {
      return _unavailable(context,
          'Only General Managers and Doctor Managers can open hiring.');
    }
    final cases = hr.casesFor(me);
    final requests =
        cases.where((item) => item.status == HrStatus.requested).toList();
    final joinDays = cases
        .where((item) =>
            item.status == HrStatus.offered ||
            item.status == HrStatus.scheduled)
        .toList()
      ..sort((a, b) => (a.joinAt ?? a.createdAt)
          .compareTo(b.joinAt ?? b.createdAt));
    final history = cases.where((item) => !item.status.isOpen).toList();
    final seekers = connect.accounts
        .where((account) =>
            account.isJobSeeker &&
            account.status == AccountStatus.active &&
            account.email != me.email)
        .toList();
    final available = seekers.where((account) => account.openToWork).toList();
    final students = available
        .where((account) => account.doctorKind == DoctorKind.student)
        .length;
    final newDoctors = available.length - students;
    final staff = connect.accounts
        .where((account) =>
            account.practises &&
            account.status == AccountStatus.active &&
            account.hospital.trim().isNotEmpty &&
            AccountService.hrCovers(me, account.hospital))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    final q = _query.trim().toLowerCase();
    final pool = available
        .where((account) =>
            (_kind == 'All' ||
                (_kind == 'Students') ==
                    (account.doctorKind == DoctorKind.student)) &&
            '${account.fullName} ${account.specialty} ${account.university} '
                    '${account.previousHospital}'
                .toLowerCase()
                .contains(q))
        .toList()
      ..sort((a, b) {
        if (a.hasCertificate != b.hasCertificate) {
          return a.hasCertificate ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    final tabs = [
      ('Requests', requests.length),
      ('Talent pool', available.length),
      ('Join days', joinDays.length),
      ('Staff', staff.length),
      ('History', 0),
    ];
    final tab = _tab.clamp(0, tabs.length - 1);

    Widget stat(String label, int value, IconData icon) => SizedBox(
          width: 196,
          child: FdCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: context.fdColor(AppColors.primaryBlue)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value',
                        style: AppTextStyles.headline2
                            .copyWith(fontSize: 22, color: _ink(context))),
                    Text(label,
                        style: AppTextStyles.caption
                            .copyWith(color: _muted(context))),
                  ],
                ),
              ),
            ]),
          ),
        );

    Widget empty(String title, String message, IconData icon) =>
        FdEmptyState(title: title, message: message, icon: icon);

    Widget content;
    switch (tab) {
      case 0:
        content = requests.isEmpty
            ? empty('No requests waiting',
                'Students and New Doctors who ask to work here appear here.',
                Icons.inbox_outlined)
            : Column(children: [
                for (final item in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HrCaseCard(item: item, me: me),
                  ),
              ]);
      case 1:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, university or specialty',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: _segmentStyle(context),
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: 'Students', label: Text('Students')),
                  ButtonSegment(
                      value: 'New Doctors', label: Text('New Doctors')),
                ],
                selected: {_kind},
                onSelectionChanged: (value) =>
                    setState(() => _kind = value.first),
              ),
            ]),
            const SizedBox(height: 12),
            if (pool.isEmpty)
              empty(
                  available.isEmpty ? 'Nobody is looking for work' : 'No match',
                  available.isEmpty
                      ? 'Students and New Doctors who are open to work appear '
                          'here.'
                      : 'Try another name or filter.',
                  Icons.person_search_outlined)
            else
              for (final account in pool)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SeekerCard(seeker: account, me: me),
                ),
          ],
        );
      case 2:
        content = joinDays.isEmpty
            ? empty('No join days',
                'Accepted requests and job offers appear here until the '
                    'hiring is completed.',
                Icons.event_available_outlined)
            : Column(children: [
                for (final item in joinDays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HrCaseCard(item: item, me: me),
                  ),
              ]);
      case 3:
        content = staff.isEmpty
            ? empty('No doctors yet',
                'Doctors you hire appear here.', Icons.groups_outlined)
            : Column(children: [
                for (final account in staff)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StaffCard(doctor: account, me: me),
                  ),
              ]);
      default:
        content = history.isEmpty
            ? empty('No history yet', 'Finished hiring cases are kept here.',
                Icons.history_rounded)
            : Column(children: [
                for (final item in history.take(50))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HrCaseCard(item: item, me: me),
                  ),
              ]);
    }

    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(
        title: 'Hiring & staff',
        subtitle: me.isGeneralManager
            ? 'General Manager · every hospital'
            : 'Doctor Manager · ${me.hospital}',
        showBack: Navigator.of(context).canPop(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                stat('Students available', students, Icons.school_outlined),
                stat('New Doctors available', newDoctors,
                    Icons.medical_services_outlined),
                stat('Requests waiting', requests.length, Icons.inbox_outlined),
                stat('Join days', joinDays.length,
                    Icons.event_available_outlined),
              ]),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: _segmentStyle(context),
                  segments: [
                    for (var i = 0; i < tabs.length; i++)
                      ButtonSegment<int>(
                        value: i,
                        label: Text(tabs[i].$2 == 0 || i == 4
                            ? tabs[i].$1
                            : '${tabs[i].$1} (${tabs[i].$2})'),
                      ),
                  ],
                  selected: {tab},
                  onSelectionChanged: (value) =>
                      setState(() => _tab = value.first),
                ),
              ),
              const SizedBox(height: 16),
              content,
              const SizedBox(height: 18),
              Text(
                me.isGeneralManager
                    ? 'Rules: only Students and New Doctors can be hired. You '
                        'can hire for any hospital and give or remove Doctor '
                        'Manager permission. Nobody can change their own role.'
                    : 'Rules: you hire for ${me.hospital} only. Only a General '
                        'Manager can give Doctor Manager permission. Nobody can '
                        'change their own role.',
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrCaseCard extends StatelessWidget {
  const _HrCaseCard({required this.item, required this.me});
  final HrCase item;
  final AppAccount me;

  @override
  Widget build(BuildContext context) {
    final color = hrStatusColor(context, item);
    final join = item.joinAt;
    final service = HrService.instance;
    final actions = <Widget>[];
    switch (item.status) {
      case HrStatus.requested:
        actions.addAll([
          OutlinedButton(
            onPressed: () async {
              final reason = await _askVisitReason(context,
                  title: 'Decline ${item.seekerName}?',
                  message: 'They will be told that ${item.hospital} declined '
                      'the request.',
                  action: 'Decline',
                  keepLabel: 'Back');
              if (reason == null || !context.mounted) return;
              await _hrRun(
                  context,
                  () => service.declineRequest(
                      actor: me, caseId: item.id, reason: reason),
                  'Request declined.');
            },
            child: const Text('Decline'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final choice = await _showJoinDayDialog(context,
                  title: 'Accept ${item.seekerName}',
                  action: 'Accept & send join day',
                  intro: 'Choose the day ${item.seekerName} should come to '
                      '${item.hospital}. After that day you can complete the '
                      'hiring.',
                  hospital: item.hospital);
              if (choice == null || !context.mounted) return;
              await _hrRun(
                  context,
                  () => service.acceptRequest(
                      actor: me,
                      caseId: item.id,
                      joinAt: choice.joinAt,
                      place: choice.place,
                      reply: choice.message),
                  'Accepted. ${item.seekerName} has been told the join day.');
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Accept & set join day'),
          ),
        ]);
      case HrStatus.offered:
      case HrStatus.scheduled:
        actions.addAll([
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: context.fdColor(AppColors.errorRed)),
            onPressed: () async {
              final reason = await _askVisitReason(context,
                  title: 'Cancel this hiring?',
                  message: '${item.seekerName} will be told it is cancelled.',
                  action: 'Cancel hiring',
                  keepLabel: 'Back');
              if (reason == null || !context.mounted) return;
              await _hrRun(
                  context,
                  () => service.cancel(
                      actor: me, caseId: item.id, reason: reason),
                  'Cancelled.');
            },
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              final choice = await _showJoinDayDialog(context,
                  title: 'Change join day',
                  action: 'Save join day',
                  intro: '${item.seekerName} will be told the new day.',
                  hospital: item.hospital,
                  initial: join,
                  place: item.place,
                  askMessage: false);
              if (choice == null || !context.mounted) return;
              await _hrRun(
                  context,
                  () => service.reschedule(
                      actor: me,
                      caseId: item.id,
                      joinAt: choice.joinAt,
                      place: choice.place),
                  'Join day changed.');
            },
            child: const Text('Change join day'),
          ),
          if (item.status == HrStatus.scheduled)
            FilledButton.icon(
              onPressed: item.canComplete
                  ? () async {
                      final ok = await _confirmHr(context,
                          title: 'Complete hiring?',
                          message: '${item.seekerName} becomes a Doctor at '
                              '${item.hospital}. Their other requests and '
                              'offers close.',
                          action: 'Complete hiring');
                      if (!ok || !context.mounted) return;
                      await _hrRun(
                          context,
                          () => service
                              .completeHiring(actor: me, caseId: item.id)
                              .then((_) {}),
                          '${item.seekerName} is now a Doctor at '
                              '${item.hospital}.');
                    }
                  : null,
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: Text(item.canComplete || join == null
                  ? 'Complete hiring'
                  : 'Complete from ${ConnectService.fullDate(join)}'),
            ),
        ]);
      default:
        break;
    }

    return FdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConnectAvatar(name: item.seekerName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(item.seekerName,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText1.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _ink(context))),
                      ),
                      const SizedBox(width: 8),
                      _Tag(item.kindLabel,
                          context.fdColor(AppColors.primaryBlue)),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (me.isGeneralManager) item.hospital,
                        item.fromHospital
                            ? 'Offer by ${item.hrName}'
                            : 'Asked ${ConnectService.fullDate(item.createdAt)}',
                      ].join(' · '),
                      style: AppTextStyles.caption
                          .copyWith(color: _muted(context)),
                    ),
                    if (join != null && item.status.isOpen) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Join day: ${visitDayLabel(join)} at '
                        '${visitClock(join)} · ${item.place}',
                        style: AppTextStyles.bodyText2.copyWith(
                            fontWeight: FontWeight.w600, color: _ink(context)),
                      ),
                    ],
                    if (item.message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('“${item.message}”',
                          style: AppTextStyles.bodyText2
                              .copyWith(color: _ink(context))),
                    ],
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.note,
                          style: AppTextStyles.caption.copyWith(color: color)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Tag(item.status.label, color),
                  const SizedBox(height: 8),
                  _CertificateThumb(
                      path: item.certificatePath, name: item.seekerName),
                ],
              ),
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

class _SeekerCard extends StatelessWidget {
  const _SeekerCard({required this.seeker, required this.me});
  final AppAccount seeker;
  final AppAccount me;

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrService>();
    final scheduled = hr.scheduledFor(seeker.email);
    final mine = hr
        .casesForSeeker(seeker.email)
        .where((item) =>
            item.status.isOpen && AccountService.hrCovers(me, item.hospital))
        .toList();
    final details = _seekerDetails(seeker);
    final canOffer = seeker.hasCertificate &&
        scheduled == null &&
        (me.isGeneralManager || mine.isEmpty);
    final reason = !seeker.hasCertificate
        ? 'No certificate yet'
        : scheduled != null
            ? 'Join day at ${scheduled.hospital}'
            : mine.isNotEmpty
                ? mine.first.status.label
                : null;

    return FdCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        ConnectAvatar(name: seeker.fullName, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(seeker.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText1.copyWith(
                          fontWeight: FontWeight.w700, color: _ink(context))),
                ),
                const SizedBox(width: 8),
                _Tag(seeker.typeLabel, context.fdColor(AppColors.primaryBlue)),
              ]),
              const SizedBox(height: 2),
              Text(details.isEmpty ? 'No details yet' : details,
                  style:
                      AppTextStyles.caption.copyWith(color: _muted(context))),
              const SizedBox(height: 4),
              Text(
                'On Find Doctor since ${ConnectService.fullDate(seeker.createdAt)}',
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CertificateThumb(path: seeker.certificatePath, name: seeker.fullName),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: canOffer
                  ? () async {
                      final choice = await _showJoinDayDialog(context,
                          title: 'Offer ${seeker.fullName} a job',
                          action: 'Send offer',
                          intro: 'They will see the offer with its join day '
                              'and can accept or decline.',
                          hospital: me.isGeneralManager ? null : me.hospital,
                          chooseHospital: me.isGeneralManager);
                      if (choice == null || !context.mounted) return;
                      await _hrRun(
                          context,
                          () => HrService.instance
                              .sendOffer(
                                  actor: me,
                                  seekerEmail: seeker.email,
                                  hospital: choice.hospital,
                                  joinAt: choice.joinAt,
                                  place: choice.place,
                                  message: choice.message)
                              .then((_) {}),
                          'Offer sent to ${seeker.fullName}.');
                    }
                  : null,
              icon: const Icon(Icons.work_outline_rounded, size: 18),
              label: const Text('Offer a job'),
            ),
            if (reason != null) ...[
              const SizedBox(height: 6),
              Text(reason,
                  style:
                      AppTextStyles.caption.copyWith(color: _muted(context))),
            ],
          ],
        ),
      ]),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.doctor, required this.me});
  final AppAccount doctor;
  final AppAccount me;

  @override
  Widget build(BuildContext context) {
    final isSelf = doctor.email == me.email;
    final service = HrService.instance;
    final canRelease =
        !isSelf && (me.isGeneralManager || !doctor.isDoctorManager);
    final name = ConnectService.displayName(doctor);
    return FdCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        ConnectAvatar(name: name, size: 46),
        const SizedBox(width: 12),
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
                const SizedBox(width: 8),
                _Tag(
                    doctor.typeLabel,
                    doctor.isDoctorManager
                        ? const Color(0xFF0D9488)
                        : context.fdColor(AppColors.primaryBlue)),
                if (isSelf) ...[
                  const SizedBox(width: 6),
                  _Tag('You', _muted(context)),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                [
                  if (doctor.specialty.isNotEmpty) doctor.specialty,
                  doctor.hospital,
                  if (doctor.hiredAt != null)
                    'Hired ${ConnectService.fullDate(doctor.hiredAt!)}',
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(color: _muted(context)),
              ),
            ],
          ),
        ),
        Wrap(spacing: 8, runSpacing: 6, children: [
          TextButton(
            onPressed: () => openDoctorProfile(context, doctor.email),
            child: const Text('Profile'),
          ),
          if (me.isGeneralManager && !isSelf)
            OutlinedButton(
              onPressed: () async {
                final grant = !doctor.isDoctorManager;
                final ok = await _confirmHr(context,
                    title: grant
                        ? 'Make $name a Doctor Manager?'
                        : 'Remove Doctor Manager permission?',
                    message: grant
                        ? '$name will be able to hire and manage doctors at '
                            '${doctor.hospital}.'
                        : '$name will be a Doctor at ${doctor.hospital} '
                            'without HR permission.',
                    action: grant ? 'Give permission' : 'Remove permission');
                if (!ok || !context.mounted) return;
                await _hrRun(
                    context,
                    () => service
                        .setDoctorManager(
                            actor: me, doctorEmail: doctor.email, grant: grant)
                        .then((_) {}),
                    grant
                        ? '$name is now a Doctor Manager.'
                        : '$name is now a Doctor.');
              },
              child: Text(doctor.isDoctorManager
                  ? 'Remove manager permission'
                  : 'Make Doctor Manager'),
            ),
          if (canRelease)
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: context.fdColor(AppColors.errorRed)),
              onPressed: () async {
                final ok = await _confirmHr(context,
                    title: 'End $name\'s work at ${doctor.hospital}?',
                    message: '$name becomes a New Doctor looking for work. '
                        'Their upcoming visits are cancelled and the users '
                        'are told.',
                    action: 'End employment',
                    destructive: true);
                if (!ok || !context.mounted) return;
                await _hrRun(
                    context,
                    () => service
                        .endEmployment(actor: me, doctorEmail: doctor.email)
                        .then((_) {}),
                    '$name no longer works at ${doctor.hospital}.');
              },
              child: const Text('End employment'),
            ),
        ]),
      ]),
    );
  }
}
