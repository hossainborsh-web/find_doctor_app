import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/route_names.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_style.dart';
import '../core/theme/fd_palette.dart';
import '../core/widgets/fd_widgets.dart';
import 'content_widgets.dart';
import 'mock_data.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// Appointment lifecycle from the spec: Pending → Confirmed → Completed,
/// plus Cancelled, Rejected and No-show.
enum AppointmentStatus {
  pending('Pending', FdStatusTone.warning),
  confirmed('Confirmed', FdStatusTone.success),
  completed('Completed', FdStatusTone.neutral),
  cancelled('Cancelled', FdStatusTone.danger),
  rejected('Rejected', FdStatusTone.danger),
  noShow('No-show', FdStatusTone.danger);

  const AppointmentStatus(this.label, this.tone);
  final String label;
  final FdStatusTone tone;

  /// Statuses that still hold the time slot.
  bool get holdsSlot => this == pending || this == confirmed;
}

/// A consultation request is not an appointment: accepting it opens the
/// medical conversation, it does not book a visit.
enum ConsultationStatus {
  pending('Awaiting doctor', FdStatusTone.warning),
  accepted('Accepted', FdStatusTone.success),
  rejected('Declined', FdStatusTone.danger),
  completed('Completed', FdStatusTone.neutral),
  cancelled('Cancelled', FdStatusTone.danger);

  const ConsultationStatus(this.label, this.tone);
  final String label;
  final FdStatusTone tone;
}

enum VisitMode {
  inPerson('In person', Icons.local_hospital_outlined),
  video('Video consultation', Icons.videocam_outlined);

  const VisitMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Creating an invoice never means it has been paid.
enum InvoiceStatus {
  unpaid('Unpaid', FdStatusTone.warning),
  paid('Paid', FdStatusTone.success),
  cancelled('Cancelled', FdStatusTone.neutral);

  const InvoiceStatus(this.label, this.tone);
  final String label;
  final FdStatusTone tone;
}

class CareAppointment {
  CareAppointment({
    required this.id,
    required this.doctor,
    required this.patientName,
    required this.start,
    required this.mode,
    required this.status,
    this.reason = '',
  });

  final String id;
  final MockDoctor doctor;
  final String patientName;
  DateTime start;
  final VisitMode mode;
  AppointmentStatus status;
  final String reason;

  bool get isUpcoming => status.holdsSlot && start.isAfter(DateTime.now());
}

class ConsultationRequest {
  ConsultationRequest({
    required this.id,
    required this.doctor,
    required this.patientName,
    required this.subject,
    required this.description,
    required this.sentAt,
    this.status = ConsultationStatus.pending,
  });

  final String id;
  final MockDoctor doctor;
  final String patientName;
  final String subject;
  final String description;
  final DateTime sentAt;
  ConsultationStatus status;
}

class Invoice {
  Invoice({
    required this.number,
    required this.appointmentId,
    required this.service,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.issued,
    this.status = InvoiceStatus.unpaid,
  });

  final String number;
  final String appointmentId;
  final String service;
  final String provider;
  final int amount;
  final String currency;
  final DateTime issued;
  InvoiceStatus status;

  DateTime get due => issued.add(const Duration(days: 7));
}

// ---------------------------------------------------------------------------
// Store (sample data held in memory until the ASP.NET API is connected)
// ---------------------------------------------------------------------------

class CareStore extends ChangeNotifier {
  CareStore() {
    final now = DateTime.now();
    DateTime at(int days, int hour, [int minute = 0]) {
      final d = DateTime(now.year, now.month, now.day).add(Duration(days: days));
      return DateTime(d.year, d.month, d.day, hour, minute);
    }

    final doctors = MockData.doctors;
    final patients = MockData.patients;
    appointments.addAll([
      CareAppointment(
          id: 'a1',
          doctor: doctors[0],
          patientName: patients[0].name,
          start: _nextWeekday(at(1, 10)),
          mode: VisitMode.inPerson,
          status: AppointmentStatus.confirmed,
          reason: 'Blood pressure follow-up'),
      CareAppointment(
          id: 'a2',
          doctor: doctors[1],
          patientName: patients[0].name,
          start: _nextWeekday(at(4, 14, 30)),
          mode: VisitMode.video,
          status: AppointmentStatus.pending,
          reason: 'Knee pain after running'),
      CareAppointment(
          id: 'a3',
          doctor: doctors[2],
          patientName: patients[0].name,
          start: at(-40, 11),
          mode: VisitMode.inPerson,
          status: AppointmentStatus.completed,
          reason: 'Child vaccination'),
      CareAppointment(
          id: 'a4',
          doctor: doctors[3],
          patientName: patients[0].name,
          start: at(-12, 9),
          mode: VisitMode.inPerson,
          status: AppointmentStatus.cancelled,
          reason: 'Physiotherapy assessment'),
      CareAppointment(
          id: 'a5',
          doctor: doctors[0],
          patientName: patients[1].name,
          start: _nextWeekday(at(2, 9)),
          mode: VisitMode.inPerson,
          status: AppointmentStatus.pending,
          reason: 'Chest tightness when climbing stairs'),
      CareAppointment(
          id: 'a6',
          doctor: doctors[0],
          patientName: patients[2].name,
          start: _nextWeekday(at(1, 14)),
          mode: VisitMode.video,
          status: AppointmentStatus.confirmed,
          reason: 'Review of ECG results'),
    ]);
    consultations.addAll([
      ConsultationRequest(
          id: 'c1',
          doctor: doctors[0],
          patientName: patients[0].name,
          subject: 'Home blood pressure readings',
          description:
              'My readings are around 145/95 in the morning. Should I change my medication timing?',
          sentAt: now.subtract(const Duration(days: 2)),
          status: ConsultationStatus.accepted),
      ConsultationRequest(
          id: 'c2',
          doctor: doctors[2],
          patientName: patients[0].name,
          subject: 'Rash after vaccination',
          description: 'Small red rash on the arm since yesterday, no fever.',
          sentAt: now.subtract(const Duration(hours: 5))),
      ConsultationRequest(
          id: 'c3',
          doctor: doctors[0],
          patientName: patients[1].name,
          subject: 'Palpitations at night',
          description:
              'Heart racing for a few minutes before sleep, 3 times this week.',
          sentAt: now.subtract(const Duration(hours: 3))),
    ]);
    for (final a in appointments) {
      if (a.status != AppointmentStatus.cancelled &&
          a.status != AppointmentStatus.rejected) {
        _issueInvoice(a);
      }
    }
    invoices.firstWhere((i) => i.appointmentId == 'a3').status =
        InvoiceStatus.paid;
  }

  final List<CareAppointment> appointments = [];
  final List<ConsultationRequest> consultations = [];
  final List<Invoice> invoices = [];
  int _seq = 100;

  static const slotTimes = [(9, 0), (10, 30), (14, 0), (15, 30)];

  /// The billing currency follows the market the hospital operates in.
  static String currencyFor(MockDoctor doctor) {
    const sudanCities = ['Khartoum', 'Omdurman', 'Port Sudan'];
    return sudanCities.any(doctor.hospital.contains) ? 'SDG' : 'MYR';
  }

  static DateTime _nextWeekday(DateTime d) {
    var day = d;
    while (day.weekday >= DateTime.saturday) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  /// The next [count] working days, starting tomorrow.
  static List<DateTime> bookableDays([int count = 6]) {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[];
    while (days.length < count) {
      day = day.add(const Duration(days: 1));
      if (day.weekday < DateTime.saturday) days.add(day);
    }
    return days;
  }

  List<DateTime> slotsFor(DateTime day) => [
        for (final (h, m) in slotTimes) DateTime(day.year, day.month, day.day, h, m)
      ];

  /// Double-booking guard. The real check must also run on the server.
  bool isSlotTaken(MockDoctor doctor, DateTime start, {String? ignoreId}) =>
      appointments.any((a) =>
          a.id != ignoreId &&
          a.doctor.id == doctor.id &&
          a.status.holdsSlot &&
          a.start == start);

  List<CareAppointment> forPatient(String name) =>
      appointments.where((a) => a.patientName == name).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  List<CareAppointment> forDoctor(MockDoctor doctor) =>
      appointments.where((a) => a.doctor.id == doctor.id).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  Invoice? invoiceFor(String appointmentId) {
    for (final invoice in invoices) {
      if (invoice.appointmentId == appointmentId) return invoice;
    }
    return null;
  }

  ConsultationRequest requestConsultation({
    required MockDoctor doctor,
    required String patientName,
    required String subject,
    required String description,
  }) {
    final request = ConsultationRequest(
      id: 'c${_seq++}',
      doctor: doctor,
      patientName: patientName,
      subject: subject.trim(),
      description: description.trim(),
      sentAt: DateTime.now(),
    );
    consultations.insert(0, request);
    notifyListeners();
    return request;
  }

  void respondToConsultation(ConsultationRequest request, bool accept) {
    request.status =
        accept ? ConsultationStatus.accepted : ConsultationStatus.rejected;
    notifyListeners();
  }

  /// Returns null when the slot was taken in the meantime.
  CareAppointment? book({
    required MockDoctor doctor,
    required String patientName,
    required DateTime start,
    required VisitMode mode,
    String reason = '',
  }) {
    if (isSlotTaken(doctor, start)) return null;
    final appointment = CareAppointment(
      id: 'a${_seq++}',
      doctor: doctor,
      patientName: patientName,
      start: start,
      mode: mode,
      status: AppointmentStatus.pending,
      reason: reason.trim(),
    );
    appointments.add(appointment);
    _issueInvoice(appointment);
    notifyListeners();
    return appointment;
  }

  /// Moves an appointment to a new slot; it goes back to Pending so the
  /// doctor can confirm the new time. Returns false if the slot is taken.
  bool reschedule(CareAppointment appointment, DateTime start) {
    if (isSlotTaken(appointment.doctor, start, ignoreId: appointment.id)) {
      return false;
    }
    appointment
      ..start = start
      ..status = AppointmentStatus.pending;
    notifyListeners();
    return true;
  }

  void setStatus(CareAppointment appointment, AppointmentStatus status) {
    appointment.status = status;
    if (status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.rejected) {
      final invoice = invoiceFor(appointment.id);
      if (invoice != null && invoice.status == InvoiceStatus.unpaid) {
        invoice.status = InvoiceStatus.cancelled;
      }
    }
    notifyListeners();
  }

  void _issueInvoice(CareAppointment a) {
    invoices.add(Invoice(
      number: 'INV-${DateTime.now().year}-${(1000 + invoices.length + 1)}',
      appointmentId: a.id,
      service: '${a.mode.label} · ${a.doctor.specialty}',
      provider: '${a.doctor.name}, ${a.doctor.hospital}',
      amount: a.doctor.priceRm,
      currency: currencyFor(a.doctor),
      issued: a.start.isBefore(DateTime.now()) ? a.start : DateTime.now(),
    ));
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers (no intl dependency)
// ---------------------------------------------------------------------------

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String formatDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

String formatTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

String formatMoney(int amount, String currency) => '$currency $amount';

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

/// The prototype signs in sample patients; the first one is "me".
String currentPatientName() => MockData.patients.first.name;

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: AppTextStyles.caption)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.end,
                style: AppTextStyles.bodyText2
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

Future<bool> _confirm(BuildContext context,
    {required String title,
    required String message,
    required String action}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep')),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

/// Shown wherever a patient writes to a doctor.
class EmergencyNotice extends StatelessWidget {
  const EmergencyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5D3A1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.emergency_outlined,
              size: 18, color: AppColors.warningOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Not for emergencies. If you have severe symptoms, call 999 (Malaysia) or go to the nearest emergency department.',
              style: AppTextStyles.caption
                  .copyWith(color: const Color(0xFF7A4B0B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Patient: appointments & consultation requests
// ---------------------------------------------------------------------------

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final mine = store.forPatient(currentPatientName());
    final upcoming = mine.where((a) => a.isUpcoming).toList();
    final past = mine.where((a) => !a.isUpcoming).toList().reversed.toList();
    final requests = store.consultations
        .where((c) => c.patientName == currentPatientName())
        .toList();
    final initialTab =
        ModalRoute.of(context)?.settings.arguments == 'consultations' ? 2 : 0;

    Widget list(List<CareAppointment> items, String empty) => items.isEmpty
        ? FdEmptyState(
            title: empty,
            message: 'Find a doctor to request a consultation or book a visit.',
            icon: Icons.event_busy_outlined,
            actionLabel: 'Find a doctor',
            onAction: () => Navigator.pushNamed(context, RouteNames.search),
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final a = items[i];
              return AppointmentCard(
                doctor: a.doctor,
                date: formatDate(a.start),
                time: formatTime(a.start),
                status: a.status.label,
                type: a.mode.label,
                onTap: () => Navigator.pushNamed(
                    context, RouteNames.appointmentDetails,
                    arguments: a),
              );
            },
          );

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          bottom: TabBar(tabs: [
            Tab(text: 'Upcoming (${upcoming.length})'),
            const Tab(text: 'Past'),
            Tab(text: 'Requests (${requests.length})'),
          ]),
        ),
        body: TabBarView(children: [
          list(upcoming, 'No upcoming appointments'),
          list(past, 'No past appointments'),
          requests.isEmpty
              ? const FdEmptyState(
                  title: 'No consultation requests',
                  message:
                      'Open a doctor profile and choose Request consultation.',
                  icon: Icons.forum_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _ConsultationCard(request: requests[i]),
                ),
        ]),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.request, this.forDoctor = false});

  final ConsultationRequest request;
  final bool forDoctor;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CareStore>();
    final title = forDoctor ? request.patientName : request.doctor.name;
    return FdCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyText1
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(
                      forDoctor
                          ? 'Sent ${_ago(request.sentAt)}'
                          : '${request.doctor.specialty} · sent ${_ago(request.sentAt)}',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            FdStatusChip(label: request.status.label, tone: request.status.tone),
          ]),
          const SizedBox(height: 12),
          Text(request.subject,
              style:
                  AppTextStyles.bodyText2.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(request.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.secondary),
          if (forDoctor && request.status == ConsultationStatus.pending) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FdButton(
                  label: 'Decline',
                  outlined: true,
                  onPressed: () async {
                    if (await _confirm(context,
                        title: 'Decline request?',
                        message:
                            '${request.patientName} will be told you cannot take this consultation.',
                        action: 'Decline')) {
                      store.respondToConsultation(request, false);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FdButton(
                  label: 'Accept',
                  onPressed: () {
                    store.respondToConsultation(request, true);
                    _snack(context,
                        'Accepted. The conversation with ${request.patientName} is now open.');
                  },
                ),
              ),
            ]),
          ],
          if (request.status == ConsultationStatus.accepted) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FdButton(
                  label: 'Open chat',
                  icon: Icons.chat_bubble_outline,
                  outlined: !forDoctor,
                  onPressed: () => Navigator.pushNamed(
                      context, RouteNames.chatThread,
                      arguments: MockData.chats.first),
                ),
              ),
              if (!forDoctor) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FdButton(
                    label: 'Book visit',
                    onPressed: () => Navigator.pushNamed(
                        context, RouteNames.bookAppointment,
                        arguments: request.doctor),
                  ),
                ),
              ],
            ]),
          ],
          if (!forDoctor && request.status == ConsultationStatus.pending) ...[
            const SizedBox(height: 10),
            Text(
                'The chat opens once the doctor accepts. Accepting a consultation does not book an appointment.',
                style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

class AppointmentDetailsScreen extends StatelessWidget {
  const AppointmentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final a = ModalRoute.of(context)?.settings.arguments as CareAppointment? ??
        store.forPatient(currentPatientName()).first;
    final invoice = store.invoiceFor(a.id);
    final canChange = a.isUpcoming;

    return Scaffold(
      appBar: const FdAppBar(title: 'Appointment details', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FdCard(
              child: Column(children: [
            DoctorAvatar(doctor: a.doctor, size: 68),
            const SizedBox(height: 12),
            Text(a.doctor.name, style: AppTextStyles.subtitle2),
            Text(a.doctor.specialty, style: AppTextStyles.secondary),
            const SizedBox(height: 12),
            FdStatusChip(label: a.status.label, tone: a.status.tone),
            if (a.status == AppointmentStatus.pending) ...[
              const SizedBox(height: 8),
              Text('Waiting for the doctor to confirm this time.',
                  textAlign: TextAlign.center, style: AppTextStyles.caption),
            ],
          ])),
          const SizedBox(height: 16),
          FdCard(
              child: Column(children: [
            _kv('Date', formatDate(a.start)),
            const Divider(),
            _kv('Time', formatTime(a.start)),
            const Divider(),
            _kv('Type', a.mode.label),
            const Divider(),
            _kv(a.mode == VisitMode.video ? 'Join from' : 'Location',
                a.mode == VisitMode.video
                    ? 'Video link is shared after confirmation'
                    : a.doctor.hospital),
            if (a.reason.isNotEmpty) ...[
              const Divider(),
              _kv('Reason', a.reason),
            ],
            const Divider(),
            _kv('Consultation fee',
                formatMoney(a.doctor.priceRm, CareStore.currencyFor(a.doctor))),
          ])),
          if (invoice != null) ...[
            const SizedBox(height: 12),
            FdCard(
              onTap: () => Navigator.pushNamed(context, RouteNames.receipt,
                  arguments: invoice),
              child: Row(children: [
                Icon(Icons.receipt_long_outlined,
                    color: context.fdColor(AppColors.primaryBlue)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Invoice ${invoice.number}',
                        style: AppTextStyles.bodyText2
                            .copyWith(fontWeight: FontWeight.w600))),
                FdStatusChip(label: invoice.status.label, tone: invoice.status.tone),
              ]),
            ),
          ],
          if (canChange) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.notifications_active_outlined,
                  size: 16, color: context.fdColor(AppColors.darkGrey)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('You will get a reminder 24 hours before the visit.',
                    style: AppTextStyles.caption),
              ),
            ]),
          ],
          const SizedBox(height: 20),
          FdButton(
              label: 'Message doctor',
              icon: Icons.chat_bubble_outline,
              onPressed: () => Navigator.pushNamed(
                  context, RouteNames.chatThread,
                  arguments: MockData.chats.first)),
          if (canChange) ...[
            const SizedBox(height: 10),
            FdButton(
                label: 'Reschedule',
                outlined: true,
                onPressed: () => Navigator.pushNamed(
                    context, RouteNames.bookAppointment,
                    arguments: a)),
            const SizedBox(height: 10),
            FdButton(
              label: 'Cancel appointment',
              outlined: true,
              destructive: true,
              onPressed: () async {
                if (await _confirm(context,
                    title: 'Cancel appointment?',
                    message:
                        'Your ${formatTime(a.start)} visit on ${formatDate(a.start)} with ${a.doctor.name} will be cancelled and the slot released.',
                    action: 'Cancel appointment')) {
                  store.setStatus(a, AppointmentStatus.cancelled);
                  if (context.mounted) _snack(context, 'Appointment cancelled.');
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class RequestConsultationScreen extends StatefulWidget {
  const RequestConsultationScreen({super.key});

  @override
  State<RequestConsultationScreen> createState() =>
      _RequestConsultationScreenState();
}

class _RequestConsultationScreenState extends State<RequestConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = ModalRoute.of(context)?.settings.arguments as MockDoctor? ??
        MockData.doctors.first;
    return Scaffold(
      appBar: const FdAppBar(title: 'Request consultation', showBack: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            FdPersonTile(
                name: doctor.name,
                subtitle:
                    '${doctor.specialty} · ${formatMoney(doctor.priceRm, CareStore.currencyFor(doctor))}',
                initials: doctor.initials,
                rating: doctor.rating,
                available: doctor.available),
            const SizedBox(height: 16),
            const EmergencyNotice(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(
                  labelText: 'Subject', hintText: 'e.g. Recurring headaches'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Add a short subject.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 5,
              decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                  hintText:
                      'When it started, symptoms, medicines you take…',
                  alignLabelWithHint: true),
              validator: (v) => (v ?? '').trim().length < 15
                  ? 'Please describe the problem in a bit more detail.'
                  : null,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Attach photos or reports (coming soon)'),
            ),
            const SizedBox(height: 14),
            Text(
              'The doctor reviews your request first. If accepted, a private chat opens. Booking a visit is a separate step.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            FdButton(
              label: 'Send request',
              icon: Icons.send_rounded,
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                context.read<CareStore>().requestConsultation(
                      doctor: doctor,
                      patientName: currentPatientName(),
                      subject: _subject.text,
                      description: _description.text,
                    );
                Navigator.pushReplacementNamed(
                    context, RouteNames.appointments,
                    arguments: 'consultations');
                _snack(context, 'Request sent to ${doctor.name}.');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _days = CareStore.bookableDays();
  late DateTime _day = _days.first;
  DateTime? _slot;
  VisitMode _mode = VisitMode.inPerson;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final arg = ModalRoute.of(context)?.settings.arguments;
    final existing = arg is CareAppointment ? arg : null;
    final doctor = existing?.doctor ??
        (arg is MockDoctor ? arg : MockData.doctors.first);
    final currency = CareStore.currencyFor(doctor);

    return Scaffold(
      appBar: FdAppBar(
          title: existing == null ? 'Book appointment' : 'Reschedule',
          showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FdPersonTile(
              name: doctor.name,
              subtitle: doctor.hospital,
              initials: doctor.initials,
              rating: doctor.rating,
              available: doctor.available),
          if (existing == null) ...[
            const SizedBox(height: 18),
            Text('Visit type', style: AppTextStyles.subtitle2),
            const SizedBox(height: 8),
            SegmentedButton<VisitMode>(
              segments: [
                for (final m in VisitMode.values)
                  ButtonSegment(value: m, label: Text(m.label), icon: Icon(m.icon)),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
          ],
          const SizedBox(height: 18),
          Text('Day', style: AppTextStyles.subtitle2),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = _days[i];
                final selected = d == _day;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _day = d;
                    _slot = null;
                  }),
                  label: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_weekdays[d.weekday - 1],
                        style: AppTextStyles.caption),
                    Text('${d.day} ${_months[d.month - 1]}',
                        style: AppTextStyles.bodyText2
                            .copyWith(fontWeight: FontWeight.w700)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Text('Available times', style: AppTextStyles.subtitle2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in store.slotsFor(_day))
                Builder(builder: (context) {
                  final taken =
                      store.isSlotTaken(doctor, s, ignoreId: existing?.id);
                  return ChoiceChip(
                    label: Text(taken
                        ? '${formatTime(s)} · Booked'
                        : formatTime(s)),
                    selected: _slot == s,
                    onSelected: taken ? null : (_) => setState(() => _slot = s),
                  );
                }),
            ],
          ),
          if (existing == null) ...[
            const SizedBox(height: 18),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                  labelText: 'Reason for visit (optional)'),
            ),
          ],
          const SizedBox(height: 18),
          FdCard(
            child: Column(children: [
              _kv('Consultation fee', formatMoney(doctor.priceRm, currency)),
              const Divider(),
              _kv('Payment', 'Invoice issued after booking'),
            ]),
          ),
          const SizedBox(height: 24),
          FdButton(
            label: existing == null ? 'Request appointment' : 'Confirm new time',
            onPressed: _slot == null
                ? null
                : () {
                    if (existing != null) {
                      if (!store.reschedule(existing, _slot!)) {
                        _snack(context,
                            'That time was just booked. Please pick another.');
                        return;
                      }
                      Navigator.pop(context);
                      _snack(context,
                          'New time requested. The doctor will confirm it.');
                      return;
                    }
                    final booked = store.book(
                      doctor: doctor,
                      patientName: currentPatientName(),
                      start: _slot!,
                      mode: _mode,
                      reason: _reason.text,
                    );
                    if (booked == null) {
                      _snack(context,
                          'That time was just booked. Please pick another.');
                      return;
                    }
                    Navigator.pushReplacementNamed(
                        context, RouteNames.appointmentDetails,
                        arguments: booked);
                    _snack(context,
                        'Appointment requested. You will be notified when it is confirmed.');
                  },
          ),
        ],
      ),
    );
  }
}

/// Invoice view. The fee is only marked Paid after a payment provider
/// confirms it on the server.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final invoice = ModalRoute.of(context)?.settings.arguments as Invoice? ??
        store.invoices.first;
    return Scaffold(
      appBar: const FdAppBar(title: 'Invoice', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FdCard(
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Text(invoice.number, style: AppTextStyles.subtitle2)),
                FdStatusChip(label: invoice.status.label, tone: invoice.status.tone),
              ]),
              const Divider(height: 24),
              _kv('Service', invoice.service),
              _kv('Provider', invoice.provider),
              _kv('Issued', formatDate(invoice.issued)),
              if (invoice.status == InvoiceStatus.unpaid)
                _kv('Due', formatDate(invoice.due)),
              const Divider(height: 24),
              _kv('Amount', formatMoney(invoice.amount, invoice.currency)),
            ]),
          ),
          const SizedBox(height: 20),
          if (invoice.status == InvoiceStatus.unpaid) ...[
            const FdPreviewNotice(
                message:
                    'Online payment is not connected yet. This invoice stays Unpaid until a payment is confirmed.'),
            const SizedBox(height: 16),
            FdButton(
              label: 'Choose payment method',
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.paymentMethod),
            ),
          ],
          if (invoice.status == InvoiceStatus.paid)
            Text('Payment received. Thank you.',
                textAlign: TextAlign.center, style: AppTextStyles.secondary),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor: requests and schedule
// ---------------------------------------------------------------------------

class DoctorAppointmentsScreen extends StatelessWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    // The prototype signs doctors in as the first sample doctor.
    final me = MockData.doctors.first;
    final consults = store.consultations
        .where((c) => c.doctor.id == me.id)
        .toList();
    final mine = store.forDoctor(me);
    final requests =
        mine.where((a) => a.status == AppointmentStatus.pending && a.isUpcoming).toList();
    final confirmed =
        mine.where((a) => a.status == AppointmentStatus.confirmed).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests & schedule'),
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(
                text:
                    'Consultations (${consults.where((c) => c.status == ConsultationStatus.pending).length})'),
            Tab(text: 'Booking requests (${requests.length})'),
            Tab(text: 'Confirmed (${confirmed.length})'),
          ]),
        ),
        body: TabBarView(children: [
          consults.isEmpty
              ? const FdEmptyState(
                  title: 'No consultation requests',
                  message: 'New requests from users appear here.',
                  icon: Icons.forum_outlined)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                  itemCount: consults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _ConsultationCard(request: consults[i], forDoctor: true),
                ),
          _DoctorAppointmentList(
            items: requests,
            empty: 'No booking requests',
            actions: (a) => [
              ('Decline', true, () => store.setStatus(a, AppointmentStatus.rejected)),
              ('Confirm', false, () => store.setStatus(a, AppointmentStatus.confirmed)),
            ],
          ),
          _DoctorAppointmentList(
            items: confirmed,
            empty: 'No confirmed appointments',
            actions: (a) => a.start.isAfter(DateTime.now())
                ? [
                    ('Cancel', true, () => store.setStatus(a, AppointmentStatus.cancelled)),
                  ]
                : [
                    ('No-show', true, () => store.setStatus(a, AppointmentStatus.noShow)),
                    ('Completed', false, () => store.setStatus(a, AppointmentStatus.completed)),
                  ],
          ),
        ]),
      ),
    );
  }
}

class _DoctorAppointmentList extends StatelessWidget {
  const _DoctorAppointmentList({
    required this.items,
    required this.empty,
    required this.actions,
  });

  final List<CareAppointment> items;
  final String empty;
  final List<(String, bool, VoidCallback)> Function(CareAppointment) actions;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return FdEmptyState(
          title: empty,
          message: 'Nothing needs your attention here.',
          icon: Icons.event_available_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = items[i];
        final buttons = actions(a);
        return FdCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                FdAvatar(
                    initials: a.patientName
                        .split(' ')
                        .take(2)
                        .map((p) => p[0])
                        .join(),
                    size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.patientName,
                          style: AppTextStyles.bodyText1
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                          '${formatDate(a.start)} · ${formatTime(a.start)} · ${a.mode.label}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                FdStatusChip(label: a.status.label, tone: a.status.tone),
              ]),
              if (a.reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(a.reason, style: AppTextStyles.secondary),
              ],
              const SizedBox(height: 14),
              Row(children: [
                for (var j = 0; j < buttons.length; j++) ...[
                  if (j > 0) const SizedBox(width: 10),
                  Expanded(
                    child: FdButton(
                      label: buttons[j].$1,
                      outlined: buttons[j].$2,
                      onPressed: () {
                        buttons[j].$3();
                        _snack(context,
                            '${a.patientName}: ${buttons[j].$1.toLowerCase()}.');
                      },
                    ),
                  ),
                ],
              ]),
            ],
          ),
        );
      },
    );
  }
}
