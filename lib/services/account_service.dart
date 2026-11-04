import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/domain/entities/user_role.dart';
import 'cloud/fs_mirror.dart';
import 'cloud/media_service.dart';
import 'cloud/supabase_api.dart';

/// Where an account is in the sign-up / approval process.
enum AccountStatus { active, pending, rejected }

/// A Find Doctor account stored on this device.
class AppAccount {
  AppAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.doctorKind,
    this.managerLevel,
    this.hospital = '',
    this.specialty = '',
    this.birthday = '',
    this.passwordHash,
    this.salt,
    this.mustChangePassword = false,
    this.temporaryPassword,
    this.reviewedBy,
    this.reviewedAt,
    this.documentName,
    this.university = '',
    this.graduationYear = '',
    this.previousHospital = '',
    this.certificatePath = '',
    this.openToWork = true,
    this.hiredBy = '',
    this.hiredAt,
  });

  final String id;
  String fullName;
  final String email;

  /// Role, kind and level change only through AccountService's HR methods.
  UserRole role;
  DoctorKind? doctorKind;
  ManagerLevel? managerLevel;
  String hospital;
  String specialty;
  String birthday;
  AccountStatus status;
  String? passwordHash;
  String? salt;

  /// True after a Doctor Manager issues a password, until the doctor sets
  /// their own.
  bool mustChangePassword;

  /// The password a Doctor Manager issued, kept so the manager can send it
  /// again. Cleared as soon as the doctor chooses their own password.
  String? temporaryPassword;
  String? reviewedBy;
  DateTime? reviewedAt;
  String? documentName;
  final DateTime createdAt;

  /// Students: university and graduation year.
  String university;
  String graduationYear;

  /// New Doctors: the hospital they worked at before.
  String previousHospital;

  /// Saved copy of the graduation certificate image (job seekers).
  String certificatePath;

  /// Job seekers listed in the hospitals' talent pool.
  bool openToWork;

  /// Who completed this doctor's hiring, and when.
  String hiredBy;
  DateTime? hiredAt;

  /// Students and New Doctors looking for work.
  bool get isJobSeeker => doctorKind?.isJobSeeker ?? false;

  /// Doctors and Doctor Managers who work at a hospital.
  bool get practises => doctorKind == null
      ? role == UserRole.doctor && hospital.trim().isNotEmpty
      : doctorKind!.practises;

  bool get isGeneralManager =>
      managerLevel == ManagerLevel.generalManager && !isDoctorManager;

  bool get hasCertificate => certificatePath.trim().isNotEmpty;

  bool get isDoctorManager =>
      doctorKind == DoctorKind.doctorManager ||
      managerLevel == ManagerLevel.doctorManager;

  bool get needsApproval => doctorKind?.needsApproval ?? false;

  /// Label shown in the UI, e.g. "New Doctor", "Doctor Manager", "User".
  String get typeLabel {
    if (doctorKind != null) return doctorKind!.displayName;
    if (isGeneralManager) return 'General Manager';
    if (managerLevel != null) return managerLevel!.displayName;
    return role.displayName;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role.name,
        'doctorKind': doctorKind?.name,
        'managerLevel': managerLevel?.name,
        'hospital': hospital,
        'specialty': specialty,
        'birthday': birthday,
        'status': status.name,
        'passwordHash': passwordHash,
        'salt': salt,
        'mustChangePassword': mustChangePassword,
        'temporaryPassword': temporaryPassword,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'documentName': documentName,
        'createdAt': createdAt.toIso8601String(),
        'university': university,
        'graduationYear': graduationYear,
        'previousHospital': previousHospital,
        'certificatePath': certificatePath,
        'openToWork': openToWork,
        'hiredBy': hiredBy,
        'hiredAt': hiredAt?.toIso8601String(),
      };

  /// What is stored in the cloud: no passwords (Supabase Auth keeps those).
  Map<String, dynamic> toCloudJson() => toJson()
    ..remove('passwordHash')
    ..remove('salt')
    ..remove('temporaryPassword')
    ..remove('mustChangePassword');

  factory AppAccount.fromJson(Map<String, dynamic> json) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    ManagerLevel? level;
    for (final value in ManagerLevel.values) {
      if (value.name == json['managerLevel']) level = value;
    }

    return AppAccount(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: byName(UserRole.values, json['role'], UserRole.patient),
      doctorKind: DoctorKind.tryParse(json['doctorKind'] as String?),
      managerLevel: level,
      hospital: json['hospital'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      birthday: json['birthday'] as String? ?? '',
      status: byName(AccountStatus.values, json['status'], AccountStatus.active),
      passwordHash: json['passwordHash'] as String?,
      salt: json['salt'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      temporaryPassword: json['temporaryPassword'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
      documentName: json['documentName'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      university: json['university'] as String? ?? '',
      graduationYear: json['graduationYear'] as String? ?? '',
      previousHospital: json['previousHospital'] as String? ?? '',
      certificatePath: json['certificatePath'] as String? ?? '',
      openToWork: json['openToWork'] as bool? ?? true,
      hiredBy: json['hiredBy'] as String? ?? '',
      hiredAt: DateTime.tryParse(json['hiredAt'] as String? ?? ''),
    );
  }
}

class AccountException implements Exception {
  const AccountException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Sign-up, sign-in and every account's profile, in Supabase.
///
/// Supabase Auth checks passwords; profiles live in the `profiles` table,
/// which every signed-in device keeps a live copy of (for directories,
/// chats and hiring). Listen to it to refresh screens.
class AccountService extends ChangeNotifier {
  AccountService._();

  static final AccountService instance = AccountService._();

  static const minPasswordLength = 6;

  final List<AppAccount> _accounts = [];
  late final FsMirror<AppAccount> _mirror = FsMirror<AppAccount>(
    collection: 'users',
    list: _accounts,
    idOf: (account) => account.id,
    toJson: (account) => account.toCloudJson(),
    fromJson: (id, json) => AppAccount.fromJson({...json, 'id': id}),
    onChange: _usersChanged,
    pollEvery: const Duration(seconds: 10),
  );
  AppAccount? _current;

  AppAccount? get currentAccount => _current;

  CollectionReference get _users => CloudDb.instance.collection('users');

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  void _startListening() {
    if (_mirror.isListening) return;
    _mirror.listen([_users]);
  }

  /// Keeps [currentAccount] pointing at the live copy (e.g. after HR hires
  /// this person), so the app can switch workspace without signing out.
  void _usersChanged() {
    final current = _current;
    if (current != null) {
      for (final account in _accounts) {
        if (account.id == current.id) {
          _current = account;
          break;
        }
      }
    }
    notifyListeners();
  }

  Future<List<AppAccount>> _load() async {
    if (CloudAuth.instance.currentUser == null) return _accounts;
    _startListening();
    await _mirror.ready;
    return _accounts;
  }

  Future<void> _save() async {
    await _mirror.push();
    notifyListeners();
  }

  /// Every account (used by chat, groups, directories and hiring).
  Future<List<AppAccount>> accounts() async =>
      List.unmodifiable(await _load());

  Future<AppAccount?> findByEmail(String email) async {
    final key = normalizeEmail(email);
    for (final account in await _load()) {
      if (account.email == key) return account;
    }
    return null;
  }

  Future<AppAccount?> _findById(String id) async {
    for (final account in await _load()) {
      if (account.id == id) return account;
    }
    return null;
  }

  static AccountException _authError(CloudAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return const AccountException('EMAIL_EXISTS',
            'An account with this email already exists. Sign in instead.');
      case 'invalid-email':
        return const AccountException(
            'BAD_EMAIL', 'Enter a valid email address.');
      case 'weak-password':
        return const AccountException('WEAK_PASSWORD',
            'Use at least $minPasswordLength characters for your password.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return const AccountException(
            'WRONG_PASSWORD', 'Incorrect email or password. Please try again.');
      case 'user-disabled':
        return const AccountException(
            'DISABLED', 'This account has been turned off.');
      case 'too-many-requests':
        return const AccountException('TOO_MANY',
            'Too many tries. Wait a few minutes, then try again.');
      case 'network-request-failed':
        return const AccountException(
            'OFFLINE', 'No internet connection. Check it and try again.');
      case 'requires-recent-login':
      case 'user-token-expired':
        return const AccountException(
            'SIGN_IN_AGAIN', 'Please sign out and sign in again first.');
      case 'email-not-confirmed':
        return const AccountException('NOT_CONFIRMED',
            'Confirm your email first: open the link we sent to your inbox.');
      case 'operation-not-allowed':
        return const AccountException('SIGN_UP_OFF',
            'Email sign-up is turned off for Find Doctor right now.');
      default:
        return AccountException(error.code,
            error.message ?? 'Something went wrong. Please try again.');
    }
  }

  // ---------------------------------------------------------------- sign-up

  /// Creates an account. The law: anyone can join as a User, a Student or a
  /// New Doctor. Doctor, Doctor Manager and Manager can't be chosen here —
  /// HR gives Doctor by hiring, and only a General Manager gives Doctor
  /// Manager.
  Future<AppAccount> register({
    required String fullName,
    required String email,
    required UserRole role,
    DoctorKind? doctorKind,
    ManagerLevel? managerLevel,
    String hospital = '',
    String specialty = '',
    String birthday = '',
    String university = '',
    String graduationYear = '',
    String previousHospital = '',
    String? password,
  }) async {
    final key = normalizeEmail(email);
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(key)) {
      throw const AccountException('BAD_EMAIL', 'Enter a valid email address.');
    }
    if (fullName.trim().length < 2) {
      throw const AccountException('BAD_NAME', 'Enter your full name.');
    }
    if (role == UserRole.manager || managerLevel != null) {
      throw const AccountException(
        'NOT_ALLOWED',
        'Manager accounts can\'t be created by signing up. Only a General '
            'Manager can give manager permission.',
      );
    }
    if (role == UserRole.doctor &&
        (doctorKind == null || !doctorKind.canSignUp)) {
      throw const AccountException(
        'NOT_ALLOWED',
        'Doctor and Doctor Manager accounts are given by hospital HR. Sign up '
            'as a Student or New Doctor and ask a hospital for work.',
      );
    }
    if (role == UserRole.patient && doctorKind != null) {
      throw const AccountException(
          'NOT_ALLOWED', 'Choose User, Student or New Doctor.');
    }
    if (doctorKind == DoctorKind.student) {
      if (university.trim().length < 3) {
        throw const AccountException(
            'BAD_UNIVERSITY', 'Enter the university you graduated from.');
      }
      _checkGraduationYear(graduationYear);
    }
    if (doctorKind == DoctorKind.newDoctor && specialty.trim().isEmpty) {
      throw const AccountException('BAD_SPECIALTY', 'Enter your specialty.');
    }
    if (password == null || password.length < minPasswordLength) {
      throw const AccountException(
        'WEAK_PASSWORD',
        'Use at least $minPasswordLength characters for your password.',
      );
    }

    AppAccount profile(String id) => AppAccount(
          id: id,
          fullName: fullName.trim(),
          email: key,
          role: role,
          doctorKind: doctorKind,
          // Nobody gets a hospital by signing up: HR assigns it on hiring.
          hospital: '',
          specialty: specialty.trim(),
          birthday: birthday.trim(),
          university: university.trim(),
          graduationYear: graduationYear.trim(),
          previousHospital: previousHospital.trim(),
          status: AccountStatus.active,
          createdAt: DateTime.now(),
        );

    // The database makes the profile from these details at sign-up (and
    // applies the law: only User, Student or New Doctor).
    final CloudUser user;
    try {
      user = await CloudAuth.instance.createUser(
        email: key,
        password: password,
        data: {
          'full_name': fullName.trim(),
          'doc': profile('').toCloudJson()..remove('id'),
        },
      );
    } on CloudAuthException catch (error) {
      throw _authError(error);
    }
    final account = AppAccount(
      id: user.uid,
      fullName: fullName.trim(),
      email: key,
      role: role,
      doctorKind: doctorKind,
      // Nobody gets a hospital by signing up: HR assigns it on hiring.
      hospital: '',
      specialty: specialty.trim(),
      birthday: birthday.trim(),
      university: university.trim(),
      graduationYear: graduationYear.trim(),
      previousHospital: previousHospital.trim(),
      status: AccountStatus.active,
      createdAt: DateTime.now(),
    );
    if (CloudAuth.instance.currentUser != null) {
      try {
        await _users.doc(account.id).set(account.toCloudJson());
      } catch (error) {
        // The sign-up already made the profile; this only refreshes it.
        debugPrint('Find Doctor: profile save after sign-up: $error');
      }
    }
    // The sign-up screen sends people to sign in next.
    await CloudAuth.instance.signOut();
    return account;
  }

  static void _checkGraduationYear(String value) {
    final year = int.tryParse(value.trim());
    final now = DateTime.now().year;
    if (year == null || year < 1950 || year > now + 1) {
      throw AccountException(
          'BAD_YEAR', 'Enter your graduation year (1950–${now + 1}).');
    }
  }

  /// Saves the editable profile fields. Email, role and hospital are set at
  /// sign-up or by a Doctor Manager, so they don't change here.
  Future<AppAccount> updateProfile(
    String email, {
    required String fullName,
    String? birthday,
    String? specialty,
  }) async {
    final account = await findByEmail(email);
    if (account == null) {
      throw const AccountException(
          'not-found', 'This account was not found.');
    }
    final name = fullName.trim();
    if (name.length < 2) {
      throw const AccountException(
          'invalid-name', 'Please enter your full name.');
    }
    account.fullName = name;
    if (birthday != null) account.birthday = birthday.trim();
    if (specialty != null) account.specialty = specialty.trim();
    await _save();
    return account;
  }

  Future<void> attachDocument(String email, String fileName) async {
    final account = await findByEmail(email);
    if (account == null) return;
    account.documentName = fileName;
    await _save();
  }

  // ---------------------------------------------------------------- sign-in

  Future<AppAccount> signIn({
    required String email,
    required String password,
  }) async {
    final key = normalizeEmail(email);
    final CloudUser user;
    try {
      user = await CloudAuth.instance.signIn(email: key, password: password);
    } on CloudAuthException catch (error) {
      throw _authError(error);
    }
    final AppAccount account;
    try {
      account = await _profileFor(user);
    } on CloudDbException catch (error) {
      await CloudAuth.instance.signOut();
      throw AccountException(
          error.code == 'unavailable' ? 'OFFLINE' : 'PROFILE',
          error.code == 'unavailable'
              ? 'No internet connection. Check it and try again.'
              : 'Could not load your profile: ${error.message}');
    }
    switch (account.status) {
      case AccountStatus.pending:
      case AccountStatus.rejected:
        await CloudAuth.instance.signOut();
        throw const AccountException('NOT_ACTIVE',
            'This account is not active. Contact the hospital\'s HR.');
      case AccountStatus.active:
        break;
    }
    _current = account;
    _startListening();
    notifyListeners();
    return account;
  }

  /// The signed-in person's profile; creates a basic User profile for a
  /// sign-in that has none (e.g. made in the Supabase dashboard).
  Future<AppAccount> _profileFor(CloudUser user) async {
    final doc = await _users.doc(user.uid).get();
    final data = doc.data();
    if (data != null) return AppAccount.fromJson({...data, 'id': user.uid});
    final account = AppAccount(
      id: user.uid,
      fullName: user.displayName ?? user.email.split('@').first,
      email: normalizeEmail(user.email),
      role: UserRole.patient,
      status: AccountStatus.active,
      createdAt: DateTime.now(),
    );
    await _users.doc(user.uid).set(account.toCloudJson());
    return account;
  }

  Future<AppAccount?> restoreSession() async {
    // CloudAuth.instance.init() (at start-up) restored the saved sign-in.
    final user = CloudAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final account = await _profileFor(user);
      if (account.status != AccountStatus.active) {
        await CloudAuth.instance.signOut();
        return null;
      }
      _current = account;
      _startListening();
      return account;
    } catch (error) {
      debugPrint('Find Doctor: could not restore session: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    _current = null;
    _mirror.stop();
    _accounts.clear();
    await CloudAuth.instance.signOut();
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = CloudAuth.instance.currentUser;
    final account = _current;
    if (user == null || account == null) {
      throw const AccountException('NOT_SIGNED_IN', 'Please sign in again.');
    }
    if (newPassword.length < minPasswordLength) {
      throw const AccountException(
        'WEAK_PASSWORD',
        'Use at least $minPasswordLength characters for your new password.',
      );
    }
    try {
      await CloudAuth.instance.changePassword(
          currentPassword: currentPassword, newPassword: newPassword);
    } on CloudAuthException catch (error) {
      if (error.code == 'wrong-password' || error.code == 'invalid-credential') {
        throw const AccountException(
            'WRONG_PASSWORD', 'Your current password is incorrect.');
      }
      throw _authError(error);
    }
    account
      ..mustChangePassword = false
      ..temporaryPassword = null;
  }

  /// Sends a password reset email and returns what to tell the person.
  Future<String> passwordHelp(String email) async {
    final key = normalizeEmail(email);
    try {
      await CloudAuth.instance.sendPasswordResetEmail(key);
    } on CloudAuthException catch (error) {
      if (error.code != 'user-not-found') throw _authError(error);
    }
    return 'If an account exists for $key, we sent it an email with a link '
        'to choose a new password. Check your inbox and spam folder.';
  }

  // ------------------------------------------------------ Doctor Manager tools

  /// Requests a manager can review: Doctors at the manager's hospital, plus
  /// every New Doctor (they have no hospital yet). General managers see all.
  Future<List<AppAccount>> requestsFor(AppAccount manager) async {
    final accounts = await _load();
    final managerHospital = manager.hospital.trim().toLowerCase();
    final requests = accounts.where((account) {
      if (!account.needsApproval) return false;
      if (!manager.isDoctorManager) return true;
      if (account.doctorKind == DoctorKind.newDoctor) return true;
      return account.hospital.trim().toLowerCase() == managerHospital;
    }).toList()
      ..sort((a, b) {
        int rank(AppAccount account) => switch (account.status) {
              AccountStatus.pending => 0,
              AccountStatus.active => 1,
              AccountStatus.rejected => 2,
            };
        final byStatus = rank(a).compareTo(rank(b));
        if (byStatus != 0) return byStatus; // pending first
        return b.createdAt.compareTo(a.createdAt); // newest first
      });
    return requests;
  }

  Future<int> pendingCountFor(AppAccount manager) async =>
      (await requestsFor(manager))
          .where((account) => account.status == AccountStatus.pending)
          .length;

  /// Approves a request and returns the password to send to the doctor.
  Future<String> approve(String accountId, {required AppAccount manager}) async {
    final account = await _findById(accountId);
    if (account == null) {
      throw const AccountException('NOT_FOUND', 'This request no longer exists.');
    }
    final hr = await findByEmail(manager.email);
    if (hr == null || !isHr(hr)) {
      throw const AccountException(
          'NOT_ALLOWED', 'Only HR can answer sign-up requests.');
    }
    if (account.status == AccountStatus.pending &&
        (account.doctorKind?.practises ?? false)) {
      // Older sign-ups asked for Doctor or Doctor Manager directly. Under the
      // hiring rules they join as New Doctors and are hired through HR.
      account
        ..doctorKind = DoctorKind.newDoctor
        ..previousHospital = account.hospital
        ..hospital = '';
    }
    final password = _generatePassword();
    _setPassword(account, password);
    account
      ..status = AccountStatus.active
      ..mustChangePassword = true
      ..temporaryPassword = password
      ..reviewedBy = manager.fullName
      ..reviewedAt = DateTime.now();
    await _save();
    return password;
  }

  Future<void> reject(String accountId, {required AppAccount manager}) async {
    final account = await _findById(accountId);
    if (account == null) return;
    account
      ..status = AccountStatus.rejected
      ..passwordHash = null
      ..salt = null
      ..temporaryPassword = null
      ..reviewedBy = manager.fullName
      ..reviewedAt = DateTime.now();
    await _save();
  }

  /// Issues a fresh password for an approved doctor (e.g. they forgot it).
  Future<String> issueNewPassword(String accountId,
          {required AppAccount manager}) =>
      approve(accountId, manager: manager);

  // ------------------------------------------------------------------- HR

  /// General Managers (every hospital) and Doctor Managers (their own
  /// hospital) are HR.
  static bool isHr(AppAccount? account) =>
      account != null &&
      account.status == AccountStatus.active &&
      (account.isGeneralManager ||
          (account.isDoctorManager && account.hospital.trim().isNotEmpty));

  static bool isGeneralManager(AppAccount? account) =>
      account != null &&
      account.status == AccountStatus.active &&
      account.isGeneralManager;

  /// Whether [actor] may act as HR for [hospital].
  static bool hrCovers(AppAccount? actor, String hospital) {
    if (!isHr(actor)) return false;
    if (actor!.isGeneralManager) return true;
    final key = hospital.trim().toLowerCase();
    return key.isNotEmpty && key == actor.hospital.trim().toLowerCase();
  }

  /// Active Students and New Doctors.
  Future<List<AppAccount>> jobSeekers() async => (await _load())
      .where((account) =>
          account.isJobSeeker && account.status == AccountStatus.active)
      .toList();

  Future<AppAccount> _stored(String email, String what) async {
    final account = await findByEmail(email);
    if (account == null) {
      throw AccountException('NOT_FOUND', '$what no longer exists.');
    }
    return account;
  }

  /// Makes a Student or New Doctor a Doctor at [hospital]. Called by
  /// HrService when HR completes hiring after the join day.
  Future<AppAccount> hire({
    required String seekerEmail,
    required String hospital,
    required AppAccount actor,
  }) async {
    final hr = await _stored(actor.email, 'Your account');
    if (!hrCovers(hr, hospital)) {
      throw AccountException(
          'NOT_ALLOWED', 'Only HR of $hospital can hire for it.');
    }
    final seeker = await _stored(seekerEmail, 'This person');
    if (seeker.email == hr.email) {
      throw const AccountException('NOT_ALLOWED', 'You can\'t hire yourself.');
    }
    if (!seeker.isJobSeeker || seeker.status != AccountStatus.active) {
      throw const AccountException(
          'NOT_SEEKER', 'This person is no longer looking for work.');
    }
    seeker
      ..role = UserRole.doctor
      ..doctorKind = DoctorKind.doctor
      ..managerLevel = null
      ..hospital = hospital.trim()
      ..openToWork = false
      ..hiredBy = hr.fullName
      ..hiredAt = DateTime.now();
    await _save();
    return seeker;
  }

  /// Ends a doctor's work at their hospital. They become a New Doctor who
  /// can look for work again. Doctor Managers can only be released by a
  /// General Manager, and nobody can release themselves.
  Future<AppAccount> endEmployment({
    required String targetEmail,
    required AppAccount actor,
  }) async {
    final hr = await _stored(actor.email, 'Your account');
    final target = await _stored(targetEmail, 'This doctor');
    if (target.email == hr.email) {
      throw const AccountException('NOT_ALLOWED',
          'You can\'t end your own employment. Ask a General Manager.');
    }
    if (!target.practises || target.hospital.trim().isEmpty) {
      throw const AccountException(
          'NOT_STAFF', 'This account doesn\'t work at a hospital.');
    }
    if (!hrCovers(hr, target.hospital)) {
      throw AccountException('NOT_ALLOWED',
          'Only HR of ${target.hospital} can end this employment.');
    }
    if (target.isDoctorManager && !hr.isGeneralManager) {
      throw const AccountException('NOT_ALLOWED',
          'Only a General Manager can change a Doctor Manager.');
    }
    target
      ..previousHospital = target.hospital
      ..hospital = ''
      ..role = UserRole.doctor
      ..doctorKind = DoctorKind.newDoctor
      ..managerLevel = null
      ..openToWork = true;
    await _save();
    return target;
  }

  /// Gives (or removes) Doctor Manager permission. General Managers only.
  Future<AppAccount> setDoctorManager({
    required String targetEmail,
    required AppAccount actor,
    required bool grant,
  }) async {
    final hr = await _stored(actor.email, 'Your account');
    if (!isGeneralManager(hr)) {
      throw const AccountException('NOT_ALLOWED',
          'Only a General Manager can give or remove Doctor Manager '
              'permission.');
    }
    final target = await _stored(targetEmail, 'This doctor');
    if (target.email == hr.email) {
      throw const AccountException(
          'NOT_ALLOWED', 'You can\'t change your own permissions.');
    }
    if (!target.practises ||
        target.hospital.trim().isEmpty ||
        target.status != AccountStatus.active) {
      throw const AccountException('NOT_STAFF',
          'Only doctors who work at a hospital can be Doctor Managers.');
    }
    if (grant == target.isDoctorManager) return target;
    target
      ..role = UserRole.doctor
      ..doctorKind = grant ? DoctorKind.doctorManager : DoctorKind.doctor
      ..managerLevel = null;
    await _save();
    return target;
  }

  /// Job seekers' career details.
  Future<AppAccount> updateCareer(
    String email, {
    String? university,
    String? graduationYear,
    String? previousHospital,
    String? specialty,
    bool? openToWork,
  }) async {
    final account = await _stored(email, 'This account');
    if (!account.isJobSeeker) {
      throw const AccountException(
          'NOT_SEEKER', 'Only Students and New Doctors have a career profile.');
    }
    if (university != null) {
      if (account.doctorKind == DoctorKind.student &&
          university.trim().length < 3) {
        throw const AccountException(
            'BAD_UNIVERSITY', 'Enter the university you graduated from.');
      }
      account.university = university.trim();
    }
    if (graduationYear != null) {
      if (account.doctorKind == DoctorKind.student) {
        _checkGraduationYear(graduationYear);
      }
      account.graduationYear = graduationYear.trim();
    }
    if (previousHospital != null) {
      account.previousHospital = previousHospital.trim();
    }
    if (specialty != null) {
      if (account.doctorKind == DoctorKind.newDoctor &&
          specialty.trim().isEmpty) {
        throw const AccountException('BAD_SPECIALTY', 'Enter your specialty.');
      }
      account.specialty = specialty.trim();
    }
    if (openToWork != null) account.openToWork = openToWork;
    await _save();
    return account;
  }

  static const _imageTypes = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'};

  /// Shrinks the graduation certificate photo and saves it in the cloud.
  Future<AppAccount> setCertificate(String email, String sourcePath) async {
    final account = await _stored(email, 'This account');
    if (!account.isJobSeeker) {
      throw const AccountException('NOT_SEEKER',
          'Only Students and New Doctors upload a graduation certificate.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const AccountException('NO_FILE', 'That file could not be found.');
    }
    final extension = sourcePath.contains('.')
        ? sourcePath.split('.').last.toLowerCase()
        : 'jpg';
    if (!_imageTypes.contains(extension) && !extension.startsWith('heic')) {
      throw const AccountException(
          'BAD_FILE', 'Choose an image of your certificate (PNG or JPG).');
    }
    if (await source.length() > 25 * 1024 * 1024) {
      throw const AccountException(
          'TOO_BIG', 'That image is too large. Use one under 25 MB.');
    }
    final String reference;
    try {
      reference = await MediaService.instance.uploadFile(sourcePath);
    } on MediaException catch (error) {
      throw AccountException('BAD_FILE', error.message);
    } catch (_) {
      throw const AccountException('OFFLINE',
          'Could not upload the certificate. Check your internet connection.');
    }
    account
      ..certificatePath = reference
      ..documentName = sourcePath.split(RegExp(r'[\\/]')).last;
    await _save();
    return account;
  }

  // ---------------------------------------------------------------- helpers

  static final _random = Random.secure();

  static String _randomId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  /// Easy-to-read password like "K7PM-4QXZ" (no 0/O or 1/I).
  static String _generatePassword() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String block() =>
        List.generate(4, (_) => alphabet[_random.nextInt(alphabet.length)])
            .join();
    return '${block()}-${block()}';
  }

  static void _setPassword(AppAccount account, String password) {
    final salt = base64Url
        .encode(List<int>.generate(16, (_) => _random.nextInt(256)));
    account
      ..salt = salt
      ..passwordHash = _hash(salt, password);
  }

  static bool _checkPassword(AppAccount account, String password) {
    final salt = account.salt;
    final hash = account.passwordHash;
    if (salt == null || hash == null) return false;
    return _hash(salt, password) == hash;
  }

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}
