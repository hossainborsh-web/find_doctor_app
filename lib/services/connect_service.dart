import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/domain/entities/user_role.dart';
import 'account_service.dart';
import 'cloud/fs_mirror.dart';
import 'cloud/supabase_api.dart';

// ===========================================================================
// Models
// ===========================================================================

enum DayStatus {
  available('Available'),
  busy('Busy'),
  off('Off');

  const DayStatus(this.label);
  final String label;

  static DayStatus parse(String? name) => DayStatus.values.firstWhere(
        (value) => value.name == name,
        orElse: () => DayStatus.available,
      );
}

/// One weekday in a doctor's weekly schedule.
class DaySchedule {
  DaySchedule({required this.status, this.start = '09:00', this.end = '17:00'});

  DayStatus status;
  String start;
  String end;

  String get hours => status == DayStatus.off ? 'Day off' : '$start – $end';

  DaySchedule copy() => DaySchedule(status: status, start: start, end: end);

  Map<String, dynamic> toJson() =>
      {'status': status.name, 'start': start, 'end': end};

  factory DaySchedule.fromJson(Map<String, dynamic> json) => DaySchedule(
        status: DayStatus.parse(json['status'] as String?),
        start: json['start'] as String? ?? '09:00',
        end: json['end'] as String? ?? '17:00',
      );
}

enum RequestStatus { pending, accepted, rejected }

/// A patient asking a doctor to start a chat.
class ChatRequest {
  ChatRequest({
    required this.id,
    required this.patientEmail,
    required this.patientName,
    required this.doctorEmail,
    required this.doctorName,
    required this.message,
    required this.createdAt,
    this.status = RequestStatus.pending,
    this.respondedAt,
    this.reason = '',
    this.conversationId,
  });

  final String id;
  final String patientEmail;
  final String patientName;
  final String doctorEmail;
  final String doctorName;
  final String message;
  final DateTime createdAt;
  RequestStatus status;
  DateTime? respondedAt;
  String reason;
  String? conversationId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientEmail': patientEmail,
        'patientName': patientName,
        'doctorEmail': doctorEmail,
        'doctorName': doctorName,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'respondedAt': respondedAt?.toIso8601String(),
        'reason': reason,
        'conversationId': conversationId,
      };

  factory ChatRequest.fromJson(Map<String, dynamic> json) => ChatRequest(
        id: json['id'] as String,
        patientEmail: json['patientEmail'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        doctorEmail: json['doctorEmail'] as String? ?? '',
        doctorName: json['doctorName'] as String? ?? '',
        message: json['message'] as String? ?? '',
        createdAt: _date(json['createdAt']),
        status: RequestStatus.values.firstWhere(
            (value) => value.name == json['status'],
            orElse: () => RequestStatus.pending),
        respondedAt: DateTime.tryParse(json['respondedAt'] as String? ?? ''),
        reason: json['reason'] as String? ?? '',
        conversationId: json['conversationId'] as String?,
      );
}

/// A medical report a doctor issues from a chat, signed with the doctor's
/// name and hospital.
class MedicalReport {
  MedicalReport({
    required this.code,
    required this.patientName,
    required this.patientEmail,
    required this.patientBirthday,
    required this.doctorName,
    required this.doctorEmail,
    required this.doctorType,
    required this.hospital,
    required this.specialty,
    required this.diagnosis,
    required this.findings,
    required this.treatment,
    required this.leaveDays,
    required this.followUp,
    required this.issuedAt,
  });

  final String code;
  final String patientName;
  final String patientEmail;
  final String patientBirthday;
  final String doctorName;
  final String doctorEmail;
  final String doctorType;
  final String hospital;
  final String specialty;
  final String diagnosis;
  final String findings;
  final String treatment;
  final int leaveDays;
  final String followUp;
  final DateTime issuedAt;

  String get hospitalLabel =>
      hospital.trim().isEmpty ? 'No hospital listed' : hospital.trim();

  Map<String, dynamic> toJson() => {
        'code': code,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'patientBirthday': patientBirthday,
        'doctorName': doctorName,
        'doctorEmail': doctorEmail,
        'doctorType': doctorType,
        'hospital': hospital,
        'specialty': specialty,
        'diagnosis': diagnosis,
        'findings': findings,
        'treatment': treatment,
        'leaveDays': leaveDays,
        'followUp': followUp,
        'issuedAt': issuedAt.toIso8601String(),
      };

  factory MedicalReport.fromJson(Map<String, dynamic> json) => MedicalReport(
        code: json['code'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        patientEmail: json['patientEmail'] as String? ?? '',
        patientBirthday: json['patientBirthday'] as String? ?? '',
        doctorName: json['doctorName'] as String? ?? '',
        doctorEmail: json['doctorEmail'] as String? ?? '',
        doctorType: json['doctorType'] as String? ?? 'Doctor',
        hospital: json['hospital'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
        diagnosis: json['diagnosis'] as String? ?? '',
        findings: json['findings'] as String? ?? '',
        treatment: json['treatment'] as String? ?? '',
        leaveDays: json['leaveDays'] as int? ?? 0,
        followUp: json['followUp'] as String? ?? '',
        issuedAt: _date(json['issuedAt']),
      );
}

class ConnectMessage {
  ConnectMessage({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.kind = 'text',
    this.report,
  });

  final String id;
  final String senderEmail;
  final String senderName;
  final String text;
  final DateTime createdAt;

  /// "text", "system" or "report".
  final String kind;
  final MedicalReport? report;

  bool get isSystem => kind == 'system';
  bool get isReport => kind == 'report' && report != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderEmail': senderEmail,
        'senderName': senderName,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind,
        'report': report?.toJson(),
      };

  factory ConnectMessage.fromJson(Map<String, dynamic> json) => ConnectMessage(
        id: json['id'] as String,
        senderEmail: json['senderEmail'] as String? ?? '',
        senderName: json['senderName'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: _date(json['createdAt']),
        kind: json['kind'] as String? ?? 'text',
        report: json['report'] == null
            ? null
            : MedicalReport.fromJson(json['report'] as Map<String, dynamic>),
      );
}

/// A chat between a patient and a doctor, a private hospital group or a
/// community group.
class Conversation {
  Conversation({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.description = '',
    this.hospital = '',
    this.leaderEmail = '',
    this.staffRoom = false,
    List<String>? members,
    Map<String, String>? memberNames,
    List<ConnectMessage>? messages,
    Map<String, DateTime>? lastRead,
  })  : members = members ?? <String>[],
        memberNames = memberNames ?? <String, String>{},
        messages = messages ?? <ConnectMessage>[],
        lastRead = lastRead ?? <String, DateTime>{};

  final String id;

  /// "direct", "hospital" or "community".
  final String type;
  String title;
  String description;
  final String hospital;
  final String leaderEmail;

  /// The automatic group every doctor and manager of a hospital belongs to.
  final bool staffRoom;
  final List<String> members;
  final Map<String, String> memberNames;
  final List<ConnectMessage> messages;
  final Map<String, DateTime> lastRead;
  final DateTime createdAt;

  bool get isDirect => type == 'direct';
  bool get isHospital => type == 'hospital';
  bool get isCommunity => type == 'community';

  DateTime get lastActivity =>
      messages.isEmpty ? createdAt : messages.last.createdAt;

  String nameOf(String email) => memberNames[email] ?? email;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'hospital': hospital,
        'leaderEmail': leaderEmail,
        'staffRoom': staffRoom,
        'members': members,
        'memberNames': memberNames,
        'messages': messages.map((message) => message.toJson()).toList(),
        'lastRead': lastRead
            .map((key, value) => MapEntry(key, value.toIso8601String())),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'direct',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        hospital: json['hospital'] as String? ?? '',
        leaderEmail: json['leaderEmail'] as String? ?? '',
        staffRoom: json['staffRoom'] as bool? ?? false,
        members: [...(json['members'] as List<dynamic>? ?? []).cast<String>()],
        memberNames: {
          ...((json['memberNames'] as Map<String, dynamic>?) ?? {})
              .map((key, value) => MapEntry(key, value as String)),
        },
        messages: [
          for (final item in (json['messages'] as List<dynamic>? ?? []))
            ConnectMessage.fromJson(item as Map<String, dynamic>),
        ],
        lastRead: {
          ...((json['lastRead'] as Map<String, dynamic>?) ?? {})
              .map((key, value) => MapEntry(key, _date(value))),
        },
        createdAt: _date(json['createdAt']),
      );
}

// ---------------------------------------------------------------- visits

enum VisitStatus {
  requested('Waiting for doctor'),
  confirmed('Confirmed'),
  declined('Declined'),
  cancelled('Cancelled'),
  completed('Completed');

  const VisitStatus(this.label);
  final String label;

  /// Requested and confirmed visits keep their time slot.
  bool get holdsSlot => this == requested || this == confirmed;

  static VisitStatus parse(String? name) => VisitStatus.values.firstWhere(
        (value) => value.name == name,
        orElse: () => VisitStatus.requested,
      );
}

/// A visit a user books at a doctor's hospital, inside the doctor's
/// weekly schedule. The doctor confirms or declines it.
class Visit {
  Visit({
    required this.id,
    required this.code,
    required this.patientEmail,
    required this.patientName,
    required this.doctorEmail,
    required this.doctorName,
    required this.doctorType,
    required this.specialty,
    required this.hospital,
    required this.start,
    required this.reason,
    required this.createdAt,
    this.minutes = 30,
    this.status = VisitStatus.requested,
    this.note = '',
    this.updatedBy = '',
  });

  final String id;
  final String code;
  final String patientEmail;
  final String patientName;
  final String doctorEmail;
  final String doctorName;
  final String doctorType;
  final String specialty;
  final String hospital;
  final DateTime start;
  final int minutes;
  final String reason;
  final DateTime createdAt;
  VisitStatus status;

  /// Decline or cancel reason.
  String note;

  /// Email of whoever last changed the status.
  String updatedBy;

  DateTime get end => start.add(Duration(minutes: minutes));

  /// Still ahead and holding its slot.
  bool get isUpcoming => status.holdsSlot && end.isAfter(DateTime.now());

  /// A request the doctor never answered before the visit time.
  bool get isExpired =>
      status == VisitStatus.requested && !start.isAfter(DateTime.now());

  /// Confirmed, and the visit time has started.
  bool get canComplete =>
      status == VisitStatus.confirmed && !start.isAfter(DateTime.now());

  String get statusLabel {
    if (isExpired) return 'Not confirmed';
    if (status == VisitStatus.confirmed && !end.isAfter(DateTime.now())) {
      return 'Awaiting completion';
    }
    return status.label;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'patientEmail': patientEmail,
        'patientName': patientName,
        'doctorEmail': doctorEmail,
        'doctorName': doctorName,
        'doctorType': doctorType,
        'specialty': specialty,
        'hospital': hospital,
        'start': start.toIso8601String(),
        'minutes': minutes,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'note': note,
        'updatedBy': updatedBy,
      };

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as String,
        code: json['code'] as String? ?? '',
        patientEmail: json['patientEmail'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        doctorEmail: json['doctorEmail'] as String? ?? '',
        doctorName: json['doctorName'] as String? ?? '',
        doctorType: json['doctorType'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
        hospital: json['hospital'] as String? ?? '',
        start: _date(json['start']),
        minutes: (json['minutes'] as num?)?.toInt() ?? 30,
        reason: json['reason'] as String? ?? '',
        createdAt: _date(json['createdAt']),
        status: VisitStatus.parse(json['status'] as String?),
        note: json['note'] as String? ?? '',
        updatedBy: json['updatedBy'] as String? ?? '',
      );
}

class ConnectNotification {
  ConnectNotification({
    required this.id,
    required this.recipient,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.refId = '',
  });

  final String id;
  final String recipient;

  /// chat_request, request_accepted, request_rejected, report, group_added,
  /// group_removed.
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  bool read;
  final String refId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipient': recipient,
        'type': type,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
        'refId': refId,
      };

  factory ConnectNotification.fromJson(Map<String, dynamic> json) =>
      ConnectNotification(
        id: json['id'] as String,
        recipient: json['recipient'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: _date(json['createdAt']),
        read: json['read'] as bool? ?? false,
        refId: json['refId'] as String? ?? '',
      );
}

class ConnectException implements Exception {
  const ConnectException(this.message);
  final String message;

  @override
  String toString() => message;
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value as String? ?? '') ?? DateTime.now();

// ===========================================================================
// Service
// ===========================================================================

/// One doctor's weekly schedule (table `schedules`, id = email).
class _ScheduleDoc {
  _ScheduleDoc(this.email, this.days);
  final String email;
  final List<DaySchedule> days;

  Map<String, dynamic> toJson() => {
        'email': email,
        'days': days.map((day) => day.toJson()).toList(),
      };

  factory _ScheduleDoc.fromJson(String id, Map<String, dynamic> json) =>
      _ScheduleDoc(id, [
        for (final day in json['days'] as List<dynamic>? ?? [])
          DaySchedule.fromJson(day as Map<String, dynamic>),
      ]);
}

/// A booked time (table `slots`): public, without patient details, so
/// everyone can see which times are taken.
class _Slot {
  _Slot({
    required this.id,
    required this.doctorEmail,
    required this.start,
    required this.owner,
    required this.visitId,
  });

  final String id;
  final String doctorEmail;
  final DateTime start;
  final String owner;
  final String visitId;

  Map<String, dynamic> toJson() => {
        'doctorEmail': doctorEmail,
        'start': start.toIso8601String(),
        'owner': owner,
        'visitId': visitId,
      };

  factory _Slot.fromJson(String id, Map<String, dynamic> json) => _Slot(
        id: id,
        doctorEmail: json['doctorEmail'] as String? ?? '',
        start: _date(json['start']),
        owner: json['owner'] as String? ?? '',
        visitId: json['visitId'] as String? ?? '',
      );
}

/// Chat requests, conversations, groups, doctor schedules, visits, medical
/// reports and notifications — in Supabase, live on every device.
class ConnectService extends ChangeNotifier {
  ConnectService._() {
    AccountService.instance.addListener(_refreshAccounts);
  }

  static final ConnectService instance = ConnectService._();

  final List<_ScheduleDoc> _scheduleDocs = [];
  final List<ChatRequest> _requests = [];
  final List<Conversation> _conversations = [];
  final List<ConnectNotification> _notifications = [];
  final List<Visit> _visits = [];
  final List<_Slot> _slots = [];
  List<AppAccount> _accounts = const [];
  AppAccount? _me;

  late final FsMirror<_ScheduleDoc> _scheduleMirror = FsMirror<_ScheduleDoc>(
    collection: 'schedules',
    pollEvery: const Duration(seconds: 15),
    list: _scheduleDocs,
    idOf: (doc) => doc.email,
    toJson: (doc) => doc.toJson(),
    fromJson: _ScheduleDoc.fromJson,
    onChange: notifyListeners,
  );
  late final FsMirror<ChatRequest> _requestMirror = FsMirror<ChatRequest>(
    collection: 'chatRequests',
    list: _requests,
    idOf: (item) => item.id,
    toJson: (item) => item.toJson(),
    fromJson: (id, json) => ChatRequest.fromJson({...json, 'id': id}),
    onChange: notifyListeners,
  );
  late final FsMirror<Conversation> _conversationMirror =
      FsMirror<Conversation>(
    collection: 'conversations',
    list: _conversations,
    idOf: (item) => item.id,
    toJson: (item) => item.toJson(),
    fromJson: (id, json) => Conversation.fromJson({...json, 'id': id}),
    onChange: notifyListeners,
    write: _writeConversation,
  );
  late final FsMirror<ConnectNotification> _notificationMirror =
      FsMirror<ConnectNotification>(
    collection: 'notifications',
    list: _notifications,
    idOf: (item) => item.id,
    toJson: (item) => item.toJson(),
    fromJson: (id, json) => ConnectNotification.fromJson({...json, 'id': id}),
    onChange: notifyListeners,
  );
  late final FsMirror<Visit> _visitMirror = FsMirror<Visit>(
    collection: 'visits',
    list: _visits,
    idOf: (item) => item.id,
    toJson: (item) => item.toJson(),
    fromJson: (id, json) => Visit.fromJson({...json, 'id': id}),
    onChange: notifyListeners,
  );
  late final FsMirror<_Slot> _slotMirror = FsMirror<_Slot>(
    collection: 'slots',
    list: _slots,
    idOf: (item) => item.id,
    toJson: (item) => item.toJson(),
    fromJson: _Slot.fromJson,
    onChange: notifyListeners,
  );

  List<FsMirror<Object?>> get _mirrors => [
        _scheduleMirror,
        _requestMirror,
        _conversationMirror,
        _notificationMirror,
        _visitMirror,
        _slotMirror,
      ];

  bool get isLoaded => _me != null;
  List<AppAccount> get accounts => _accounts;

  /// Starts listening for [me]: only what this person may see is loaded.
  void attach(AppAccount me) {
    _me = me;
    const db = CloudDb.instance;
    _scheduleMirror.listen([db.collection('schedules')]);
    final requests = db.collection('chatRequests');
    _requestMirror.listen([
      requests.where('patientEmail', isEqualTo: me.email),
      requests.where('doctorEmail', isEqualTo: me.email),
    ]);
    final conversations = db.collection('conversations');
    _conversationMirror.listen([
      conversations.where('members', arrayContains: me.email),
      conversations.where('type', isEqualTo: 'community'),
      if (isStaff(me) && me.hospital.trim().isNotEmpty)
        conversations
            .where('type', isEqualTo: 'hospital')
            .where('hospital', isEqualTo: me.hospital.trim()),
    ]);
    _notificationMirror.listen([
      db.collection('notifications').where('recipient', isEqualTo: me.email),
    ]);
    final visits = db.collection('visits');
    _visitMirror.listen([
      visits.where('patientEmail', isEqualTo: me.email),
      visits.where('doctorEmail', isEqualTo: me.email),
      if (AccountService.isGeneralManager(me))
        visits
      else if (AccountService.isHr(me))
        visits.where('hospital', isEqualTo: me.hospital.trim()),
    ]);
    final today = DateTime.now();
    _slotMirror.listen([
      db.collection('slots').where('start',
          isGreaterThanOrEqualTo:
              DateTime(today.year, today.month, today.day).toIso8601String()),
    ]);
    _refreshAccounts();
  }

  void detach() {
    _me = null;
    for (final mirror in _mirrors) {
      mirror.listen(const []);
    }
    notifyListeners();
  }

  /// Waits until the first data has arrived.
  Future<void> load() async {
    if (_me == null) return;
    await Future.wait([for (final mirror in _mirrors) mirror.ready]);
  }

  Future<void> _refreshAccounts() async {
    _accounts = await AccountService.instance.accounts();
    notifyListeners();
  }

  Future<void> refresh() => _refreshAccounts();

  Future<void> _save() async {
    notifyListeners();
    for (final mirror in _mirrors) {
      await mirror.push();
    }
  }

  /// New messages are appended (never overwritten), so two people writing at
  /// once don't lose each other's messages.
  static void _writeConversation(
    WriteBatch batch,
    DocumentReference ref,
    JsonMap now,
    JsonMap? before,
  ) {
    if (before == null) {
      batch.set(ref, now);
      return;
    }
    final updates = <Object, Object?>{};
    now.forEach((key, value) {
      if (key == 'messages' || key == 'lastRead' || key == 'memberNames') {
        return;
      }
      if (canonicalJson(value) != canonicalJson(before[key])) {
        updates[key] = value;
      }
    });
    final oldIds = {
      for (final message in before['messages'] as List<dynamic>? ?? [])
        (message as Map)['id'],
    };
    final added = [
      for (final message in now['messages'] as List<dynamic>? ?? [])
        if (!oldIds.contains((message as Map)['id'])) message,
    ];
    if (added.isNotEmpty) updates['messages'] = FieldValue.arrayUnion(added);
    for (final field in const ['lastRead', 'memberNames']) {
      final current = (now[field] as Map?) ?? const {};
      final previous = (before[field] as Map?) ?? const {};
      current.forEach((key, value) {
        if (previous[key] != value) {
          updates[FieldPath([field, key as String])] = value;
        }
      });
      for (final key in previous.keys) {
        if (!current.containsKey(key)) {
          updates[FieldPath([field, key as String])] = FieldValue.delete();
        }
      }
    }
    if (updates.isNotEmpty) batch.update(ref, updates);
  }

  // ------------------------------------------------------------- who is who

  /// Doctors who work at a hospital. Students and New Doctors looking for
  /// work are not doctors here until HR hires them.
  static bool isDoctor(AppAccount? account) =>
      account != null && account.practises;

  /// Doctors and managers (hospital staff).
  static bool isStaff(AppAccount? account) =>
      account != null &&
      (isDoctor(account) ||
          account.role == UserRole.manager ||
          account.managerLevel != null);

  static String hospitalKey(String hospital) => hospital.trim().toLowerCase();

  static String displayName(AppAccount account) {
    final name = account.fullName.trim().isEmpty
        ? account.email
        : account.fullName.trim();
    if (isDoctor(account) && !name.toLowerCase().startsWith('dr')) {
      return 'Dr. $name';
    }
    return name;
  }

  AppAccount? accountByEmail(String email) {
    for (final account in _accounts) {
      if (account.email == email) return account;
    }
    return null;
  }

  /// Active doctors patients can find and message.
  List<AppAccount> get doctors => _accounts
      .where((account) =>
          isDoctor(account) && account.status == AccountStatus.active)
      .toList()
    ..sort((a, b) => displayName(a).compareTo(displayName(b)));

  /// Active staff of the same hospital as [me] (excluding [me]).
  List<AppAccount> colleaguesOf(AppAccount me) => _accounts
      .where((account) =>
          account.email != me.email &&
          account.status == AccountStatus.active &&
          isStaff(account) &&
          sameHospital(account, me))
      .toList();

  static bool sameHospital(AppAccount a, AppAccount b) =>
      hospitalKey(a.hospital).isNotEmpty &&
      hospitalKey(a.hospital) == hospitalKey(b.hospital);

  // --------------------------------------------------------------- schedule

  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static List<DaySchedule> defaultSchedule() => [
        for (var i = 0; i < 5; i++) DaySchedule(status: DayStatus.available),
        DaySchedule(status: DayStatus.busy, start: '09:00', end: '13:00'),
        DaySchedule(status: DayStatus.off),
      ];

  /// The doctor's week, Monday first. Copies — edit then [saveSchedule].
  _ScheduleDoc? _scheduleOf(String email) {
    for (final doc in _scheduleDocs) {
      if (doc.email == email) return doc;
    }
    return null;
  }

  List<DaySchedule> scheduleFor(String email) =>
      (_scheduleOf(email)?.days ?? defaultSchedule())
          .map((day) => day.copy())
          .toList();

  bool hasCustomSchedule(String email) => _scheduleOf(email) != null;

  Future<void> saveSchedule(String email, List<DaySchedule> days) async {
    _scheduleDocs.removeWhere((doc) => doc.email == email);
    _scheduleDocs.add(_ScheduleDoc(email, days.map((day) => day.copy()).toList()));
    await _save();
  }

  DaySchedule todayFor(String email) =>
      scheduleFor(email)[DateTime.now().weekday - 1];

  /// "Available now", "Busy today", "Off today", "Outside hours".
  String statusNowLabel(String email) {
    final today = todayFor(email);
    switch (today.status) {
      case DayStatus.off:
        return 'Off today';
      case DayStatus.busy:
        return 'Busy today';
      case DayStatus.available:
        final now = DateTime.now();
        final minutes = now.hour * 60 + now.minute;
        if (minutes >= minutesOf(today.end)) return 'Finished today';
        return minutes >= minutesOf(today.start)
            ? 'Available now'
            : 'Available today ${today.start} – ${today.end}';
    }
  }

  /// "09:30" → 570.
  static int minutesOf(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts.first.trim()) ?? 0) * 60 +
        (parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0);
  }

  // ----------------------------------------------------------------- visits

  static const visitMinutes = 30;

  /// How far ahead users can book.
  static const bookingDays = 14;

  Visit? visitById(String id) {
    for (final visit in _visits) {
      if (visit.id == id) return visit;
    }
    return null;
  }

  bool _slotTaken(String doctorEmail, DateTime start) {
    final end = start.add(const Duration(minutes: visitMinutes));
    final byVisit = _visits.any((visit) =>
        visit.doctorEmail == doctorEmail &&
        visit.status.holdsSlot &&
        visit.start.isBefore(end) &&
        visit.end.isAfter(start));
    if (byVisit) return true;
    // Slots booked by other people (their visits are private to them).
    return _slots.any((slot) =>
        slot.doctorEmail == doctorEmail &&
        slot.start.isBefore(end) &&
        slot.start.add(const Duration(minutes: visitMinutes)).isAfter(start));
  }

  static String _slotId(String doctorEmail, DateTime start) =>
      '${doctorEmail}_${start.millisecondsSinceEpoch}';

  /// Frees the booked time of a visit that no longer holds it.
  void _freeSlot(Visit visit) {
    _slots.removeWhere((slot) => slot.visitId == visit.id);
  }

  /// Free start times on [day]: every 30 minutes inside the doctor's hours
  /// on available days, at least one hour from now. Busy and off days take
  /// no new visits.
  List<DateTime> openSlots(String doctorEmail, DateTime day) {
    final schedule = scheduleFor(doctorEmail)[day.weekday - 1];
    if (schedule.status != DayStatus.available) return const [];
    final from = minutesOf(schedule.start);
    final to = minutesOf(schedule.end);
    final earliest = DateTime.now().add(const Duration(hours: 1));
    final slots = <DateTime>[];
    for (var minute = from; minute + visitMinutes <= to; minute += visitMinutes) {
      final start =
          DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
      if (start.isBefore(earliest) || _slotTaken(doctorEmail, start)) continue;
      slots.add(start);
    }
    return slots;
  }

  /// Today and the next [bookingDays] - 1 days.
  static List<DateTime> bookingWindow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = 0; i < bookingDays; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
  }

  bool _involves(Visit visit, String email) =>
      visit.patientEmail == email || visit.doctorEmail == email;

  /// Every visit of [email] (as user or as doctor).
  List<Visit> visitsFor(String email) =>
      _visits.where((visit) => _involves(visit, email)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  List<Visit> upcomingVisitsFor(String email) =>
      visitsFor(email).where((visit) => visit.isUpcoming).toList();

  List<Visit> pastVisitsFor(String email) =>
      visitsFor(email).where((visit) => !visit.isUpcoming).toList().reversed
          .toList();

  /// Requests still waiting for [doctorEmail] to answer.
  List<Visit> visitRequestsFor(String doctorEmail) => _visits
      .where((visit) =>
          visit.doctorEmail == doctorEmail &&
          visit.status == VisitStatus.requested &&
          visit.start.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  /// Visits holding a slot on [day] for [doctorEmail].
  List<Visit> doctorVisitsOn(String doctorEmail, DateTime day) => _visits
      .where((visit) =>
          visit.doctorEmail == doctorEmail &&
          visit.status.holdsSlot &&
          visit.start.year == day.year &&
          visit.start.month == day.month &&
          visit.start.day == day.day)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  /// Visits at [hospital] (for managers).
  List<Visit> visitsAtHospital(String hospital) => _visits
      .where((visit) =>
          hospitalKey(visit.hospital).isNotEmpty &&
          hospitalKey(visit.hospital) == hospitalKey(hospital))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  List<Visit> get allVisits => List.unmodifiable(_visits);

  Future<Visit> bookVisit({
    required AppAccount patient,
    required AppAccount doctor,
    required DateTime start,
    required String reason,
  }) async {
    await load();
    if (patient.email == doctor.email) {
      throw const ConnectException('You can\'t book a visit with yourself.');
    }
    if (!isDoctor(doctor) || doctor.status != AccountStatus.active) {
      throw const ConnectException('This doctor is not taking visits.');
    }
    if (doctor.hospital.trim().isEmpty) {
      throw const ConnectException(
          'This doctor has no hospital yet, so visits can\'t be booked.');
    }
    if (reason.trim().length < 5) {
      throw const ConnectException('Please tell the doctor why you\'re coming.');
    }
    final day = DateTime(start.year, start.month, start.day);
    if (!openSlots(doctor.email, day).contains(start)) {
      throw const ConnectException(
          'That time was just taken. Please choose another time.');
    }
    if (_visits.any((visit) =>
        visit.patientEmail == patient.email &&
        visit.doctorEmail == doctor.email &&
        visit.isUpcoming)) {
      throw const ConnectException(
          'You already have an upcoming visit with this doctor.');
    }
    if (_visits.any((visit) =>
        visit.patientEmail == patient.email &&
        visit.isUpcoming &&
        visit.start == start)) {
      throw const ConnectException(
          'You already have another visit at that time.');
    }
    final visit = Visit(
      id: _id(),
      code: 'V-${100000 + _random.nextInt(900000)}',
      patientEmail: patient.email,
      patientName: displayName(patient),
      doctorEmail: doctor.email,
      doctorName: displayName(doctor),
      doctorType: doctor.typeLabel,
      specialty: doctor.specialty,
      hospital: doctor.hospital.trim(),
      start: start,
      reason: reason.trim(),
      createdAt: DateTime.now(),
      updatedBy: patient.email,
    );
    // Reserve the time first, atomically, so two people can't book it.
    final slot = _Slot(
      id: _slotId(doctor.email, start),
      doctorEmail: doctor.email,
      start: start,
      owner: CloudAuth.instance.currentUser?.uid ?? '',
      visitId: visit.id,
    );
    final slotRef = CloudDb.instance.collection('slots').doc(slot.id);
    try {
      // Fails if the time already exists (the slot id is doctor + time).
      await slotRef.create(slot.toJson());
    } on ConnectException {
      rethrow;
    } catch (error) {
      if (error is CloudDbException && error.code == 'already-exists') {
        throw const ConnectException(
            'That time was just taken. Please choose another time.');
      }
      throw const ConnectException(
          'Could not book right now. Check your internet connection.');
    }
    _visitMirror.list.add(visit);
    _notify(
      doctor.email,
      type: 'visit_request',
      title: 'New visit request',
      body: '${visit.patientName} · ${fullDateTime(start)} · ${visit.reason}',
      refId: visit.id,
    );
    await _save();
    return visit;
  }

  Visit _ownVisit(String id, String email, {bool doctorOnly = false}) {
    final visit = visitById(id);
    if (visit == null ||
        (doctorOnly ? visit.doctorEmail != email : !_involves(visit, email))) {
      throw const ConnectException('This visit is no longer available.');
    }
    return visit;
  }

  Future<void> confirmVisit(String id, AppAccount doctor) async {
    final visit = _ownVisit(id, doctor.email, doctorOnly: true);
    if (visit.status != VisitStatus.requested || visit.isExpired) {
      throw const ConnectException('This visit can no longer be confirmed.');
    }
    visit
      ..status = VisitStatus.confirmed
      ..updatedBy = doctor.email;
    _readNotificationsFor(visit.id);
    _notify(
      visit.patientEmail,
      type: 'visit_confirmed',
      title: 'Visit confirmed',
      body: '${visit.doctorName} confirmed your visit on '
          '${fullDateTime(visit.start)} at ${visit.hospital}.',
      refId: visit.id,
    );
    await _save();
  }

  Future<void> declineVisit(String id, AppAccount doctor,
      {String reason = ''}) async {
    final visit = _ownVisit(id, doctor.email, doctorOnly: true);
    if (!visit.isUpcoming) {
      throw const ConnectException('This visit can no longer be changed.');
    }
    visit
      ..status = VisitStatus.declined
      ..note = reason.trim()
      ..updatedBy = doctor.email;
    _freeSlot(visit);
    _readNotificationsFor(visit.id);
    _notify(
      visit.patientEmail,
      type: 'visit_declined',
      title: 'Visit declined',
      body: '${visit.doctorName} can\'t see you on '
          '${fullDateTime(visit.start)}'
          '${visit.note.isEmpty ? '.' : ': ${visit.note}'}',
      refId: visit.id,
    );
    await _save();
  }

  Future<void> cancelVisit(String id, AppAccount me, {String reason = ''}) async {
    final visit = _ownVisit(id, me.email);
    if (!visit.isUpcoming) {
      throw const ConnectException('This visit can no longer be cancelled.');
    }
    visit
      ..status = VisitStatus.cancelled
      ..note = reason.trim()
      ..updatedBy = me.email;
    _freeSlot(visit);
    _readNotificationsFor(visit.id);
    final byDoctor = me.email == visit.doctorEmail;
    _notify(
      byDoctor ? visit.patientEmail : visit.doctorEmail,
      type: 'visit_cancelled',
      title: 'Visit cancelled',
      body: '${byDoctor ? visit.doctorName : visit.patientName} cancelled the '
          'visit on ${fullDateTime(visit.start)}'
          '${visit.note.isEmpty ? '.' : ': ${visit.note}'}',
      refId: visit.id,
    );
    await _save();
  }

  Future<void> completeVisit(String id, AppAccount doctor) async {
    final visit = _ownVisit(id, doctor.email, doctorOnly: true);
    if (!visit.canComplete) {
      throw const ConnectException(
          'Only confirmed visits that have started can be completed.');
    }
    visit
      ..status = VisitStatus.completed
      ..updatedBy = doctor.email;
    await _save();
  }

  void _readNotificationsFor(String refId) {
    final me = _me?.email;
    for (final notification in _notifications) {
      if (notification.refId == refId && notification.recipient == me) {
        notification.read = true;
      }
    }
  }

  // --------------------------------------------------------------- requests

  List<ChatRequest> pendingRequestsFor(String doctorEmail) => _requests
      .where((request) =>
          request.doctorEmail == doctorEmail &&
          request.status == RequestStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<ChatRequest> requestsByPatient(String patientEmail) => _requests
      .where((request) => request.patientEmail == patientEmail)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  ChatRequest? latestRequest(String patientEmail, String doctorEmail) {
    ChatRequest? latest;
    for (final request in _requests) {
      if (request.patientEmail == patientEmail &&
          request.doctorEmail == doctorEmail &&
          (latest == null || request.createdAt.isAfter(latest.createdAt))) {
        latest = request;
      }
    }
    return latest;
  }

  ChatRequest? requestById(String id) {
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  Future<ChatRequest> sendRequest({
    required AppAccount patient,
    required AppAccount doctor,
    required String message,
  }) async {
    await load();
    if (patient.email == doctor.email) {
      throw const ConnectException('You can\'t send a request to yourself.');
    }
    if (directBetween(patient.email, doctor.email) != null) {
      throw const ConnectException('You already have a chat with this doctor.');
    }
    final latest = latestRequest(patient.email, doctor.email);
    if (latest != null && latest.status == RequestStatus.pending) {
      throw const ConnectException(
          'Your request is still waiting for the doctor to respond.');
    }
    final request = ChatRequest(
      id: _id(),
      patientEmail: patient.email,
      patientName: displayName(patient),
      doctorEmail: doctor.email,
      doctorName: displayName(doctor),
      message: message.trim(),
      createdAt: DateTime.now(),
    );
    _requests.add(request);
    _notify(
      doctor.email,
      type: 'chat_request',
      title: 'New chat request',
      body: '${request.patientName}: ${request.message}',
      refId: request.id,
    );
    await _save();
    return request;
  }

  Future<Conversation> acceptRequest(String requestId, AppAccount doctor) async {
    final request = requestById(requestId);
    if (request == null || request.doctorEmail != doctor.email) {
      throw const ConnectException('This request is no longer available.');
    }
    if (request.status != RequestStatus.pending) {
      final existing = directBetween(request.patientEmail, doctor.email);
      if (existing != null) return existing;
      throw const ConnectException('This request was already answered.');
    }
    final now = DateTime.now();
    final conversation = directBetween(request.patientEmail, doctor.email) ??
        Conversation(
          id: _id(),
          type: 'direct',
          title: '',
          createdAt: now,
          members: [request.patientEmail, doctor.email],
          memberNames: {
            request.patientEmail: request.patientName,
            doctor.email: displayName(doctor),
          },
        );
    if (!_conversations.contains(conversation)) {
      _conversations.add(conversation);
    }
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: request.patientEmail,
      senderName: request.patientName,
      text: request.message,
      createdAt: request.createdAt,
    ));
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: '',
      senderName: '',
      text: '${displayName(doctor)} accepted the chat request',
      createdAt: now,
      kind: 'system',
    ));
    conversation.lastRead[doctor.email] = now;
    request
      ..status = RequestStatus.accepted
      ..respondedAt = now
      ..conversationId = conversation.id;
    _markRequestNotificationsRead(request.id);
    _notify(
      request.patientEmail,
      type: 'request_accepted',
      title: 'Chat request accepted',
      body: '${displayName(doctor)} accepted your request. You can chat now.',
      refId: conversation.id,
    );
    await _save();
    return conversation;
  }

  Future<void> rejectRequest(String requestId, AppAccount doctor,
      {String reason = ''}) async {
    final request = requestById(requestId);
    if (request == null ||
        request.doctorEmail != doctor.email ||
        request.status != RequestStatus.pending) {
      return;
    }
    request
      ..status = RequestStatus.rejected
      ..respondedAt = DateTime.now()
      ..reason = reason.trim();
    _markRequestNotificationsRead(request.id);
    _notify(
      request.patientEmail,
      type: 'request_rejected',
      title: 'Chat request declined',
      body: reason.trim().isEmpty
          ? '${displayName(doctor)} can\'t take your request right now.'
          : '${displayName(doctor)}: ${reason.trim()}',
      refId: request.id,
    );
    await _save();
  }

  void _markRequestNotificationsRead(String requestId) {
    final me = _me?.email;
    for (final notification in _notifications) {
      if (notification.refId == requestId && notification.recipient == me) {
        notification.read = true;
      }
    }
  }

  // ---------------------------------------------------------- conversations

  Conversation? conversationById(String id) {
    for (final conversation in _conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  Conversation? directBetween(String a, String b) {
    for (final conversation in _conversations) {
      if (conversation.isDirect &&
          conversation.members.contains(a) &&
          conversation.members.contains(b)) {
        return conversation;
      }
    }
    return null;
  }

  List<Conversation> directChatsFor(String email) => _conversations
      .where((conversation) =>
          conversation.isDirect && conversation.members.contains(email))
      .toList()
    ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

  /// The other person in a direct chat.
  String otherMember(Conversation conversation, String me) =>
      conversation.members.firstWhere((email) => email != me,
          orElse: () => me);

  String titleFor(Conversation conversation, String me) =>
      conversation.isDirect
          ? conversation.nameOf(otherMember(conversation, me))
          : conversation.title;

  int unreadCount(Conversation conversation, String email) {
    final seen = conversation.lastRead[email];
    return conversation.messages
        .where((message) =>
            message.senderEmail != email &&
            !message.isSystem &&
            (seen == null || message.createdAt.isAfter(seen)))
        .length;
  }

  int totalUnread(AppAccount? me) {
    if (me == null) return 0;
    var total = 0;
    for (final conversation in _conversations) {
      if (isMember(conversation, me)) {
        total += unreadCount(conversation, me.email);
      }
    }
    return total;
  }

  Future<void> markRead(Conversation conversation, String email) async {
    if (unreadCount(conversation, email) == 0 &&
        conversation.lastRead.containsKey(email)) {
      return;
    }
    conversation.lastRead[email] = DateTime.now();
    await _save();
  }

  Future<void> sendMessage(
      Conversation conversation, AppAccount sender, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!isMember(conversation, sender)) {
      throw const ConnectException('Join the group to post here.');
    }
    final now = DateTime.now();
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: sender.email,
      senderName: displayName(sender),
      text: trimmed,
      createdAt: now,
    ));
    conversation.memberNames[sender.email] = displayName(sender);
    conversation.lastRead[sender.email] = now;
    await _save();
  }

  /// A doctor issues a medical report inside a chat with a patient.
  Future<MedicalReport> issueReport({
    required Conversation conversation,
    required AppAccount doctor,
    required String diagnosis,
    required String findings,
    required String treatment,
    required int leaveDays,
    required String followUp,
  }) async {
    if (!conversation.isDirect || !isDoctor(doctor)) {
      throw const ConnectException(
          'Only the doctor in this chat can issue a medical report.');
    }
    final patientEmail = otherMember(conversation, doctor.email);
    final patient = accountByEmail(patientEmail);
    final now = DateTime.now();
    final report = MedicalReport(
      code: 'MR-${now.year}-${_random.nextInt(900000) + 100000}',
      patientName: conversation.nameOf(patientEmail),
      patientEmail: patientEmail,
      patientBirthday: patient?.birthday ?? '',
      doctorName: displayName(doctor),
      doctorEmail: doctor.email,
      doctorType: doctor.typeLabel,
      hospital: doctor.hospital,
      specialty: doctor.specialty,
      diagnosis: diagnosis.trim(),
      findings: findings.trim(),
      treatment: treatment.trim(),
      leaveDays: leaveDays,
      followUp: followUp.trim(),
      issuedAt: now,
    );
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: doctor.email,
      senderName: displayName(doctor),
      text: 'Medical report ${report.code}',
      createdAt: now,
      kind: 'report',
      report: report,
    ));
    conversation.lastRead[doctor.email] = now;
    _notify(
      patientEmail,
      type: 'report',
      title: 'New medical report',
      body: '${report.doctorName} · ${report.hospitalLabel} sent you a '
          'medical report.',
      refId: conversation.id,
    );
    await _save();
    return report;
  }

  // ----------------------------------------------------------------- groups

  /// Can [me] see this conversation at all?
  bool canSee(Conversation conversation, AppAccount? me) {
    if (me == null) return false;
    switch (conversation.type) {
      case 'direct':
        return conversation.members.contains(me.email);
      case 'hospital':
        return isStaff(me) &&
            me.status == AccountStatus.active &&
            hospitalKey(me.hospital).isNotEmpty &&
            hospitalKey(me.hospital) == hospitalKey(conversation.hospital);
      default:
        return true;
    }
  }

  bool isMember(Conversation conversation, AppAccount? me) {
    if (me == null || !canSee(conversation, me)) return false;
    if (conversation.staffRoom) return true;
    return conversation.members.contains(me.email);
  }

  bool isLeader(Conversation conversation, AppAccount? me) =>
      me != null &&
      !conversation.staffRoom &&
      conversation.leaderEmail == me.email;

  /// Members to show for a group (staff rooms include every colleague).
  List<String> membersOf(Conversation conversation) {
    if (!conversation.staffRoom) return conversation.members;
    return _accounts
        .where((account) =>
            account.status == AccountStatus.active &&
            isStaff(account) &&
            hospitalKey(account.hospital) ==
                hospitalKey(conversation.hospital))
        .map((account) => account.email)
        .toList();
  }

  String memberName(Conversation conversation, String email) {
    final account = accountByEmail(email);
    if (account != null) return displayName(account);
    return conversation.nameOf(email);
  }

  /// Private groups of [me]'s hospital. Creates the hospital's staff room
  /// the first time someone from that hospital opens Groups.
  List<Conversation> hospitalGroupsFor(AppAccount? me) {
    if (me == null || !isStaff(me) || hospitalKey(me.hospital).isEmpty) {
      return const [];
    }
    final groups = _conversations
        .where((conversation) =>
            conversation.isHospital && canSee(conversation, me))
        .toList();
    groups.sort((a, b) {
      if (a.staffRoom != b.staffRoom) return a.staffRoom ? -1 : 1;
      return b.lastActivity.compareTo(a.lastActivity);
    });
    return groups;
  }

  Future<void> ensureStaffRoom(AppAccount? me) async {
    if (me == null ||
        !isStaff(me) ||
        me.status != AccountStatus.active ||
        hospitalKey(me.hospital).isEmpty) {
      return;
    }
    await load();
    final exists = _conversations.any((conversation) =>
        conversation.staffRoom &&
        hospitalKey(conversation.hospital) == hospitalKey(me.hospital));
    if (exists) return;
    final now = DateTime.now();
    final roomId =
        'staff_${hospitalKey(me.hospital).replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    final ref = CloudDb.instance.collection('conversations').doc(roomId);
    try {
      if ((await ref.get()).exists) return;
    } catch (_) {
      return;
    }
    _conversations.add(Conversation(
      id: roomId,
      type: 'hospital',
      title: '${me.hospital.trim()} · Staff room',
      description: 'Private group for every doctor and manager at '
          '${me.hospital.trim()}.',
      hospital: me.hospital.trim(),
      staffRoom: true,
      createdAt: now,
      messages: [
        ConnectMessage(
          id: _id(),
          senderEmail: '',
          senderName: '',
          text: 'Only doctors and managers of ${me.hospital.trim()} can see '
              'this group.',
          createdAt: now,
          kind: 'system',
        ),
      ],
    ));
    await _save();
  }

  List<Conversation> get communities => _conversations
      .where((conversation) => conversation.isCommunity)
      .toList()
    ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

  Future<Conversation> createGroup({
    required AppAccount creator,
    required String title,
    required String description,
    required bool community,
  }) async {
    await load();
    if (community && !isDoctor(creator)) {
      throw const ConnectException('Only doctors can create community groups.');
    }
    if (!community &&
        (!isStaff(creator) || hospitalKey(creator.hospital).isEmpty)) {
      throw const ConnectException(
          'Private groups are for doctors and managers with a hospital.');
    }
    final now = DateTime.now();
    final conversation = Conversation(
      id: _id(),
      type: community ? 'community' : 'hospital',
      title: title.trim(),
      description: description.trim(),
      hospital: community ? '' : creator.hospital.trim(),
      leaderEmail: creator.email,
      createdAt: now,
      members: [creator.email],
      memberNames: {creator.email: displayName(creator)},
      lastRead: {creator.email: now},
      messages: [
        ConnectMessage(
          id: _id(),
          senderEmail: '',
          senderName: '',
          text: community
              ? '${displayName(creator)} created this community'
              : '${displayName(creator)} created this private group for '
                  '${creator.hospital.trim()}',
          createdAt: now,
          kind: 'system',
        ),
      ],
    );
    _conversations.add(conversation);
    await _save();
    return conversation;
  }

  Future<void> join(Conversation conversation, AppAccount me) async {
    if (conversation.isDirect || conversation.staffRoom) return;
    if (!canSee(conversation, me)) {
      throw const ConnectException(
          'This group belongs to another hospital.');
    }
    if (conversation.members.contains(me.email)) return;
    conversation.members.add(me.email);
    conversation.memberNames[me.email] = displayName(me);
    conversation.lastRead[me.email] = DateTime.now();
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: '',
      senderName: '',
      text: '${displayName(me)} joined',
      createdAt: DateTime.now(),
      kind: 'system',
    ));
    await _save();
  }

  Future<void> leave(Conversation conversation, AppAccount me) async {
    if (conversation.isDirect || conversation.staffRoom) return;
    if (conversation.leaderEmail == me.email) {
      throw const ConnectException(
          'You lead this group. Delete it instead of leaving.');
    }
    conversation.members.remove(me.email);
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: '',
      senderName: '',
      text: '${displayName(me)} left',
      createdAt: DateTime.now(),
      kind: 'system',
    ));
    await _save();
  }

  /// Accounts the leader can add to a group.
  List<AppAccount> addableTo(Conversation conversation, AppAccount leader) {
    return _accounts
        .where((account) =>
            account.status == AccountStatus.active &&
            !conversation.members.contains(account.email) &&
            (conversation.isCommunity ||
                (isStaff(account) &&
                    hospitalKey(account.hospital) ==
                        hospitalKey(conversation.hospital))))
        .toList()
      ..sort((a, b) => displayName(a).compareTo(displayName(b)));
  }

  Future<void> addMember(
      Conversation conversation, AppAccount leader, AppAccount member) async {
    if (!isLeader(conversation, leader)) {
      throw const ConnectException('Only the group leader can add members.');
    }
    if (conversation.isHospital && !canSee(conversation, member)) {
      throw const ConnectException(
          'Only doctors and managers of this hospital can be added.');
    }
    if (conversation.members.contains(member.email)) return;
    conversation.members.add(member.email);
    conversation.memberNames[member.email] = displayName(member);
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: '',
      senderName: '',
      text: '${displayName(leader)} added ${displayName(member)}',
      createdAt: DateTime.now(),
      kind: 'system',
    ));
    _notify(
      member.email,
      type: 'group_added',
      title: 'Added to a group',
      body: '${displayName(leader)} added you to ${conversation.title}.',
      refId: conversation.id,
    );
    await _save();
  }

  Future<void> removeMember(
      Conversation conversation, AppAccount leader, String email) async {
    if (!isLeader(conversation, leader)) {
      throw const ConnectException(
          'Only the group leader can remove members.');
    }
    if (email == leader.email) return;
    if (!conversation.members.remove(email)) return;
    final name = memberName(conversation, email);
    conversation.messages.add(ConnectMessage(
      id: _id(),
      senderEmail: '',
      senderName: '',
      text: '${displayName(leader)} removed $name',
      createdAt: DateTime.now(),
      kind: 'system',
    ));
    _notify(
      email,
      type: 'group_removed',
      title: 'Removed from a group',
      body: 'You were removed from ${conversation.title}.',
      refId: conversation.id,
    );
    await _save();
  }

  Future<void> deleteGroup(Conversation conversation, AppAccount leader) async {
    if (!isLeader(conversation, leader)) {
      throw const ConnectException('Only the group leader can delete it.');
    }
    _conversations.remove(conversation);
    await _save();
  }

  /// Latest posts from community groups, for Explore.
  List<(Conversation, ConnectMessage)> communityPosts({int limit = 30}) {
    final posts = <(Conversation, ConnectMessage)>[];
    for (final conversation in communities) {
      for (final message in conversation.messages) {
        if (message.kind == 'text') posts.add((conversation, message));
      }
    }
    posts.sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    return posts.take(limit).toList();
  }

  // ---------------------------------------------------------- notifications

  /// Adds a notification and saves (for other services such as HR).
  Future<void> notify(
    String recipient, {
    required String type,
    required String title,
    required String body,
    String refId = '',
  }) async {
    await load();
    _notify(recipient, type: type, title: title, body: body, refId: refId);
    await _save();
  }

  /// Cancels a doctor's upcoming visits, e.g. when they leave the hospital.
  Future<int> cancelUpcomingVisitsOf(String doctorEmail, String reason) async {
    await load();
    var count = 0;
    for (final visit in _visits) {
      if (visit.doctorEmail != doctorEmail || !visit.isUpcoming) continue;
      visit
        ..status = VisitStatus.cancelled
        ..note = reason
        ..updatedBy = doctorEmail;
      _freeSlot(visit);
      _notify(
        visit.patientEmail,
        type: 'visit_cancelled',
        title: 'Visit cancelled',
        body: 'Your visit with ${visit.doctorName} on '
            '${fullDateTime(visit.start)} was cancelled: $reason',
        refId: visit.id,
      );
      count++;
    }
    if (count > 0) await _save();
    return count;
  }

  void _notify(
    String recipient, {
    required String type,
    required String title,
    required String body,
    String refId = '',
  }) {
    _notifications.add(ConnectNotification(
      id: _id(),
      recipient: recipient,
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      refId: refId,
    ));
  }

  List<ConnectNotification> notificationsFor(String email) => _notifications
      .where((notification) => notification.recipient == email)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadNotifications(String? email) => email == null
      ? 0
      : _notifications
          .where((notification) =>
              notification.recipient == email && !notification.read)
          .length;

  Future<void> markNotificationsRead(String email) async {
    var changed = false;
    for (final notification in _notifications) {
      // Chat requests stay unread until the doctor answers them.
      if (notification.recipient == email &&
          !notification.read &&
          notification.type != 'chat_request') {
        notification.read = true;
        changed = true;
      }
    }
    if (changed) await _save();
  }

  // ---------------------------------------------------------------- helpers

  static final _random = Random();

  static String _id() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_random.nextInt(1 << 20).toRadixString(36)}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String two(int value) => value.toString().padLeft(2, '0');

  /// "14:05" today, "Yesterday", "Mon", or "12 Oct".
  static String shortTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '${two(time.hour)}:${two(time.minute)}';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return weekdays[time.weekday - 1].substring(0, 3);
    return '${time.day} ${_months[time.month - 1]}';
  }

  static String fullDate(DateTime time) =>
      '${time.day} ${_months[time.month - 1]} ${time.year}';

  static String fullDateTime(DateTime time) =>
      '${fullDate(time)}, ${two(time.hour)}:${two(time.minute)}';
}
