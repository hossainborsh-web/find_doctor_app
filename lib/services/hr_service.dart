import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/constants/malaysia_hospitals.dart';
import '../core/domain/entities/user_role.dart';
import 'account_service.dart';
import 'cloud/fs_mirror.dart';
import 'connect_service.dart';

// ===========================================================================
// Hiring (HR)
//
// The rules:
// 1. Only Students and New Doctors can ask a hospital for work, and only with
//    a graduation certificate uploaded. At most [HrService.maxOpenRequests]
//    open requests at a time, one per hospital.
// 2. HR is a General Manager (every hospital) or a Doctor Manager (their own
//    hospital only). HR can answer requests, or offer a job to anyone in the
//    talent pool who is open to work and has a certificate.
// 3. Accepting a request or an offer sets a join day. A person can hold only
//    one join day at a time.
// 4. On or after the join day, HR completes the hiring: the person becomes a
//    Doctor at that hospital and every other open request or offer closes.
// 5. Only a General Manager can make a Doctor a Doctor Manager (or undo it).
//    Nobody can change their own role.
// ===========================================================================

enum HrStatus {
  requested('Waiting for HR'),
  offered('Offer sent'),
  scheduled('Join day set'),
  hired('Hired'),
  declined('Declined'),
  withdrawn('Withdrawn'),
  cancelled('Cancelled'),
  closed('Closed');

  const HrStatus(this.label);
  final String label;

  bool get isOpen =>
      this == requested || this == offered || this == scheduled;

  static HrStatus parse(String? name) => HrStatus.values.firstWhere(
        (value) => value.name == name,
        orElse: () => HrStatus.requested,
      );
}

/// One hiring case between a job seeker and a hospital.
class HrCase {
  HrCase({
    required this.id,
    required this.seekerEmail,
    required this.seekerName,
    required this.seekerKind,
    required this.hospital,
    required this.fromHospital,
    required this.message,
    required this.certificatePath,
    required this.createdAt,
    this.status = HrStatus.requested,
    this.joinAt,
    this.place = '',
    this.hrEmail = '',
    this.hrName = '',
    this.reply = '',
    this.note = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String seekerEmail;
  final String seekerName;

  /// 'student' or 'newDoctor'.
  final String seekerKind;
  final String hospital;

  /// True when HR offered the job from the talent pool.
  final bool fromHospital;

  /// The seeker's message (requests) or HR's message (offers).
  final String message;
  final String certificatePath;
  final DateTime createdAt;
  HrStatus status;
  DateTime? joinAt;
  String place;
  String hrEmail;
  String hrName;

  /// HR's message when accepting a request.
  String reply;

  /// Why it was declined, cancelled or closed.
  String note;
  DateTime updatedAt;

  String get kindLabel => seekerKind == DoctorKind.student.name
      ? DoctorKind.student.displayName
      : DoctorKind.newDoctor.displayName;

  /// Hiring can be completed from the start of the join day.
  bool get canComplete {
    final join = joinAt;
    if (status != HrStatus.scheduled || join == null) return false;
    final day = DateTime(join.year, join.month, join.day);
    return !DateTime.now().isBefore(day);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seekerEmail': seekerEmail,
        'seekerName': seekerName,
        'seekerKind': seekerKind,
        'hospital': hospital,
        'fromHospital': fromHospital,
        'message': message,
        'certificatePath': certificatePath,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'joinAt': joinAt?.toIso8601String(),
        'place': place,
        'hrEmail': hrEmail,
        'hrName': hrName,
        'reply': reply,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HrCase.fromJson(Map<String, dynamic> json) => HrCase(
        id: json['id'] as String,
        seekerEmail: json['seekerEmail'] as String? ?? '',
        seekerName: json['seekerName'] as String? ?? '',
        seekerKind: json['seekerKind'] as String? ?? DoctorKind.newDoctor.name,
        hospital: json['hospital'] as String? ?? '',
        fromHospital: json['fromHospital'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        certificatePath: json['certificatePath'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        status: HrStatus.parse(json['status'] as String?),
        joinAt: DateTime.tryParse(json['joinAt'] as String? ?? ''),
        place: json['place'] as String? ?? '',
        hrEmail: json['hrEmail'] as String? ?? '',
        hrName: json['hrName'] as String? ?? '',
        reply: json['reply'] as String? ?? '',
        note: json['note'] as String? ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
}

class HrException implements Exception {
  const HrException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HrService extends ChangeNotifier {
  HrService._();

  static final HrService instance = HrService._();

  /// Open requests a job seeker can have at once.
  static const maxOpenRequests = 5;

  /// How far ahead a join day can be set.
  static const maxJoinDays = 60;

  final List<HrCase> _cases = [];
  late final FsMirror<HrCase> _mirror = FsMirror<HrCase>(
    collection: 'hrCases',
    list: _cases,
    idOf: (item) => item.id,
    toJson: (item) => item.toJson(),
    fromJson: (id, json) => HrCase.fromJson({...json, 'id': id}),
    onChange: notifyListeners,
  );
  bool _attached = false;

  /// Listens to the cases [me] may see: job seekers see their own; HR sees
  /// every case, so the one-join-day and one-request-per-hospital rules hold
  /// across hospitals. HR still only acts on its own hospital's cases.
  void attach(AppAccount me) {
    _attached = true;
    final cases = CloudDb.instance.collection('hrCases');
    _mirror.listen([
      if (AccountService.isHr(me))
        cases
      else
        cases.where('seekerEmail', isEqualTo: me.email),
    ]);
  }

  void detach() {
    _attached = false;
    _mirror.listen(const []);
  }

  Future<void> load() async {
    if (_attached) await _mirror.ready;
  }

  Future<void> _save() async {
    notifyListeners();
    await _mirror.push();
  }

  // ---------------------------------------------------------------- queries

  HrCase? byId(String id) {
    for (final item in _cases) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<HrCase> _sorted(Iterable<HrCase> items) =>
      items.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<HrCase> casesForSeeker(String email) =>
      _sorted(_cases.where((item) => item.seekerEmail == email));

  /// Cases at the hospitals [hr] looks after.
  List<HrCase> casesFor(AppAccount? hr) => _sorted(_cases
      .where((item) => AccountService.hrCovers(hr, item.hospital)));

  HrCase? scheduledFor(String seekerEmail) {
    for (final item in _cases) {
      if (item.seekerEmail == seekerEmail &&
          item.status == HrStatus.scheduled) {
        return item;
      }
    }
    return null;
  }

  HrCase? openCase(String seekerEmail, String hospital) {
    final key = hospital.trim().toLowerCase();
    for (final item in _cases) {
      if (item.seekerEmail == seekerEmail &&
          item.status.isOpen &&
          item.hospital.trim().toLowerCase() == key) {
        return item;
      }
    }
    return null;
  }

  int openRequestCount(String seekerEmail) => _cases
      .where((item) =>
          item.seekerEmail == seekerEmail &&
          item.status == HrStatus.requested)
      .length;

  static bool knownHospital(String hospital) =>
      malaysiaHospitals.any((item) => item.name == hospital.trim());

  // ---------------------------------------------------------------- checks

  Future<AppAccount> _account(String email) async {
    final account = await AccountService.instance.findByEmail(email);
    if (account == null) {
      throw const HrException('This account no longer exists.');
    }
    return account;
  }

  Future<AppAccount> _hrFor(AppAccount actor, String hospital) async {
    final hr = await _account(actor.email);
    if (!AccountService.hrCovers(hr, hospital)) {
      throw HrException('You don\'t have HR permission for $hospital.');
    }
    return hr;
  }

  Future<AppAccount> _seeker(String email) async {
    final seeker = await _account(email);
    if (!seeker.isJobSeeker || seeker.status != AccountStatus.active) {
      throw HrException('${seeker.fullName} is not looking for work any more.');
    }
    return seeker;
  }

  static bool _certificateExists(AppAccount account) => account.hasCertificate;

  static void _checkJoinAt(DateTime joinAt) {
    final now = DateTime.now();
    if (joinAt.isBefore(now.add(const Duration(minutes: 30)))) {
      throw const HrException('Choose a join day and time in the future.');
    }
    if (joinAt.isAfter(now.add(const Duration(days: maxJoinDays)))) {
      throw const HrException(
          'Choose a join day within the next $maxJoinDays days.');
    }
  }

  static String _place(String place) {
    final value = place.trim();
    if (value.length < 3) {
      throw const HrException('Say where to come on the join day.');
    }
    return value;
  }

  static String _when(DateTime time) => ConnectService.fullDateTime(time);

  Future<void> _notifyHr(
    String hospital, {
    required String type,
    required String title,
    required String body,
    required String refId,
    String? except,
  }) async {
    final accounts = await AccountService.instance.accounts();
    for (final account in accounts) {
      if (account.email == except) continue;
      if (!AccountService.hrCovers(account, hospital)) continue;
      await ConnectService.instance
          .notify(account.email, type: type, title: title, body: body, refId: refId);
    }
  }

  // ------------------------------------------------------------ job seekers

  /// A Student or New Doctor asks [hospital] for work.
  Future<HrCase> sendRequest({
    required AppAccount seeker,
    required String hospital,
    String message = '',
  }) async {
    await load();
    final me = await _seeker(seeker.email);
    if (!knownHospital(hospital)) {
      throw const HrException('Choose a hospital from the list.');
    }
    if (!_certificateExists(me)) {
      throw const HrException('Upload your graduation certificate first.');
    }
    if (openCase(me.email, hospital) != null) {
      throw HrException('You already have an open request or offer with '
          '$hospital.');
    }
    final scheduled = scheduledFor(me.email);
    if (scheduled != null) {
      throw HrException('You already have a join day at '
          '${scheduled.hospital}. Finish or withdraw it first.');
    }
    if (openRequestCount(me.email) >= maxOpenRequests) {
      throw const HrException('You can have up to $maxOpenRequests open '
          'requests. Withdraw one before asking another hospital.');
    }
    final item = HrCase(
      id: _id(),
      seekerEmail: me.email,
      seekerName: me.fullName,
      seekerKind: me.doctorKind!.name,
      hospital: hospital.trim(),
      fromHospital: false,
      message: message.trim(),
      certificatePath: me.certificatePath,
      createdAt: DateTime.now(),
    );
    _cases.add(item);
    await _save();
    await _notifyHr(item.hospital,
        type: 'hr_request',
        title: 'New work request',
        body: '${item.seekerName} (${item.kindLabel}) asks to work at '
            '${item.hospital}.',
        refId: item.id);
    return item;
  }

  /// The seeker accepts or declines a job offer.
  Future<void> respondToOffer({
    required AppAccount seeker,
    required String caseId,
    required bool accept,
  }) async {
    await load();
    final item = byId(caseId);
    if (item == null ||
        item.seekerEmail != seeker.email ||
        item.status != HrStatus.offered) {
      throw const HrException('This offer is no longer available.');
    }
    final me = await _seeker(seeker.email);
    if (accept) {
      final join = item.joinAt;
      if (join == null || !join.isAfter(DateTime.now())) {
        throw const HrException('The join day of this offer has passed. Ask '
            'the hospital to set a new date.');
      }
      final other = scheduledFor(me.email);
      if (other != null) {
        throw HrException('You already have a join day at ${other.hospital}. '
            'Withdraw it before accepting another offer.');
      }
      item.status = HrStatus.scheduled;
    } else {
      item
        ..status = HrStatus.declined
        ..note = 'Declined by ${me.fullName}';
    }
    item.updatedAt = DateTime.now();
    await _save();
    await _notifyHr(item.hospital,
        type: accept ? 'hr_offer_accepted' : 'hr_offer_declined',
        title: accept ? 'Offer accepted' : 'Offer declined',
        body: accept
            ? '${item.seekerName} accepted. Join day: ${_when(item.joinAt!)} '
                'at ${item.place}.'
            : '${item.seekerName} declined the offer from ${item.hospital}.',
        refId: item.id);
  }

  /// The seeker withdraws a request, or backs out of an offer or join day.
  Future<void> withdraw({
    required AppAccount seeker,
    required String caseId,
  }) async {
    await load();
    final item = byId(caseId);
    if (item == null ||
        item.seekerEmail != seeker.email ||
        !item.status.isOpen) {
      throw const HrException('This request is no longer open.');
    }
    item
      ..status = HrStatus.withdrawn
      ..note = 'Withdrawn by ${item.seekerName}'
      ..updatedAt = DateTime.now();
    await _save();
    await _notifyHr(item.hospital,
        type: 'hr_withdrawn',
        title: 'Request withdrawn',
        body: '${item.seekerName} withdrew from ${item.hospital}.',
        refId: item.id);
  }

  // -------------------------------------------------------------------- HR

  /// HR offers a job to someone from the talent pool, with a join day.
  Future<HrCase> sendOffer({
    required AppAccount actor,
    required String seekerEmail,
    required String hospital,
    required DateTime joinAt,
    required String place,
    String message = '',
  }) async {
    await load();
    if (!knownHospital(hospital)) {
      throw const HrException('Choose a hospital from the list.');
    }
    final hr = await _hrFor(actor, hospital);
    final seeker = await _seeker(seekerEmail);
    if (seeker.email == hr.email) {
      throw const HrException('You can\'t hire yourself.');
    }
    if (!seeker.openToWork) {
      throw HrException('${seeker.fullName} is not open to work right now.');
    }
    if (!_certificateExists(seeker)) {
      throw HrException('${seeker.fullName} hasn\'t uploaded a graduation '
          'certificate yet.');
    }
    if (openCase(seeker.email, hospital) != null) {
      throw HrException('There is already an open request or offer between '
          '${seeker.fullName} and $hospital.');
    }
    final scheduled = scheduledFor(seeker.email);
    if (scheduled != null) {
      throw HrException('${seeker.fullName} already has a join day at '
          '${scheduled.hospital}.');
    }
    _checkJoinAt(joinAt);
    final item = HrCase(
      id: _id(),
      seekerEmail: seeker.email,
      seekerName: seeker.fullName,
      seekerKind: seeker.doctorKind!.name,
      hospital: hospital.trim(),
      fromHospital: true,
      message: message.trim(),
      certificatePath: seeker.certificatePath,
      createdAt: DateTime.now(),
      status: HrStatus.offered,
      joinAt: joinAt,
      place: _place(place),
      hrEmail: hr.email,
      hrName: hr.fullName,
    );
    _cases.add(item);
    await _save();
    await ConnectService.instance.notify(seeker.email,
        type: 'hr_offer',
        title: 'Job offer from ${item.hospital}',
        body: 'Join day ${_when(joinAt)} at ${item.place}. Open My career to '
            'accept or decline.',
        refId: item.id);
    return item;
  }

  /// HR accepts a request and sets the join day.
  Future<void> acceptRequest({
    required AppAccount actor,
    required String caseId,
    required DateTime joinAt,
    required String place,
    String reply = '',
  }) async {
    await load();
    final item = byId(caseId);
    if (item == null || item.status != HrStatus.requested) {
      throw const HrException('This request is no longer waiting.');
    }
    final hr = await _hrFor(actor, item.hospital);
    if (item.seekerEmail == hr.email) {
      throw const HrException('You can\'t hire yourself.');
    }
    final seeker = await _seeker(item.seekerEmail);
    final other = scheduledFor(seeker.email);
    if (other != null) {
      throw HrException('${seeker.fullName} already has a join day at '
          '${other.hospital}.');
    }
    _checkJoinAt(joinAt);
    item
      ..status = HrStatus.scheduled
      ..joinAt = joinAt
      ..place = _place(place)
      ..reply = reply.trim()
      ..hrEmail = hr.email
      ..hrName = hr.fullName
      ..updatedAt = DateTime.now();
    await _save();
    await ConnectService.instance.notify(seeker.email,
        type: 'hr_accepted',
        title: '${item.hospital} accepted your request',
        body: 'Your join day: ${_when(joinAt)} at ${item.place}.',
        refId: item.id);
  }

  Future<void> declineRequest({
    required AppAccount actor,
    required String caseId,
    String reason = '',
  }) async {
    await load();
    final item = byId(caseId);
    if (item == null || item.status != HrStatus.requested) {
      throw const HrException('This request is no longer waiting.');
    }
    final hr = await _hrFor(actor, item.hospital);
    item
      ..status = HrStatus.declined
      ..note = reason.trim()
      ..hrEmail = hr.email
      ..hrName = hr.fullName
      ..updatedAt = DateTime.now();
    await _save();
    await ConnectService.instance.notify(item.seekerEmail,
        type: 'hr_declined',
        title: '${item.hospital} declined your request',
        body: item.note.isEmpty
            ? 'You can ask other hospitals for work.'
            : item.note,
        refId: item.id);
  }

  /// HR moves the join day of an offer or a scheduled hiring.
  Future<void> reschedule({
    required AppAccount actor,
    required String caseId,
    required DateTime joinAt,
    required String place,
  }) async {
    await load();
    final item = byId(caseId);
    if (item == null ||
        (item.status != HrStatus.offered &&
            item.status != HrStatus.scheduled)) {
      throw const HrException('This join day can no longer be changed.');
    }
    final hr = await _hrFor(actor, item.hospital);
    _checkJoinAt(joinAt);
    item
      ..joinAt = joinAt
      ..place = _place(place)
      ..hrEmail = hr.email
      ..hrName = hr.fullName
      ..updatedAt = DateTime.now();
    await _save();
    await ConnectService.instance.notify(item.seekerEmail,
        type: 'hr_rescheduled',
        title: 'New join day at ${item.hospital}',
        body: '${_when(joinAt)} at ${item.place}.',
        refId: item.id);
  }

  /// HR cancels an offer or a scheduled hiring.
  Future<void> cancel({
    required AppAccount actor,
    required String caseId,
    String reason = '',
  }) async {
    await load();
    final item = byId(caseId);
    if (item == null ||
        (item.status != HrStatus.offered &&
            item.status != HrStatus.scheduled)) {
      throw const HrException('This can no longer be cancelled.');
    }
    final hr = await _hrFor(actor, item.hospital);
    item
      ..status = HrStatus.cancelled
      ..note = reason.trim()
      ..hrEmail = hr.email
      ..hrName = hr.fullName
      ..updatedAt = DateTime.now();
    await _save();
    await ConnectService.instance.notify(item.seekerEmail,
        type: 'hr_cancelled',
        title: '${item.hospital} cancelled the hiring',
        body: item.note.isEmpty
            ? 'You can ask other hospitals for work.'
            : item.note,
        refId: item.id);
  }

  /// On or after the join day: the person becomes a Doctor at the hospital
  /// and every other open request or offer of theirs closes.
  Future<AppAccount> completeHiring({
    required AppAccount actor,
    required String caseId,
  }) async {
    await load();
    final item = byId(caseId);
    if (item == null || item.status != HrStatus.scheduled) {
      throw const HrException('This hiring is not waiting to be completed.');
    }
    final hr = await _hrFor(actor, item.hospital);
    if (!item.canComplete) {
      throw HrException('You can complete the hiring on or after the join '
          'day (${ConnectService.fullDate(item.joinAt!)}).');
    }
    final doctor = await _wrap(() => AccountService.instance.hire(
        seekerEmail: item.seekerEmail, hospital: item.hospital, actor: hr));
    final now = DateTime.now();
    item
      ..status = HrStatus.hired
      ..hrEmail = hr.email
      ..hrName = hr.fullName
      ..updatedAt = now;
    final closed = <HrCase>[];
    for (final other in _cases) {
      if (other.id == item.id ||
          other.seekerEmail != item.seekerEmail ||
          !other.status.isOpen) {
        continue;
      }
      other
        ..status = HrStatus.closed
        ..note = 'Hired by ${item.hospital}'
        ..updatedAt = now;
      closed.add(other);
    }
    await _save();
    await ConnectService.instance.refresh();
    await ConnectService.instance.notify(doctor.email,
        type: 'hr_hired',
        title: 'Welcome to ${item.hospital}',
        body: 'You are now a Doctor at ${item.hospital}. Set your weekly '
            'schedule so users can book visits with you.',
        refId: item.id);
    for (final other in closed) {
      await _notifyHr(other.hospital,
          type: 'hr_closed',
          title: 'Request closed',
          body: '${other.seekerName} was hired by ${item.hospital}.',
          refId: other.id);
    }
    return doctor;
  }

  /// HR ends a doctor's work at the hospital; their upcoming visits are
  /// cancelled and they become a New Doctor looking for work.
  Future<AppAccount> endEmployment({
    required AppAccount actor,
    required String doctorEmail,
  }) async {
    final before = await AccountService.instance.findByEmail(doctorEmail);
    final hospital = before?.hospital ?? '';
    final account = await _wrap(() => AccountService.instance
        .endEmployment(targetEmail: doctorEmail, actor: actor));
    await ConnectService.instance.cancelUpcomingVisitsOf(
        account.email, 'the doctor no longer works at $hospital');
    await ConnectService.instance.refresh();
    await ConnectService.instance.notify(account.email,
        type: 'hr_role',
        title: 'Your work at $hospital has ended',
        body: 'You are now a New Doctor and can ask other hospitals for work.');
    notifyListeners();
    return account;
  }

  /// General Manager only: gives or removes Doctor Manager permission.
  Future<AppAccount> setDoctorManager({
    required AppAccount actor,
    required String doctorEmail,
    required bool grant,
  }) async {
    final account = await _wrap(() => AccountService.instance
        .setDoctorManager(targetEmail: doctorEmail, actor: actor, grant: grant));
    await ConnectService.instance.refresh();
    await ConnectService.instance.notify(account.email,
        type: 'hr_role',
        title: grant
            ? 'You are now a Doctor Manager'
            : 'Doctor Manager permission removed',
        body: grant
            ? 'You can now hire and manage doctors at ${account.hospital}. '
                'Sign in again to open the manager workspace.'
            : 'You are a Doctor at ${account.hospital}. Sign in again to '
                'refresh your workspace.');
    notifyListeners();
    return account;
  }

  // ---------------------------------------------------------------- helpers

  /// Runs an AccountService rule check and reports it as an HR error.
  static Future<T> _wrap<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AccountException catch (error) {
      throw HrException(error.message);
    }
  }

  static final _random = Random();

  static String _id() =>
      'hr${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_random.nextInt(1 << 20).toRadixString(36)}';
}
