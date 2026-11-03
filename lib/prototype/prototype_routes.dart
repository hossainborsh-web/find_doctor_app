import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/route_names.dart';
import '../core/theme/app_text_style.dart';
import '../core/widgets/fd_widgets.dart';
import '../services/account_service.dart';
import '../services/connect_service.dart';
import 'app_screens.dart';
import 'auth_screens.dart';
import 'connect_screens.dart';
import 'manager_screens.dart';
import 'shell.dart';
import 'prototype_session.dart';

Route<dynamic> generatePrototypeRoute(
  BuildContext context,
  RouteSettings settings,
) {
  final isPublicRoute = <String>{
    RouteNames.initial,
    RouteNames.login,
    RouteNames.createAccount,
    RouteNames.documentUpload,
    RouteNames.requestSent,
    RouteNames.verificationPending,
    RouteNames.verificationRejected,
    RouteNames.forgotPassword,
    RouteNames.verificationCode,
    RouteNames.newPassword,
    RouteNames.passwordResetSuccess,
  }.contains(settings.name);
  final isSignedIn = Provider.of<PrototypeSession>(
    context,
    listen: false,
  ).isSignedIn;
  final routeName =
      !isPublicRoute && !isSignedIn ? RouteNames.login : settings.name;
  final builder = _builders[routeName];
  final Widget page = builder != null
      ? builder(RouteSettings(name: routeName, arguments: settings.arguments))
      : _UntitledScreen(title: routeName ?? 'Screen');

  return PageRouteBuilder<dynamic>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final curvedAnimation =
          animation.drive(CurveTween(curve: Curves.easeOutCubic));
      final fromRightToLeft = Directionality.of(context) == TextDirection.ltr;
      final slideAnimation = Tween<Offset>(
        begin: Offset(fromRightToLeft ? 0.035 : -0.035, 0),
        end: Offset.zero,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}

Widget _doctorProfileFor(RouteSettings settings) {
  final args = settings.arguments;
  if (args is AppAccount) return ConnectDoctorProfileScreen(doctorEmail: args.email);
  if (args is String && args.contains('@')) {
    return ConnectDoctorProfileScreen(doctorEmail: args);
  }
  return const DoctorDirectoryScreen();
}

Widget _conversationFor(RouteSettings settings) {
  final args = settings.arguments;
  if (args is String &&
      ConnectService.instance.conversationById(args) != null) {
    return ConversationScreen(conversationId: args);
  }
  return const RoleShell(initialIndex: 2);
}

/// Every route opens a working screen. Older sample-only routes now lead to
/// the live screens that replaced them.
final Map<String, Widget Function(RouteSettings settings)> _builders = {
  RouteNames.initial: (_) => const StartScreen(),
  RouteNames.login: (_) => const LoginScreen(),
  RouteNames.createAccount: (_) => const CreateAccountScreen(),
  RouteNames.documentUpload: (_) => const DocumentUploadScreen(),
  RouteNames.requestSent: (_) => const DoctorRequestSentScreen(),
  RouteNames.changePassword: (_) => const ChangePasswordScreen(),
  RouteNames.verificationPending: (_) => const VerificationPendingScreen(),
  RouteNames.verificationRejected: (_) => const VerificationRejectedScreen(),
  RouteNames.doctorPendingGate: (_) => const DoctorPendingGateScreen(),
  RouteNames.forgotPassword: (_) => const ForgotPasswordScreen(),
  RouteNames.verificationCode: (_) => const VerificationCodeScreen(),
  RouteNames.newPassword: (_) => const NewPasswordScreen(),
  RouteNames.passwordResetSuccess: (_) => const PasswordResetSuccessScreen(),
  RouteNames.shell: (_) => const RoleShell(initialIndex: 1),
  RouteNames.notifications: (_) => const ConnectNotificationsScreen(),
  RouteNames.settings: (_) => const SettingsScreen(),
  RouteNames.editProfile: (_) => const EditProfileScreen(),
  RouteNames.explore: (_) => const RoleShell(initialIndex: 1),
  RouteNames.loading: (_) => const LoadingStateScreen(),
  RouteNames.empty: (_) => const EmptyStateScreen(),
  RouteNames.error: (_) => const ErrorStateScreen(),
  RouteNames.confirmation: (_) => const ConfirmationStateScreen(),

  // Explore: posts, comments and authors live in the Explore tab.
  RouteNames.postDetail: (_) => const RoleShell(initialIndex: 1),
  RouteNames.medicalContentDetail: (_) => const RoleShell(initialIndex: 1),
  RouteNames.comments: (_) => const RoleShell(initialIndex: 1),
  RouteNames.authorProfile: (_) => const RoleShell(initialIndex: 1),
  RouteNames.createPost: (_) => const RoleShell(initialIndex: 1),

  // Doctors and visits.
  RouteNames.searchEmpty: (_) => const RoleShell(initialIndex: 3),
  RouteNames.search: (_) => const SearchRouteScreen(),
  RouteNames.doctorProfile: _doctorProfileFor,
  RouteNames.doctorCertificates: _doctorProfileFor,
  RouteNames.doctorReviews: _doctorProfileFor,
  RouteNames.weeklySchedule: (settings) => settings.arguments is AppAccount
      ? _doctorProfileFor(settings)
      : const ScheduleEditorScreen(),
  RouteNames.requestConsultation: (_) => const DoctorDirectoryScreen(),
  RouteNames.bookAppointment: (_) => const DoctorDirectoryScreen(),
  RouteNames.appointments: (_) => const VisitsScreen(),
  RouteNames.appointmentDetails: (_) => const VisitsScreen(),
  RouteNames.paymentMethod: (_) => const VisitsScreen(),
  RouteNames.paymentConfirm: (_) => const VisitsScreen(),
  RouteNames.receipt: (_) => const VisitsScreen(),
  RouteNames.doctorAppointments: (_) => const VisitsScreen(),
  RouteNames.operations: (_) => const VisitsScreen(),
  RouteNames.doctorSchedule: (_) => const ScheduleEditorScreen(),

  // Chats and groups.
  RouteNames.chatThread: _conversationFor,
  RouteNames.publicGroup: _conversationFor,
  RouteNames.privateGroup: _conversationFor,
  RouteNames.doctorCollabChat: _conversationFor,
  RouteNames.doctorManagerChat: _conversationFor,
  RouteNames.sharePrescription: _conversationFor,
  RouteNames.collaborationRequest: _conversationFor,
  RouteNames.patientProfileView: (_) => const RoleShell(initialIndex: 3),
  RouteNames.managerProfileView: (_) => const RoleShell(initialIndex: 3),

  // Manager workspace.
  // Hiring replaced sign-up approvals: every old link opens Hiring & staff.
  RouteNames.doctorApplications: (_) => const HrCenterScreen(),
  RouteNames.applicationReview: (_) => const HrCenterScreen(),
  RouteNames.approveConfirm: (_) => const HrCenterScreen(),
  RouteNames.rejectReason: (_) => const HrCenterScreen(),
  RouteNames.doctorManagement: (_) => const HospitalDoctorsScreen(),
  RouteNames.manageSchedule: (_) => const HospitalSchedulesScreen(),
  RouteNames.hospitalAnalytics: (_) => const HospitalOverviewScreen(),
  RouteNames.equipment: (_) => const EquipmentScreen(),
  RouteNames.medication: (_) => const MedicationInventoryScreen(),
  RouteNames.managerOperations: (_) => const HospitalSchedulesScreen(),
  RouteNames.meetings: (_) => const RoleShell(initialIndex: 2),
  RouteNames.alerts: (_) => const HospitalAlertsScreen(),
};

class _UntitledScreen extends StatelessWidget {
  const _UntitledScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FdAppBar(title: title, showBack: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            title,
            style: AppTextStyles.headline2,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
