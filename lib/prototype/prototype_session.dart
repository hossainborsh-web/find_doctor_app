import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/domain/entities/user_role.dart';
import '../services/account_service.dart';

class PrototypeSession extends ChangeNotifier {
  PrototypeSession({AppAccount? initialAccount}) {
    if (initialAccount != null) {
      _applyAccount(initialAccount);
    }
    _restoreThemePreference();
    AccountService.instance.addListener(_followLiveAccount);
  }

  /// When HR changes this person's role (hire, promotion, release), the live
  /// profile changes too; switch workspace without signing out.
  void _followLiveAccount() {
    final live = AccountService.instance.currentAccount;
    final mine = account;
    if (live == null || mine == null || identical(live, mine)) return;
    if (live.id != mine.id) return;
    _applyAccount(live);
    notifyListeners();
  }

  static const _themePreferenceKey = 'find_doctor_night_mode';

  UserRole? role;
  ManagerLevel? managerLevel;
  DoctorKind? doctorKind;

  /// The signed-in account (null for guests).
  AppAccount? account;
  VerificationStatus verification = VerificationStatus.none;
  String displayName = 'Guest';
  String email = '';
  String workplace = '';
  String specialty = '';
  bool doctorApproved = true;
  bool isDarkMode = false;
  final Set<String> approvedApplicationIds = <String>{};
  final Set<String> rejectedApplicationIds = <String>{};

  bool get isSignedIn => role != null;

  Future<void> setDarkMode(bool enabled) async {
    if (isDarkMode == enabled) return;
    isDarkMode = enabled;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_themePreferenceKey, enabled);
  }

  Future<void> _restoreThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final savedValue = preferences.getBool(_themePreferenceKey) ?? false;
    if (isDarkMode == savedValue) return;
    isDarkMode = savedValue;
    notifyListeners();
  }

  void approveApplication(String id) {
    approvedApplicationIds.add(id);
    rejectedApplicationIds.remove(id);
    notifyListeners();
  }

  void rejectApplication(String id) {
    rejectedApplicationIds.add(id);
    approvedApplicationIds.remove(id);
    notifyListeners();
  }

  bool applicationApproved(String id) => approvedApplicationIds.contains(id);
  bool applicationRejected(String id) => rejectedApplicationIds.contains(id);

  void updateProfile(
      {required String displayName,
      required String email,
      required String workplace}) {
    this.displayName = displayName.trim();
    this.email = email.trim();
    this.workplace = workplace.trim();
    notifyListeners();
  }

  void signIn({
    required String fullName,
    required String email,
    required String roleName,
    required bool isVerified,
    String hospitalName = '',
    String specialty = '',
    String? accountManagerLevel,
  }) {
    final normalizedRole = roleName.trim().toLowerCase();
    role = switch (normalizedRole) {
      'doctor' => UserRole.doctor,
      'manager' || 'general manager' || 'doctor manager' => UserRole.manager,
      _ => UserRole.patient,
    };
    managerLevel =
        switch (accountManagerLevel?.trim().toLowerCase() ?? normalizedRole) {
      'doctor manager' || 'doctormanager' => ManagerLevel.doctorManager,
      'manager' ||
      'general manager' ||
      'generalmanager' =>
        ManagerLevel.generalManager,
      _ => null,
    };
    displayName = fullName.trim().isEmpty ? email.trim() : fullName.trim();
    this.email = email.trim();
    workplace = hospitalName.trim();
    this.specialty = specialty.trim();
    verification =
        isVerified ? VerificationStatus.approved : VerificationStatus.pending;
    doctorApproved = isVerified;
    notifyListeners();
  }

  /// Signs in with an account from [AccountService].
  void signInWithAccount(AppAccount account) {
    _applyAccount(account);
    notifyListeners();
  }

  /// Label for the profile, e.g. "Doctor Manager" or "New Doctor".
  String get accountTypeLabel =>
      account?.typeLabel ??
      (managerLevel?.displayName ?? role?.displayName ?? 'Guest');

  Future<void> signOut() async {
    try {
      await AccountService.instance.signOut();
    } finally {
      role = null;
      managerLevel = null;
      doctorKind = null;
      account = null;
      verification = VerificationStatus.none;
      displayName = 'Guest';
      email = '';
      workplace = '';
      specialty = '';
      doctorApproved = true;
      notifyListeners();
    }
  }

  void _applyAccount(AppAccount account) {
    this.account = account;
    // Students and New Doctors don't see patients until HR hires them, so
    // they get the user workspace plus their career page.
    role = account.isDoctorManager
        ? UserRole.manager
        : account.isJobSeeker
            ? UserRole.patient
            : account.role;
    doctorKind = account.doctorKind;
    managerLevel = account.isDoctorManager
        ? ManagerLevel.doctorManager
        : account.managerLevel;
    displayName =
        account.fullName.isEmpty ? account.email : account.fullName;
    email = account.email;
    workplace = account.hospital;
    specialty = account.specialty;
    verification = account.status == AccountStatus.active
        ? VerificationStatus.approved
        : VerificationStatus.pending;
    doctorApproved = account.status == AccountStatus.active;
  }
}
