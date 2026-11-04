import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../account_service.dart';
import '../connect_service.dart';
import 'cloud_db.dart';
import 'supabase_api.dart';

// ===========================================================================
// Demo examples for teachers
//
// A General Manager can load a set of fictional people (emails end in
// @example.com, so they can never reach a real person) that show every part
// of the app: users with visits and chats, doctors, Doctor Managers, and
// Students / New Doctors at each hiring stage. Each demo person signs up and
// writes their own data with their own account, so every security rule is
// exercised exactly as it is for real people. The General Manager does the
// HR steps (hiring, Doctor Manager permission) with their own account.
// ===========================================================================

enum DemoKind { user, student, newDoctor, doctor, doctorManager }

class DemoPerson {
  const DemoPerson({
    required this.key,
    required this.name,
    required this.email,
    required this.kind,
    required this.shows,
    this.hospital = '',
    this.specialty = '',
    this.university = '',
    this.graduationYear = '',
    this.previousHospital = '',
    this.birthday = '',
    this.hiredFromStudent = false,
  });

  final String key;
  final String name;
  final String email;
  final DemoKind kind;

  /// What this account demonstrates, for the teachers' tour.
  final String shows;
  final String hospital;
  final String specialty;
  final String university;
  final String graduationYear;
  final String previousHospital;
  final String birthday;

  /// Doctors hired straight after graduating (were Students before).
  final bool hiredFromStudent;

  String get typeLabel {
    switch (kind) {
      case DemoKind.user:
        return 'User';
      case DemoKind.student:
        return 'Student';
      case DemoKind.newDoctor:
        return 'New Doctor';
      case DemoKind.doctor:
        return 'Doctor';
      case DemoKind.doctorManager:
        return 'Doctor Manager';
    }
  }

  bool get practises =>
      kind == DemoKind.doctor || kind == DemoKind.doctorManager;

  /// What they signed up as (doctors were hired later through HR).
  String get signUpKind {
    switch (kind) {
      case DemoKind.user:
        return '';
      case DemoKind.student:
        return 'student';
      case DemoKind.newDoctor:
        return 'newDoctor';
      case DemoKind.doctor:
      case DemoKind.doctorManager:
        return hiredFromStudent ? 'student' : 'newDoctor';
    }
  }

  String get doctorName => 'Dr. $name';
}

class DemoInfo {
  const DemoInfo({
    required this.password,
    required this.status,
    this.loadedAt,
    this.loadedBy = '',
  });

  final String password;

  /// "loading" or "done".
  final String status;
  final DateTime? loadedAt;
  final String loadedBy;

  bool get isDone => status == 'done';
}

class DemoException implements Exception {
  const DemoException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DemoSeeder {
  DemoSeeder._();

  static final DemoSeeder instance = DemoSeeder._();

  static const hkl = 'Hospital Kuala Lumpur';
  static const ummc = 'University Malaya Medical Centre (UMMC)';

  static const people = <DemoPerson>[
    DemoPerson(
      key: 'aisyah',
      name: 'Aisyah Rahman',
      email: 'aisyah.user@example.com',
      kind: DemoKind.user,
      birthday: '1994-03-12',
      shows: 'A user: a confirmed visit with Dr. Farid, a chat with a '
          'medical report, and the Heart Health Circle community.',
    ),
    DemoPerson(
      key: 'daniel',
      name: 'Daniel Lim',
      email: 'daniel.user@example.com',
      kind: DemoKind.user,
      birthday: '1988-07-25',
      shows: 'A user waiting for answers: a visit request to Dr. Mei Ling and '
          'a chat request to Dr. Arjun.',
    ),
    DemoPerson(
      key: 'priya',
      name: 'Priya Nair',
      email: 'priya.user@example.com',
      kind: DemoKind.user,
      birthday: '1979-11-02',
      shows: 'A user with a completed visit (visit history).',
    ),
    DemoPerson(
      key: 'farid',
      name: 'Farid Hassan',
      email: 'farid.doctor@example.com',
      kind: DemoKind.doctorManager,
      hospital: hkl,
      specialty: 'Cardiology',
      previousHospital: 'Hospital Pulau Pinang',
      birthday: '1980-01-20',
      shows: 'Doctor Manager (HR) of Hospital Kuala Lumpur: a work request '
          'waiting, a join day set, staff, visits and the staff room.',
    ),
    DemoPerson(
      key: 'meiling',
      name: 'Mei Ling Tan',
      email: 'meiling.doctor@example.com',
      kind: DemoKind.doctor,
      hospital: hkl,
      specialty: 'Paediatrics',
      previousHospital: 'Hospital Sultanah Aminah',
      birthday: '1987-05-09',
      shows: 'A doctor with a visit request to confirm or decline, and a '
          'health post in Explore.',
    ),
    DemoPerson(
      key: 'arjun',
      name: 'Arjun Kumar',
      email: 'arjun.doctor@example.com',
      kind: DemoKind.doctorManager,
      hospital: ummc,
      specialty: 'Orthopaedics',
      previousHospital: 'Hospital Raja Permaisuri Bainun',
      birthday: '1983-09-14',
      shows: 'Doctor Manager (HR) of UMMC: an offer sent to a New Doctor, a '
          'declined request, and a chat request to answer.',
    ),
    DemoPerson(
      key: 'nurul',
      name: 'Nurul Izzah Ahmad',
      email: 'nurul.doctor@example.com',
      kind: DemoKind.doctor,
      hospital: ummc,
      specialty: 'General Medicine',
      university: 'Universiti Malaya',
      graduationYear: '2024',
      hiredFromStudent: true,
      birthday: '1999-02-27',
      shows: 'Was a Student, hired by UMMC (see hiring history). Has a '
          'completed visit.',
    ),
    DemoPerson(
      key: 'hakim',
      name: 'Hakim Zulkifli',
      email: 'hakim.student@example.com',
      kind: DemoKind.student,
      university: 'Universiti Kebangsaan Malaysia',
      graduationYear: '2025',
      birthday: '2000-06-18',
      shows: 'A Student whose work request to Hospital Kuala Lumpur is '
          'waiting for HR.',
    ),
    DemoPerson(
      key: 'sarah',
      name: 'Sarah Ong',
      email: 'sarah.student@example.com',
      kind: DemoKind.student,
      university: 'Universiti Sains Malaysia',
      graduationYear: '2025',
      birthday: '2000-10-03',
      shows: 'A Student accepted by Hospital Kuala Lumpur, with a join day '
          'appointment.',
    ),
    DemoPerson(
      key: 'ravi',
      name: 'Ravi Menon',
      email: 'ravi.newdoctor@example.com',
      kind: DemoKind.newDoctor,
      specialty: 'Emergency Medicine',
      previousHospital: 'Hospital Sultanah Aminah',
      birthday: '1990-04-30',
      shows: 'A New Doctor (from another hospital) with a job offer from UMMC '
          'to accept or decline in My career.',
    ),
    DemoPerson(
      key: 'siti',
      name: 'Siti Aminah Yusof',
      email: 'siti.newdoctor@example.com',
      kind: DemoKind.newDoctor,
      specialty: 'Dermatology',
      previousHospital: 'Hospital Pulau Pinang',
      birthday: '1992-12-08',
      shows: 'A New Doctor whose request was declined; still open to work in '
          'the talent pool.',
    ),
    DemoPerson(
      key: 'weijie',
      name: 'Wei Jie Chong',
      email: 'weijie.student@example.com',
      kind: DemoKind.student,
      university: 'International Medical University',
      graduationYear: '2026',
      birthday: '2001-08-21',
      shows: 'A Student in the talent pool with no requests yet: HR can send '
          'an offer.',
    ),
  ];

  static DemoPerson person(String key) =>
      people.firstWhere((person) => person.key == key);

  DocumentReference get _infoRef =>
      CloudDb.instance.collection('demo').doc('info');

  /// What was loaded before (General Managers only).
  Future<DemoInfo?> info() async {
    try {
      final doc = await _infoRef.get();
      final data = doc.data();
      if (data == null) return null;
      return DemoInfo(
        password: data['password'] as String? ?? '',
        status: data['status'] as String? ?? 'loading',
        loadedAt: DateTime.tryParse(data['loadedAt'] as String? ?? ''),
        loadedBy: data['loadedBy'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  bool _running = false;

  /// Creates every demo person and example. Safe to run again after a
  /// failure: finished steps are skipped.
  Future<DemoInfo> load({required void Function(String step) onStep}) async {
    if (_running) throw const DemoException('Already loading.');
    _running = true;
    try {
      return await _load(onStep);
    } on DemoException {
      rethrow;
    } on CloudDbException catch (error) {
      throw DemoException(error.message);
    } on CloudAuthException catch (error) {
      throw DemoException(error.message ?? error.code);
    } on TimeoutException {
      throw const DemoException(
          'The connection timed out. Check the internet and try again.');
    } catch (error) {
      throw DemoException('$error');
    } finally {
      _running = false;
    }
  }

  Future<DemoInfo> _load(void Function(String step) onStep) async {
    final me = AccountService.instance.currentAccount;
    if (!AccountService.isGeneralManager(me)) {
      throw const DemoException(
          'Only a General Manager can load the demo examples.');
    }
    final gm = me!;
    final rest = _Rest();
    const db = CloudDb.instance;

    // 1. The shared demo password (kept so a retry can sign back in).
    onStep('Preparing');
    final previous = await info();
    if (previous != null && previous.isDone) return previous;
    final password = previous?.password.isNotEmpty == true
        ? previous!.password
        : 'Demo${1000 + Random.secure().nextInt(9000)}!';
    await _infoRef.set({
      'password': password,
      'status': 'loading',
      'loadedBy': gm.email,
      'accounts': [
        for (final person in people)
          {
            'name': person.name,
            'email': person.email,
            'type': person.typeLabel,
            'hospital': person.hospital,
          },
      ],
    });

    // 2. Accounts and profiles, each written by the person themselves.
    final s = <String, _Session>{};
    final profiles = <String, Map<String, dynamic>>{};
    for (final person in people) {
      onStep('Creating ${person.name} (${person.typeLabel})');
      final session = await rest.signUpOrIn(
          person.email,
          password,
          person.practises ? person.doctorName : person.name,
          _profile(person, '')..remove('id'));
      s[person.key] = session;
      final path = 'users/${session.uid}';
      var profile = await rest.get(session, path);
      if (profile == null) {
        profile = _profile(person, session.uid);
        await rest.set(session, path, profile);
      }
      profiles[person.key] = profile;
    }

    // 3. Graduation certificates for everyone who went through hiring.
    for (final person in people) {
      if (person.kind == DemoKind.user) continue;
      final profile = profiles[person.key]!;
      if ((profile['certificatePath'] as String? ?? '').isNotEmpty) continue;
      onStep('Certificate for ${person.name}');
      final session = s[person.key]!;
      final jpeg = await compute(_drawCertificate, [
        person.name,
        person.university.isNotEmpty
            ? person.university
            : 'Universiti Malaya',
        person.graduationYear.isNotEmpty ? person.graduationYear : '2016',
      ]);
      final mediaId = 'demo_cert_${person.key}';
      if (await rest.get(session, 'media/$mediaId') == null) {
        await rest.set(session, 'media/$mediaId', {
          'owner': session.uid,
          'mime': 'image/jpeg',
          'data': base64Encode(jpeg),
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      await rest.update(session, 'users/${session.uid}',
          {'certificatePath': 'media:$mediaId'});
      profile['certificatePath'] = 'media:$mediaId';
    }

    final now = DateTime.now();
    DateTime daysAgo(int days, [int hour = 9]) {
      final day = now.subtract(Duration(days: days));
      return DateTime(day.year, day.month, day.day, hour);
    }

    // 4. Doctors: each asked a hospital for work and was hired by HR.
    for (final person in people.where((person) => person.practises)) {
      final session = s[person.key]!;
      final profile = profiles[person.key]!;
      final caseId = 'demo_hr_${person.key}';
      onStep('Hiring history of ${person.doctorName}');
      if (await rest.get(session, 'hrCases/$caseId') == null) {
        await rest.set(session, 'hrCases/$caseId', _hrCase(
          id: caseId,
          seeker: person,
          certificate: profile['certificatePath'] as String,
          hospital: person.hospital,
          status: 'requested',
          message: 'I would like to join the ${person.specialty} team.',
          createdAt: daysAgo(30),
        ));
      }
      final caseRef = db.collection('hrCases').doc(caseId);
      final hrCase = (await caseRef.get()).data();
      if (hrCase?['status'] == 'requested') {
        await caseRef.update({
          'status': 'hired',
          'joinAt': daysAgo(14).toIso8601String(),
          'place': 'HR office, Level 2',
          'hrEmail': gm.email,
          'hrName': gm.fullName,
          'reply': 'Welcome to ${person.hospital}.',
          'updatedAt': daysAgo(14, 10).toIso8601String(),
        });
      }
      final userRef = db.collection('users').doc(session.uid);
      var user = (await userRef.get()).data() ?? profile;
      if (user['doctorKind'] == 'student' || user['doctorKind'] == 'newDoctor') {
        onStep('Hiring ${person.doctorName} at ${person.hospital}');
        await userRef.update({
          'role': 'doctor',
          'doctorKind': 'doctor',
          'managerLevel': null,
          'hospital': person.hospital,
          'openToWork': false,
          'hiredBy': gm.fullName,
          'hiredAt': daysAgo(14, 10).toIso8601String(),
        });
        user = {...user, 'doctorKind': 'doctor'};
      }
      if (person.kind == DemoKind.doctorManager &&
          user['doctorKind'] != 'doctorManager') {
        onStep('Making ${person.doctorName} a Doctor Manager');
        await userRef.update({'doctorKind': 'doctorManager'});
      }
      await rest.set(session, 'schedules/${person.email}', {
        'email': person.email,
        'days': [
          for (final day in ConnectService.defaultSchedule()) day.toJson(),
        ],
      });
    }

    // 5. Hiring examples at every stage.
    onStep('Work requests, join days and offers');
    final farid = person('farid');
    final arjun = person('arjun');
    Future<void> seekerCase(String key, String hospital, String message,
        {required int daysOld}) async {
      final seeker = person(key);
      final session = s[key]!;
      final caseId = 'demo_hr_$key';
      if (await rest.get(session, 'hrCases/$caseId') != null) return;
      await rest.set(session, 'hrCases/$caseId', _hrCase(
        id: caseId,
        seeker: seeker,
        certificate: profiles[key]!['certificatePath'] as String,
        hospital: hospital,
        status: 'requested',
        message: message,
        createdAt: daysAgo(daysOld, 15),
      ));
      for (final hr in [farid, arjun, null]) {
        if (hr != null && hr.hospital != hospital) continue;
        await rest.set(session, 'notifications/demo_n_${key}_${hr?.key ?? 'gm'}', {
          'id': 'demo_n_${key}_${hr?.key ?? 'gm'}',
          'recipient': hr?.email ?? gm.email,
          'type': 'hr_request',
          'title': 'New work request',
          'body': '${seeker.name} (${seeker.typeLabel}) asks to work at '
              '$hospital.',
          'createdAt': daysAgo(daysOld, 15).toIso8601String(),
          'read': false,
          'refId': caseId,
        });
      }
    }

    // Hakim: waiting for HR at Hospital Kuala Lumpur.
    await seekerCase('hakim', hkl,
        'I graduated in 2025 and would love to start my housemanship here.',
        daysOld: 1);

    // Sarah: accepted by Dr. Farid, join day in a few days.
    await seekerCase('sarah', hkl,
        'Fresh graduate, interested in paediatrics and emergency.',
        daysOld: 4);
    final joinDay = _nextWeekday(now.add(const Duration(days: 3)), 9);
    final sarahCase = await rest.get(s['farid']!, 'hrCases/demo_hr_sarah');
    if (sarahCase?['status'] == 'requested') {
      await rest.update(s['farid']!, 'hrCases/demo_hr_sarah', {
        'status': 'scheduled',
        'joinAt': joinDay.toIso8601String(),
        'place': 'HR office, Block A, Level 1',
        'reply': 'Please bring your original certificate and IC.',
        'hrEmail': farid.email,
        'hrName': farid.doctorName,
        'updatedAt': daysAgo(2, 11).toIso8601String(),
      });
      await rest.set(s['farid']!, 'notifications/demo_n_sarah_join', {
        'id': 'demo_n_sarah_join',
        'recipient': person('sarah').email,
        'type': 'hr_accepted',
        'title': '$hkl accepted your request',
        'body': 'Your join day: ${ConnectService.fullDateTime(joinDay)} at '
            'HR office, Block A, Level 1.',
        'createdAt': daysAgo(2, 11).toIso8601String(),
        'read': false,
        'refId': 'demo_hr_sarah',
      });
    }

    // Siti: asked UMMC, declined by Dr. Arjun; still open to work.
    await seekerCase('siti', ummc,
        'Dermatologist with 6 years of experience, ready to start next month.',
        daysOld: 6);
    final sitiCase = await rest.get(s['arjun']!, 'hrCases/demo_hr_siti');
    if (sitiCase?['status'] == 'requested') {
      await rest.update(s['arjun']!, 'hrCases/demo_hr_siti', {
        'status': 'declined',
        'note': 'We have no dermatology opening this month. Please try again '
            'in March.',
        'hrEmail': arjun.email,
        'hrName': arjun.doctorName,
        'updatedAt': daysAgo(3, 16).toIso8601String(),
      });
      await rest.set(s['arjun']!, 'notifications/demo_n_siti_declined', {
        'id': 'demo_n_siti_declined',
        'recipient': person('siti').email,
        'type': 'hr_declined',
        'title': '$ummc declined your request',
        'body': 'We have no dermatology opening this month.',
        'createdAt': daysAgo(3, 16).toIso8601String(),
        'read': false,
        'refId': 'demo_hr_siti',
      });
    }

    // Ravi: UMMC offers him a job from the talent pool.
    final offerDay = _nextWeekday(now.add(const Duration(days: 5)), 9);
    if (await rest.get(s['arjun']!, 'hrCases/demo_hr_ravi') == null) {
      final ravi = person('ravi');
      await rest.set(s['arjun']!, 'hrCases/demo_hr_ravi', {
        ..._hrCase(
          id: 'demo_hr_ravi',
          seeker: ravi,
          certificate: profiles['ravi']!['certificatePath'] as String,
          hospital: ummc,
          status: 'offered',
          message: 'Our emergency department needs an experienced doctor. '
              'Would you like to join us?',
          createdAt: daysAgo(1, 10),
        ),
        'fromHospital': true,
        'joinAt': offerDay.toIso8601String(),
        'place': 'Emergency Department office',
        'hrEmail': arjun.email,
        'hrName': arjun.doctorName,
      });
      await rest.set(s['arjun']!, 'notifications/demo_n_ravi_offer', {
        'id': 'demo_n_ravi_offer',
        'recipient': ravi.email,
        'type': 'hr_offer',
        'title': 'Job offer from $ummc',
        'body': 'Join day ${ConnectService.fullDateTime(offerDay)} at '
            'Emergency Department office. Open My career to accept or '
            'decline.',
        'createdAt': daysAgo(1, 10).toIso8601String(),
        'read': false,
        'refId': 'demo_hr_ravi',
      });
    }

    // 6. Visits.
    onStep('Visits');
    final day1 = _nextWeekday(now.add(const Duration(days: 1)), 10);
    final day2 = _nextWeekday(day1.add(const Duration(days: 1)), 14, 30);
    await _visit(rest, s,
        id: 'demo_visit_1',
        patient: person('aisyah'),
        doctor: farid,
        start: day1,
        reason: 'Chest tightness when climbing stairs',
        finalStatus: 'confirmed',
        createdAt: daysAgo(2, 20));
    await _visit(rest, s,
        id: 'demo_visit_2',
        patient: person('daniel'),
        doctor: person('meiling'),
        start: day2,
        reason: 'My son has had a fever for two days',
        finalStatus: 'requested',
        createdAt: daysAgo(0, 8));
    await _visit(rest, s,
        id: 'demo_visit_3',
        patient: person('priya'),
        doctor: person('nurul'),
        start: _previousWeekday(now.subtract(const Duration(days: 6)), 11),
        reason: 'Blood pressure follow-up',
        finalStatus: 'completed',
        createdAt: daysAgo(9, 19));

    // 7. Chats.
    onStep('Chats and groups');
    await _chats(rest, s, now);

    // 8. Explore posts by demo doctors.
    onStep('Health posts');
    await _posts(rest, s, now);

    // 9. Hospital stock.
    onStep('Hospital stock');
    final stock = <(String, String, String, int, String)>[
      (hkl, 'Paracetamol 500mg', 'Medication', 240, 'tablets'),
      (hkl, 'Amoxicillin 250mg', 'Medication', 14, 'boxes'),
      (hkl, 'Insulin pen', 'Medication', 6, 'pens'),
      (hkl, 'Surgical masks', 'PPE & Consumables', 120, 'boxes'),
      (hkl, 'ECG machine', 'Equipment', 4, 'units'),
      (ummc, 'Ibuprofen 400mg', 'Medication', 180, 'tablets'),
      (ummc, 'Saline 0.9% 500ml', 'Medication', 18, 'bags'),
      (ummc, 'Nitrile gloves', 'PPE & Consumables', 8, 'boxes'),
      (ummc, 'Wheelchair', 'Equipment', 22, 'units'),
    ];
    for (var i = 0; i < stock.length; i++) {
      final (hospital, name, category, count, unit) = stock[i];
      final id = 'demo_inv_$i';
      await db.collection('inventory').doc(id).set({
        'id': id,
        'hospital': hospital,
        'name': name,
        'category': category,
        'stock': count,
        'unit': unit,
        'status': count < 10
            ? 'Critical'
            : (count < 20 ? 'Low Stock' : 'In Stock'),
        'expiryDate': category == 'Medication'
            ? DateTime(now.year + 1, (i % 12) + 1, 28)
                .toIso8601String()
                .substring(0, 10)
            : '',
      });
    }

    // 10. Done.
    final loadedAt = DateTime.now();
    await _infoRef.update({
      'status': 'done',
      'loadedAt': loadedAt.toIso8601String(),
    });
    onStep('Done');
    unawaited(ConnectService.instance.refresh());
    return DemoInfo(
        password: password,
        status: 'done',
        loadedAt: loadedAt,
        loadedBy: gm.email);
  }

  // ------------------------------------------------------------ helpers

  static Map<String, dynamic> _profile(DemoPerson person, String uid) {
    final kind = person.signUpKind;
    return {
      'id': uid,
      'fullName': person.name,
      'email': person.email,
      'role': kind.isEmpty ? 'patient' : 'doctor',
      'doctorKind': kind.isEmpty ? null : kind,
      'managerLevel': null,
      'hospital': '',
      'specialty': person.specialty,
      'birthday': person.birthday,
      'status': 'active',
      'reviewedBy': null,
      'reviewedAt': null,
      'documentName': null,
      'createdAt': DateTime.now()
          .subtract(const Duration(days: 40))
          .toIso8601String(),
      'university': person.university,
      'graduationYear': person.graduationYear,
      'previousHospital': person.previousHospital,
      'certificatePath': '',
      'openToWork': kind.isNotEmpty,
      'hiredBy': '',
      'hiredAt': null,
      'demo': true,
    };
  }

  static Map<String, dynamic> _hrCase({
    required String id,
    required DemoPerson seeker,
    required String certificate,
    required String hospital,
    required String status,
    required String message,
    required DateTime createdAt,
  }) =>
      {
        'id': id,
        'seekerEmail': seeker.email,
        'seekerName': seeker.name,
        'seekerKind': seeker.signUpKind,
        'hospital': hospital,
        'fromHospital': false,
        'message': message,
        'certificatePath': certificate,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'joinAt': null,
        'place': '',
        'hrEmail': '',
        'hrName': '',
        'reply': '',
        'note': '',
        'updatedAt': createdAt.toIso8601String(),
      };

  static DateTime _nextWeekday(DateTime from, int hour, [int minute = 0]) {
    var day = DateTime(from.year, from.month, from.day, hour, minute);
    while (day.weekday > DateTime.friday) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  static DateTime _previousWeekday(DateTime from, int hour) {
    var day = DateTime(from.year, from.month, from.day, hour);
    while (day.weekday > DateTime.friday) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }

  Future<void> _visit(
    _Rest rest,
    Map<String, _Session> s, {
    required String id,
    required DemoPerson patient,
    required DemoPerson doctor,
    required DateTime start,
    required String reason,
    required String finalStatus,
    required DateTime createdAt,
  }) async {
    final ps = s[patient.key]!;
    final ds = s[doctor.key]!;
    if (await rest.get(ps, 'visits/$id') != null) return;
    await rest.set(ps, 'visits/$id', {
      'id': id,
      'code': 'V-${100000 + id.hashCode.abs() % 900000}',
      'patientEmail': patient.email,
      'patientName': patient.name,
      'doctorEmail': doctor.email,
      'doctorName': doctor.doctorName,
      'doctorType': doctor.typeLabel,
      'specialty': doctor.specialty,
      'hospital': doctor.hospital,
      'start': start.toIso8601String(),
      'minutes': 30,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'status': 'requested',
      'note': '',
      'updatedBy': patient.email,
    });
    if (start.isAfter(DateTime.now())) {
      final slotId = '${doctor.email}_${start.millisecondsSinceEpoch}';
      if (await rest.get(ps, 'slots/$slotId') == null) {
        await rest.set(ps, 'slots/$slotId', {
          'doctorEmail': doctor.email,
          'start': start.toIso8601String(),
          'owner': ps.uid,
          'visitId': id,
        });
      }
    }
    await rest.set(ps, 'notifications/demo_n_${id}_req', {
      'id': 'demo_n_${id}_req',
      'recipient': doctor.email,
      'type': 'visit_request',
      'title': 'New visit request',
      'body': '${patient.name} · ${ConnectService.fullDateTime(start)} · '
          '$reason',
      'createdAt': createdAt.toIso8601String(),
      'read': finalStatus != 'requested',
      'refId': id,
    });
    if (finalStatus == 'requested') return;
    await rest.update(ds, 'visits/$id', {
      'status': finalStatus,
      'updatedBy': doctor.email,
    });
    if (finalStatus == 'confirmed') {
      await rest.set(ds, 'notifications/demo_n_${id}_ok', {
        'id': 'demo_n_${id}_ok',
        'recipient': patient.email,
        'type': 'visit_confirmed',
        'title': 'Visit confirmed',
        'body': '${doctor.doctorName} · ${ConnectService.fullDateTime(start)}'
            ' · ${doctor.hospital}',
        'createdAt': createdAt.add(const Duration(hours: 2)).toIso8601String(),
        'read': false,
        'refId': id,
      });
    }
  }

  Future<void> _chats(
      _Rest rest, Map<String, _Session> s, DateTime now) async {
    final aisyah = person('aisyah');
    final daniel = person('daniel');
    final priya = person('priya');
    final farid = person('farid');
    final meiling = person('meiling');
    final arjun = person('arjun');
    final nurul = person('nurul');
    Map<String, dynamic> msg(String id, DemoPerson? from, String text,
            DateTime at,
            {String kind = 'text', Map<String, dynamic>? report}) =>
        {
          'id': id,
          'senderEmail': from?.email ?? '',
          'senderName': from == null
              ? ''
              : from.practises
                  ? from.doctorName
                  : from.name,
          'text': text,
          'createdAt': at.toIso8601String(),
          'kind': kind,
          'report': report,
        };
    DateTime ago(int hours) => now.subtract(Duration(hours: hours));

    // Aisyah ↔ Dr. Farid: accepted request, messages and a medical report.
    if (await rest.get(s['aisyah']!, 'chatRequests/demo_chat_1') == null) {
      await rest.set(s['aisyah']!, 'chatRequests/demo_chat_1', {
        'id': 'demo_chat_1',
        'patientEmail': aisyah.email,
        'patientName': aisyah.name,
        'doctorEmail': farid.email,
        'doctorName': farid.doctorName,
        'message': 'Hello doctor, I get chest tightness when I climb stairs. '
            'Should I be worried?',
        'createdAt': ago(50).toIso8601String(),
        'status': 'pending',
        'respondedAt': null,
        'reason': '',
        'conversationId': null,
      });
    }
    if (await rest.get(s['farid']!, 'conversations/demo_conv_1') == null) {
      final report = {
        'code': 'MR-${now.year}-482913',
        'patientName': aisyah.name,
        'patientEmail': aisyah.email,
        'patientBirthday': aisyah.birthday,
        'doctorName': farid.doctorName,
        'doctorEmail': farid.email,
        'doctorType': 'Doctor Manager',
        'hospital': farid.hospital,
        'specialty': farid.specialty,
        'diagnosis': 'Exertional chest discomfort, likely musculoskeletal',
        'findings': 'No pain at rest. No shortness of breath. Normal blood '
            'pressure reported at home (118/76).',
        'treatment': 'Avoid heavy exercise until the visit. Paracetamol 500mg '
            'if needed. Go to Emergency at once if pain spreads to the arm '
            'or jaw.',
        'leaveDays': 0,
        'followUp': 'Clinic visit with ECG on ${ConnectService.fullDate(_nextWeekday(now.add(const Duration(days: 1)), 10))}',
        'issuedAt': ago(44).toIso8601String(),
      };
      await rest.set(s['farid']!, 'conversations/demo_conv_1', {
        'id': 'demo_conv_1',
        'type': 'direct',
        'title': '',
        'description': '',
        'hospital': '',
        'leaderEmail': '',
        'staffRoom': false,
        'members': [aisyah.email, farid.email],
        'memberNames': {
          aisyah.email: aisyah.name,
          farid.email: farid.doctorName,
        },
        'messages': [
          msg('dm1', aisyah,
              'Hello doctor, I get chest tightness when I climb stairs. '
                  'Should I be worried?',
              ago(50)),
          msg('dm2', null, '${farid.doctorName} accepted the chat request',
              ago(48),
              kind: 'system'),
          msg('dm3', farid,
              'Hello Aisyah. How long does it last, and does it happen when '
                  'you rest?',
              ago(48)),
          msg('dm4', aisyah,
              'About 2 minutes, only on the stairs. Never when resting.',
              ago(47)),
          msg('dm5', farid,
              'Thank you. I have written a short report below and booked you '
                  'for an ECG. If the pain spreads to your arm or jaw, go to '
                  'Emergency immediately.',
              ago(45)),
          msg('dm6', farid, 'Medical report ${report['code']}', ago(44),
              kind: 'report', report: report),
          msg('dm7', aisyah, 'Thank you doctor, see you at the clinic 🙏',
              ago(43)),
        ],
        'lastRead': {
          aisyah.email: ago(43).toIso8601String(),
          farid.email: ago(43).toIso8601String(),
        },
        'createdAt': ago(48).toIso8601String(),
      });
      await rest.update(s['farid']!, 'chatRequests/demo_chat_1', {
        'status': 'accepted',
        'respondedAt': ago(48).toIso8601String(),
        'conversationId': 'demo_conv_1',
      });
    }

    // Daniel → Dr. Arjun: a chat request waiting for an answer.
    if (await rest.get(s['daniel']!, 'chatRequests/demo_chat_2') == null) {
      await rest.set(s['daniel']!, 'chatRequests/demo_chat_2', {
        'id': 'demo_chat_2',
        'patientEmail': daniel.email,
        'patientName': daniel.name,
        'doctorEmail': arjun.email,
        'doctorName': arjun.doctorName,
        'message': 'Hi Dr. Arjun, my knee hurts after futsal. Can I ask you '
            'a few questions?',
        'createdAt': ago(3).toIso8601String(),
        'status': 'pending',
        'respondedAt': null,
        'reason': '',
        'conversationId': null,
      });
      await rest.set(s['daniel']!, 'notifications/demo_n_chat_2', {
        'id': 'demo_n_chat_2',
        'recipient': arjun.email,
        'type': 'chat_request',
        'title': 'New chat request',
        'body': '${daniel.name}: my knee hurts after futsal.',
        'createdAt': ago(3).toIso8601String(),
        'read': false,
        'refId': 'demo_chat_2',
      });
    }

    // Staff rooms of both hospitals.
    Future<void> staffRoom(DemoPerson lead, DemoPerson colleague,
        List<(DemoPerson, String)> lines) async {
      final key = ConnectService.hospitalKey(lead.hospital)
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final id = 'staff_$key';
      if (await rest.get(s[lead.key]!, 'conversations/$id') != null) return;
      var hour = 30;
      await rest.set(s[lead.key]!, 'conversations/$id', {
        'id': id,
        'type': 'hospital',
        'title': '${lead.hospital} · Staff room',
        'description': 'Private group for every doctor and manager at '
            '${lead.hospital}.',
        'hospital': lead.hospital,
        'leaderEmail': '',
        'staffRoom': true,
        'members': <String>[],
        'memberNames': {
          lead.email: lead.doctorName,
          colleague.email: colleague.doctorName,
        },
        'messages': [
          msg('sr0', null,
              'Only doctors and managers of ${lead.hospital} can see this '
                  'group.',
              ago(hour + 2),
              kind: 'system'),
          for (var i = 0; i < lines.length; i++)
            msg('sr${i + 1}', lines[i].$1, lines[i].$2, ago(hour -= 4)),
        ],
        'lastRead': <String, dynamic>{},
        'createdAt': ago(32).toIso8601String(),
      });
    }

    await staffRoom(farid, meiling, [
      (farid, 'Good morning team. Reminder: CME talk on Friday 2pm, Level 3.'),
      (meiling, 'Noted. Paediatric ward is full today, please refer new '
          'cases to the clinic.'),
      (farid, 'Thanks Mei Ling. We also have a new graduate joining soon 🎉'),
    ]);
    await staffRoom(arjun, nurul, [
      (arjun, 'Wheelchair stock is fine, but gloves are critical. I have '
          'ordered more.'),
      (nurul, 'Thank you! I will use the spare box from the clinic for now.'),
    ]);

    // A community group anyone can join.
    if (await rest.get(s['farid']!, 'conversations/demo_community_heart') ==
        null) {
      await rest.set(s['farid']!, 'conversations/demo_community_heart', {
        'id': 'demo_community_heart',
        'type': 'community',
        'title': 'Heart Health Circle',
        'description': 'Tips and questions about blood pressure, cholesterol '
            'and a healthy heart. Led by Dr. Farid Hassan.',
        'hospital': '',
        'leaderEmail': farid.email,
        'staffRoom': false,
        'members': [farid.email, aisyah.email, priya.email],
        'memberNames': {
          farid.email: farid.doctorName,
          aisyah.email: aisyah.name,
          priya.email: priya.name,
        },
        'messages': [
          msg('hc1', farid,
              'Welcome! This week: measure your blood pressure at the same '
                  'time every morning for 7 days.',
              ago(70)),
          msg('hc2', priya,
              'Mine is 135/85 in the morning. Is that high?', ago(66)),
          msg('hc3', farid,
              'Slightly high, Priya. Keep a log and bring it to your next '
                  'visit. Less salt helps a lot.',
              ago(64)),
          msg('hc4', aisyah, 'Joining the 7-day challenge 💪', ago(30)),
        ],
        'lastRead': <String, dynamic>{},
        'createdAt': ago(72).toIso8601String(),
      });
    }
  }

  Future<void> _posts(
      _Rest rest, Map<String, _Session> s, DateTime now) async {
    final aisyah = person('aisyah');
    final daniel = person('daniel');
    Map<String, dynamic> author(DemoPerson doctor, int color) => {
          'handle': 'dr.${doctor.key}',
          'name': doctor.doctorName,
          'title': '${doctor.specialty} · ${doctor.hospital}',
          'color': color,
          'verified': true,
          'demo': true,
        };
    Map<String, dynamic> commentBy(
            String id, DemoPerson who, String text, int hoursAgo) =>
        {
          'id': id,
          'author': {
            'handle': who.key,
            'name': who.name,
            'title': '',
            'color': 0xFF0EA5E9,
            'verified': false,
            'demo': true,
          },
          'text': text,
          'createdAt':
              now.subtract(Duration(hours: hoursAgo)).toIso8601String(),
          'baseLikes': 0,
          'likedBy': <String>[],
        };
    final posts = <(String, DemoPerson, int, String, String, String, bool,
        List<Map<String, dynamic>>)>[
      (
        'demo_post_farid',
        person('farid'),
        0xFFDC2626,
        'assets/images/explore/stroke_tall.jpg',
        'Know the signs of stroke: face drooping, arm weakness, speech '
            'difficulty — time to call 999. Every minute matters. #stroke '
            '#FAST',
        'Heart',
        true,
        [commentBy('pc1', aisyah, 'Sharing this with my parents. Thank you!', 5)],
      ),
      (
        'demo_post_meiling',
        person('meiling'),
        0xFF059669,
        'assets/images/explore/kids_fever.jpg',
        'Fever in children: keep them drinking, dress them lightly, and see '
            'a doctor if they are under 3 months, very drowsy, or the fever '
            'lasts more than 2 days. #kids #fever',
        'Kids',
        false,
        [commentBy('pc2', daniel, 'Very helpful, my son had a fever this week.', 2)],
      ),
    ];
    for (final (id, doctor, color, image, caption, topic, tall, comments)
        in posts) {
      final session = s[doctor.key]!;
      if (await rest.get(session, 'posts/$id') != null) continue;
      await rest.set(session, 'posts/$id', {
        'id': id,
        'author': author(doctor, color),
        'image': image,
        'isAsset': true,
        'tall': tall,
        'caption': caption,
        'topic': topic,
        'location': doctor.hospital,
        'createdAt': now.subtract(const Duration(hours: 9)).toIso8601String(),
        'baseLikes': 120,
        'likedBy': [aisyah.email, daniel.email],
        'savedBy': <String>[],
        'comments': comments,
        'kind': 'post',
        'theme': 0,
        'baseViews': 0,
        'viewedBy': <String>[],
        'slides': <Map<String, dynamic>>[],
        'authorUid': session.uid,
      });
    }
  }
}

// ---------------------------------------------------------------- REST

/// One demo person's own sign-in.
class _Session {
  _Session(this.tokens);
  final CloudSessionTokens tokens;

  String get uid => tokens.user.uid;
  String get email => tokens.user.email;
  CloudDb get db => CloudDb.as(tokens);
}

/// Supabase sign-in and documents as each demo person, so they act as
/// themselves without signing the General Manager out of the app.
class _Rest {
  Future<_Session> signUpOrIn(String email, String password,
      String displayName, Map<String, dynamic> profile) async {
    try {
      final tokens = await CloudAuth.signUpRaw(email, password, {
        'full_name': displayName,
        'doc': profile,
      });
      if (tokens == null) {
        throw const DemoException('Supabase asks new accounts to confirm '
            'their email. Turn off "Confirm email" in Supabase '
            '(Authentication > Sign In / Providers > Email), then try again.');
      }
      return _Session(tokens);
    } on CloudAuthException catch (error) {
      if (error.code == 'operation-not-allowed') {
        throw const DemoException(
            'Email sign-up is turned off in Supabase Authentication.');
      }
      if (error.code != 'email-already-in-use') rethrow;
    }
    try {
      return _Session(await CloudAuth.signInRaw(email, password));
    } on CloudAuthException catch (error) {
      if (error.code == 'email-not-confirmed') {
        throw DemoException('$email is waiting for email confirmation. '
            'Turn off "Confirm email" in Supabase, delete $email under '
            'Authentication > Users, then try again.');
      }
      throw DemoException('$email already exists with another password. '
          'Delete it in Supabase (Authentication > Users), then try again.');
    }
  }

  DocumentReference _doc(_Session session, String path) {
    final slash = path.indexOf('/');
    return session.db
        .collection(path.substring(0, slash))
        .doc(path.substring(slash + 1));
  }

  /// The document's data, or null when it doesn't exist (or can't be read).
  Future<Map<String, dynamic>?> get(_Session session, String path) async {
    try {
      return (await _doc(session, path).get()).data();
    } on CloudDbException catch (error) {
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Writes the whole document.
  Future<void> set(
      _Session session, String path, Map<String, dynamic> data) async {
    try {
      await _doc(session, path).set(data);
    } on CloudDbException catch (error) {
      throw DemoException('Save $path: ${error.message}');
    }
  }

  /// Changes only the given fields.
  Future<void> update(
      _Session session, String path, Map<String, dynamic> data) async {
    try {
      await _doc(session, path).update(data);
    } on CloudDbException catch (error) {
      throw DemoException('Update $path: ${error.message}');
    }
  }
}

// ------------------------------------------------------- certificate

/// A simple graduation certificate picture: [name, university, year].
Uint8List _drawCertificate(List<String> input) {
  final name = input[0];
  final university = input[1];
  final year = input[2];
  final image = img.Image(width: 1100, height: 760);
  img.fill(image, color: img.ColorRgb8(253, 250, 240));
  img.drawRect(image,
      x1: 24, y1: 24, x2: 1075, y2: 735,
      color: img.ColorRgb8(30, 58, 138), thickness: 10);
  img.drawRect(image,
      x1: 48, y1: 48, x2: 1051, y2: 711,
      color: img.ColorRgb8(202, 160, 60), thickness: 3);

  int widthOf(String text, img.BitmapFont font) {
    var width = 0;
    for (final code in text.codeUnits) {
      width += font.characters[code]?.xAdvance ?? font.size ~/ 2;
    }
    return width;
  }

  void centered(String text, img.BitmapFont font, int y, img.Color color) {
    final x = ((1100 - widthOf(text, font)) / 2).round();
    img.drawString(image, text, font: font, x: max(60, x), y: y, color: color);
  }

  final navy = img.ColorRgb8(30, 58, 138);
  final ink = img.ColorRgb8(40, 40, 40);
  final gold = img.ColorRgb8(176, 131, 30);
  centered(university.toUpperCase(), img.arial48, 110, navy);
  centered('This is to certify that', img.arial24, 220, ink);
  centered(name, img.arial48, 280, ink);
  img.drawLine(image, x1: 260, y1: 345, x2: 840, y2: 345, color: gold, thickness: 2);
  centered('has been awarded the degree of', img.arial24, 380, ink);
  centered('BACHELOR OF MEDICINE AND BACHELOR OF SURGERY (MBBS)', img.arial24,
      430, navy);
  centered('Conferred in $year', img.arial24, 490, ink);
  img.fillCircle(image, x: 550, y: 610, radius: 58, color: gold);
  img.drawCircle(image, x: 550, y: 610, radius: 46, color: img.ColorRgb8(253, 250, 240));
  centered('SEAL', img.arial24, 598, img.ColorRgb8(253, 250, 240));
  img.drawString(image, 'Demo document - not a real certificate',
      font: img.arial14, x: 70, y: 680, color: img.ColorRgb8(150, 150, 150));
  return Uint8List.fromList(img.encodeJpg(image, quality: 82));
}
