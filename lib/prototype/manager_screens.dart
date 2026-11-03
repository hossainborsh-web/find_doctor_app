import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/route_names.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_style.dart';
import '../core/theme/fd_palette.dart';
import '../core/widgets/fd_widgets.dart';
import '../services/account_service.dart';
import '../widgets/inventory/inventory_management_screen.dart';
import 'care_flow.dart';
import 'mock_data.dart';
import 'prototype_session.dart';

/// Doctor Manager inbox: approve or reject New Doctor / Doctor sign-ups.
/// Approving generates the password the doctor signs in with.
class DoctorApplicationsScreen extends StatefulWidget {
  const DoctorApplicationsScreen({super.key});

  @override
  State<DoctorApplicationsScreen> createState() =>
      _DoctorApplicationsScreenState();
}

class _DoctorApplicationsScreenState extends State<DoctorApplicationsScreen> {
  late Future<List<AppAccount>> _requests;

  AppAccount? get _manager => context.read<PrototypeSession>().account;

  @override
  void initState() {
    super.initState();
    _requests = _load();
    AccountService.instance.addListener(_reload);
  }

  @override
  void dispose() {
    AccountService.instance.removeListener(_reload);
    super.dispose();
  }

  Future<List<AppAccount>> _load() {
    final manager = _manager;
    if (manager == null) return Future.value(const <AppAccount>[]);
    return AccountService.instance.requestsFor(manager);
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _requests = _load());
  }

  Future<void> _approve(AppAccount request) async {
    final manager = _manager;
    if (manager == null) return;
    final password =
        await AccountService.instance.approve(request.id, manager: manager);
    if (!mounted) return;
    await _showPassword(request, password, approved: true);
  }

  Future<void> _issueNewPassword(AppAccount request) async {
    final manager = _manager;
    if (manager == null) return;
    final password = await AccountService.instance
        .issueNewPassword(request.id, manager: manager);
    if (!mounted) return;
    await _showPassword(request, password, approved: false);
  }

  Future<void> _reject(AppAccount request) async {
    final manager = _manager;
    if (manager == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this request?'),
        content: Text(
            '${request.fullName} (${request.typeLabel}) will not be able to sign in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AccountService.instance.reject(request.id, manager: manager);
  }

  Future<void> _showPassword(AppAccount request, String password,
      {required bool approved}) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.verified_rounded,
            color: AppColors.successGreen, size: 40),
        title: Text(approved ? 'Request approved' : 'New password issued'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send this password to ${request.fullName} '
                '(${request.email}). They can change it after signing in.'),
            const SizedBox(height: 14),
            _PasswordBox(password: password),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<PrototypeSession>().account;
    final scope = manager == null
        ? ''
        : manager.isDoctorManager
            ? 'You approve Doctors at ${manager.hospital.isEmpty ? 'your hospital' : manager.hospital}, and all New Doctors.'
            : 'You can review every doctor request.';

    return Scaffold(
      appBar: const FdAppBar(title: 'Doctor requests', showBack: true),
      body: FutureBuilder<List<AppAccount>>(
        future: _requests,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const FdLoadingState(label: 'Loading requests');
          }
          final requests = snapshot.data!;
          final pending = requests
              .where((request) => request.status == AccountStatus.pending)
              .toList();
          final reviewed = requests
              .where((request) => request.status != AccountStatus.pending)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (scope.isNotEmpty) FdPreviewNotice(message: scope),
              const SizedBox(height: 16),
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: FdEmptyState(
                    title: 'No requests yet',
                    message:
                        'When a New Doctor or Doctor signs up, their request appears here for you to approve.',
                    icon: Icons.how_to_reg_outlined,
                  ),
                ),
              if (pending.isNotEmpty) ...[
                FdSectionHeader(
                    title: 'Waiting for you',
                    action: '${pending.length} pending'),
                for (final request in pending)
                  _RequestCard(
                    request: request,
                    onApprove: () => _approve(request),
                    onReject: () => _reject(request),
                  ),
              ],
              if (reviewed.isNotEmpty) ...[
                const SizedBox(height: 8),
                const FdSectionHeader(title: 'Reviewed'),
                for (final request in reviewed)
                  _RequestCard(
                    request: request,
                    onIssuePassword: request.status == AccountStatus.active
                        ? () => _issueNewPassword(request)
                        : null,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.onApprove,
    this.onReject,
    this.onIssuePassword,
  });

  final AppAccount request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onIssuePassword;

  static String _date(DateTime? value) {
    if (value == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = switch (request.status) {
      AccountStatus.pending => ('Pending', FdStatusTone.warning),
      AccountStatus.active => ('Approved', FdStatusTone.success),
      AccountStatus.rejected => ('Rejected', FdStatusTone.danger),
    };
    final initials = request.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    Widget info(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: context.fdColor(AppColors.darkGrey)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: AppTextStyles.caption)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FdAvatar(initials: initials.isEmpty ? '?' : initials, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.fullName,
                          style: AppTextStyles.bodyText1
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(request.typeLabel,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                FdStatusChip(label: statusLabel, tone: tone),
              ],
            ),
            const SizedBox(height: 6),
            info(Icons.mail_outline_rounded, request.email),
            info(
                Icons.local_hospital_outlined,
                request.hospital.isEmpty
                    ? 'No hospital yet (New Doctor)'
                    : request.hospital),
            if (request.specialty.isNotEmpty)
              info(Icons.medical_services_outlined, request.specialty),
            if (request.birthday.isNotEmpty)
              info(Icons.cake_outlined, 'Born ${request.birthday}'),
            info(Icons.attach_file_rounded,
                request.documentName ?? 'No document uploaded'),
            info(Icons.schedule_rounded, 'Sent ${_date(request.createdAt)}'),
            if (request.reviewedBy != null)
              info(Icons.person_outline_rounded,
                  '${statusLabel} by ${request.reviewedBy} · ${_date(request.reviewedAt)}'),
            if (request.status == AccountStatus.active) ...[
              const SizedBox(height: 12),
              if (request.temporaryPassword != null) ...[
                Text('Password to send to the doctor',
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _PasswordBox(password: request.temporaryPassword!),
              ] else
                Text('The doctor has set their own password.',
                    style: AppTextStyles.caption),
            ],
            if (onApprove != null || onReject != null || onIssuePassword != null)
              const SizedBox(height: 14),
            if (onApprove != null || onReject != null)
              Row(
                children: [
                  if (onReject != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed),
                      ),
                    ),
                  if (onReject != null && onApprove != null)
                    const SizedBox(width: 10),
                  if (onApprove != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve & send password'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                ],
              ),
            if (onIssuePassword != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onIssuePassword,
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('Issue a new password'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PasswordBox extends StatelessWidget {
  const _PasswordBox({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: context.fdColor(AppColors.surfaceMuted),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fdColor(AppColors.lightBlue)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              password,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: context.fdColor(AppColors.primaryBlueDark),
                fontFamily: 'Consolas',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy password',
            icon: const Icon(Icons.copy_rounded, color: AppColors.primaryBlue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: password));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Dashboard card showing how many doctor requests wait for this manager.
class DoctorRequestsSummaryCard extends StatefulWidget {
  const DoctorRequestsSummaryCard({super.key});

  @override
  State<DoctorRequestsSummaryCard> createState() =>
      _DoctorRequestsSummaryCardState();
}

class _DoctorRequestsSummaryCardState extends State<DoctorRequestsSummaryCard> {
  int? _pending;

  @override
  void initState() {
    super.initState();
    AccountService.instance.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    AccountService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final manager = context.read<PrototypeSession>().account;
    final count = manager == null
        ? 0
        : await AccountService.instance.pendingCountFor(manager);
    if (mounted) setState(() => _pending = count);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending ?? 0;
    return FdCard(
      onTap: () => Navigator.pushNamed(context, RouteNames.doctorApplications),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.how_to_reg_outlined,
                color: AppColors.warningOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending == 1 ? '1 doctor request' : '$pending doctor requests',
                  style: AppTextStyles.bodyText1.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.fdColor(AppColors.primaryBlueDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                    pending > 0
                        ? 'Waiting for your approval'
                        : 'Open to see approved and rejected requests',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          FdStatusChip(
            label: pending > 0 ? 'Pending' : 'Up to date',
            tone: pending > 0 ? FdStatusTone.warning : FdStatusTone.success,
          ),
        ],
      ),
    );
  }
}

class ApplicationReviewScreen extends StatelessWidget {
  const ApplicationReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final application =
        ModalRoute.of(context)?.settings.arguments as MockApplication? ??
            MockData.applications.first;
    final session = context.watch<PrototypeSession>();
    final applicationStatus = session.applicationApproved(application.id)
        ? 'Approved'
        : session.applicationRejected(application.id)
            ? 'Rejected'
            : application.status;
    return Scaffold(
      appBar: const FdAppBar(title: 'Application review', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const FdPreviewNotice(
              message: 'Preview workspace · sample application records'),
          const SizedBox(height: 16),
          FdCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(application.doctorName, style: AppTextStyles.subtitle1),
              const SizedBox(height: 6),
              Text('${application.specialty} · ${application.hospital}',
                  style: AppTextStyles.secondary),
              const SizedBox(height: 12),
              FdStatusChip(
                label: applicationStatus,
                tone: applicationStatus == 'Approved'
                    ? FdStatusTone.success
                    : applicationStatus == 'Rejected'
                        ? FdStatusTone.danger
                        : FdStatusTone.warning,
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const FdSectionHeader(title: 'Identity information'),
          const FdCard(
              child: Column(children: [
            _ReviewRow('Birthday', '12 Mar 1987'),
            Divider(),
            _ReviewRow('Hospital', 'Pantai Hospital Kuala Lumpur · Private'),
            Divider(),
            _ReviewRow('Specialty', 'Medical registration details supplied'),
          ])),
          const SizedBox(height: 16),
          const FdSectionHeader(title: 'Documents'),
          const FdCard(
              child: Column(children: [
            _DocumentRow(
                'Graduation certificate', 'Medical_degree_certified.pdf'),
          ])),
          const SizedBox(height: 24),
          FdButton(
            label: 'Approve doctor',
            icon: Icons.check_circle_outline,
            onPressed: () {
              Navigator.pushNamed(context, RouteNames.approveConfirm,
                  arguments: application);
            },
          ),
          const SizedBox(height: 12),
          FdButton(
            label: 'Reject application',
            outlined: true,
            destructive: true,
            onPressed: () => Navigator.pushNamed(
                context, RouteNames.rejectReason,
                arguments: application),
          ),
        ],
      ),
    );
  }
}

class RejectReasonScreen extends StatefulWidget {
  const RejectReasonScreen({super.key});

  @override
  State<RejectReasonScreen> createState() => _RejectReasonScreenState();
}

class _RejectReasonScreenState extends State<RejectReasonScreen> {
  String selectedReason = 'Certificate is not certified';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FdAppBar(title: 'Reject application', showBack: true),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const FdPreviewNotice(
              message: 'No rejection notice will be sent from this preview.'),
          const SizedBox(height: 16),
          Text('Select a reason', style: AppTextStyles.headline2),
          const SizedBox(height: 8),
          Text('Choose a sample reason. Nothing will be sent to an applicant.',
              style: AppTextStyles.secondary),
          const SizedBox(height: 16),
          for (final reason in const [
            'Certificate is not certified',
            'Identity document is unclear',
            'Hospital details could not be confirmed',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceChip(
                label: Text(reason),
                selected: selectedReason == reason,
                onSelected: (_) => setState(() => selectedReason = reason),
              ),
            ),
          const SizedBox(height: 12),
          const FdTextField(label: 'Additional detail', maxLines: 4),
          const SizedBox(height: 24),
          FdButton(
            label: 'Send rejection',
            destructive: true,
            onPressed: () {
              final application = ModalRoute.of(context)?.settings.arguments
                  as MockApplication?;
              if (application != null) {
                context
                    .read<PrototypeSession>()
                    .rejectApplication(application.id);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Sample application marked rejected for this preview session only: $selectedReason')),
              );
              Navigator.popUntil(
                  context, ModalRoute.withName(RouteNames.doctorApplications));
            },
          ),
        ]),
      );
}

class DoctorManagementScreen extends StatelessWidget {
  const DoctorManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FdAppBar(title: 'Doctor management', showBack: true),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const FdTextField(
                  label: 'Search doctors',
                  hint: 'Name, specialty, or hospital'),
              const SizedBox(height: 16),
              for (final doctor in MockData.doctors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FdCard(
                    child: Row(children: [
                      FdAvatar(initials: doctor.initials, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(doctor.name,
                                style: AppTextStyles.bodyText2
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text('${doctor.specialty} · ${doctor.hospital}',
                                style: AppTextStyles.caption),
                          ])),
                      IconButton(
                        tooltip: 'Manage schedule',
                        icon: const Icon(Icons.calendar_month_outlined),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          RouteNames.manageSchedule,
                          arguments: doctor,
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
      );
}

class HospitalAnalyticsScreen extends StatelessWidget {
  const HospitalAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FdAppBar(title: 'Hospital analytics', showBack: true),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const FdPreviewNotice(
              message:
                  'Preview workspace · sample analytics, not live hospital data'),
          const SizedBox(height: 16),
          const _LiveBookingSummary(),
          const SizedBox(height: 20),
          const FdSectionHeader(title: 'October overview'),
          const Wrap(spacing: 12, runSpacing: 12, children: [
            _MetricCard(value: '1,248', label: 'Consultations'),
            _MetricCard(value: '86%', label: 'Schedule utilisation'),
            _MetricCard(value: 'RM 182k', label: 'Consultation revenue'),
            _MetricCard(value: '4.8', label: 'Average rating'),
          ]),
          const SizedBox(height: 20),
          const FdSectionHeader(title: 'Service activity'),
          const FdCard(
              child: Column(children: [
            _BarRow(label: 'Cardiology', value: '82%'),
            _BarRow(label: 'Orthopaedics', value: '74%'),
            _BarRow(label: 'Paediatrics', value: '91%'),
            _BarRow(label: 'Physiotherapy', value: '66%'),
          ])),
          const SizedBox(height: 16),
          Text('Reporting period: 1–31 October 2026',
              style: AppTextStyles.caption),
        ]),
      );
}

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) => const InventoryManagementScreen(
        title: 'Equipment inventory',
        category: 'Equipment',
      );
}

class MedicationInventoryScreen extends StatelessWidget {
  const MedicationInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const InventoryManagementScreen(
        title: 'Medication inventory',
        category: 'Medication',
      );
}

class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FdAppBar(title: 'Meetings', showBack: true),
        body: ListView(padding: const EdgeInsets.all(20), children: const [
          FdSectionHeader(title: 'Upcoming'),
          _ScheduleCard(
              title: 'Clinical governance review',
              subtitle: 'Today · 14:00 · Boardroom A',
              icon: Icons.groups_outlined),
          _ScheduleCard(
              title: 'Doctor manager briefing',
              subtitle: 'Tomorrow · 09:30 · Meeting room 3',
              icon: Icons.medical_services_outlined),
          _ScheduleCard(
              title: 'Monthly operations meeting',
              subtitle: 'Friday · 11:00 · Virtual',
              icon: Icons.video_call_outlined),
        ]),
      );
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FdAppBar(title: 'Hospital alerts', showBack: true),
        body: ListView(padding: const EdgeInsets.all(20), children: const [
          FdPreviewNotice(
              message: 'Preview workspace · sample operational alerts'),
          SizedBox(height: 16),
          _AlertCard(
              title: 'Medication stock below threshold',
              detail: 'Salbutamol inhaler · 42 units remaining · Pharmacy',
              tone: FdStatusTone.warning),
          _AlertCard(
              title: 'Equipment maintenance due',
              detail: 'Infusion pump IP-204 · Ward 7',
              tone: FdStatusTone.warning),
          _AlertCard(
              title: 'Doctor application awaiting review',
              detail: 'Dr. Hana Yusof · Dermatology · Submitted 2 Oct',
              tone: FdStatusTone.neutral),
          _AlertCard(
              title: 'Operating theatre schedule updated',
              detail: 'OT 3 · Friday 11:00 · Orthopaedics',
              tone: FdStatusTone.success),
        ]),
      );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
              width: 110, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.bodyText2)),
        ]),
      );
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow(this.label, this.file);
  final String label;
  final String file;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Icon(Icons.description_outlined, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: AppTextStyles.bodyText2
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(file, style: AppTextStyles.caption),
              ])),
          IconButton(
              tooltip: 'View document',
              onPressed: () => _showNotice(context, 'Document preview'),
              icon: const Icon(Icons.visibility_outlined)),
        ]),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 52) / 2,
        child: FdCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: AppTextStyles.headline2
                  .copyWith(
                  fontSize: 22,
                  color: context.fdColor(AppColors.primaryBlueDark))),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ])),
      );
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyText2)),
          SizedBox(
              width: 110,
              child: LinearProgressIndicator(
                  value: int.parse(value.replaceAll('%', '')) / 100)),
          const SizedBox(width: 10),
          SizedBox(width: 36, child: Text(value, style: AppTextStyles.caption)),
        ]),
      );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard(
      {required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FdCard(
            child: Row(children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: AppTextStyles.bodyText2
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTextStyles.caption),
              ])),
          Icon(Icons.chevron_right,
              color: context.fdColor(AppColors.darkGrey)),
        ])),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard(
      {required this.title, required this.detail, required this.tone});
  final String title;
  final String detail;
  final FdStatusTone tone;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FdCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: AppTextStyles.bodyText2
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(detail, style: AppTextStyles.caption),
          const SizedBox(height: 8),
          FdStatusChip(
              label: switch (tone) {
                FdStatusTone.warning => 'Action required',
                FdStatusTone.success => 'Resolved',
                FdStatusTone.danger => 'Critical',
                _ => 'Information'
              },
              tone: tone),
        ])),
      );
}

void _showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Counts computed from the booking data in the app (not fixed numbers),
/// with the time they were calculated so stale figures are obvious.
class _LiveBookingSummary extends StatelessWidget {
  const _LiveBookingSummary();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    int count(AppointmentStatus s) =>
        store.appointments.where((a) => a.status == s).length;
    final pendingConsults = store.consultations
        .where((c) => c.status == ConsultationStatus.pending)
        .length;
    final unpaid =
        store.invoices.where((i) => i.status == InvoiceStatus.unpaid).length;
    final rows = <(String, int)>[
      ('Pending appointments', count(AppointmentStatus.pending)),
      ('Confirmed appointments', count(AppointmentStatus.confirmed)),
      ('Completed', count(AppointmentStatus.completed)),
      ('Cancelled / rejected',
          count(AppointmentStatus.cancelled) + count(AppointmentStatus.rejected)),
      ('No-shows', count(AppointmentStatus.noShow)),
      ('Consultation requests waiting', pendingConsults),
      ('Unpaid invoices', unpaid),
    ];
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FdSectionHeader(title: 'Bookings right now'),
        FdCard(
          child: Column(children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(child: Text(label, style: AppTextStyles.bodyText2)),
                  Text('$value',
                      style: AppTextStyles.bodyText1
                          .copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text('Last updated ${formatTime(now)}, ${formatDate(now)}. Offline: figures are read-only and may be out of date.',
            style: AppTextStyles.caption),
      ],
    );
  }
}
