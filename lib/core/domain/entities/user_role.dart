enum UserRole {
  patient,
  doctor,
  manager;

  String get displayName {
    switch (this) {
      case UserRole.patient:
        return 'User';
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.manager:
        return 'Manager';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return UserRole.doctor;
      case 'manager':
      case 'admin':
        return UserRole.manager;
      case 'patient':
      default:
        return UserRole.patient;
    }
  }

  String toJson() => name;

  bool get usesPatientWorkspace => this == UserRole.patient;
}

enum ManagerLevel {
  generalManager,
  doctorManager;

  String get displayName {
    switch (this) {
      case ManagerLevel.generalManager:
        return 'General Manager';
      case ManagerLevel.doctorManager:
        return 'Doctor Manager';
    }
  }

  bool get canManageHospitalOps => this == ManagerLevel.generalManager;
}

enum VerificationStatus {
  none,
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case VerificationStatus.none:
        return 'Not submitted';
      case VerificationStatus.pending:
        return 'Pending review';
      case VerificationStatus.approved:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Kinds of clinical account.
///
/// Hiring rules (enforced in AccountService and HrService):
/// * [student] – fresh medical graduate looking for a first hospital.
/// * [newDoctor] – doctor from another hospital looking for a new job.
///   Students and New Doctors are the only accounts that can ask a hospital
///   for work, and the only kinds anyone can pick when signing up.
/// * [doctor] – works at a hospital and sees patients. Only HR (a General
///   Manager, or a Doctor Manager of that hospital) can make someone a Doctor,
///   by completing their hiring after the join day.
/// * [doctorManager] – a Doctor with HR permission for their hospital. Only a
///   General Manager can give or remove this.
enum DoctorKind {
  student,
  newDoctor,
  doctor,
  doctorManager;

  String get displayName {
    switch (this) {
      case DoctorKind.student:
        return 'Student';
      case DoctorKind.newDoctor:
        return 'New Doctor';
      case DoctorKind.doctor:
        return 'Doctor';
      case DoctorKind.doctorManager:
        return 'Doctor Manager';
    }
  }

  String get description {
    switch (this) {
      case DoctorKind.student:
        return 'Fresh medical graduate looking for a first hospital to work at.';
      case DoctorKind.newDoctor:
        return 'Doctor from another hospital, looking for a new job.';
      case DoctorKind.doctor:
        return 'Works at a hospital and sees patients. Given by HR only.';
      case DoctorKind.doctorManager:
        return 'Doctor with HR permission. Given by a General Manager only.';
    }
  }

  /// Students and New Doctors look for work and can ask hospitals for a job.
  bool get isJobSeeker => this == student || this == newDoctor;

  /// Doctors and Doctor Managers work at a hospital and see patients.
  bool get practises => this == doctor || this == doctorManager;

  /// Only job seekers can be chosen at sign-up.
  bool get canSignUp => isJobSeeker;

  /// Accounts are no longer approved at sign-up: hospitals hire through HR.
  bool get needsApproval => false;

  /// Nobody picks a hospital at sign-up any more; HR assigns it on hiring.
  bool get choosesHospital => false;

  static DoctorKind? tryParse(String? value) {
    for (final kind in DoctorKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}
