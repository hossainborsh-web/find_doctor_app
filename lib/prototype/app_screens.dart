import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/route_names.dart';
import '../core/domain/entities/user_role.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/fd_palette.dart';
import '../core/theme/app_text_style.dart';
import '../core/widgets/fd_widgets.dart';
import 'care_flow.dart' show EmergencyNotice;
import 'content_widgets.dart';
import 'mock_data.dart';
import 'prototype_session.dart';
import 'shell.dart' show showAccountStatus;
import '../services/account_service.dart';
import '../services/connect_service.dart';
import '../services/localization_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Notifications', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Recent updates',
              style: AppTextStyles.subtitle2.copyWith(
                color: context.fdColor(AppColors.primaryBlueDark),
                fontSize: 17,
              )),
          const SizedBox(height: 14),
          const NotificationItem(
            title: 'Appointment confirmed',
            description: 'Dr. Emily Chen · Thu 10:00 · RM 180',
            time: '10 min ago',
            icon: Icons.event_available_outlined,
            tone: FdStatusTone.success,
          ),
          const NotificationItem(
            title: 'Pending document review',
            description: 'Doctor application for Dr. Hana Yusof',
            time: '1 hour ago',
            icon: Icons.assignment_outlined,
            tone: FdStatusTone.warning,
          ),
          const NotificationItem(
            title: 'Payment receipt available',
            description: 'Invoice INV-20418 is ready',
            time: 'Yesterday',
            icon: Icons.receipt_long_outlined,
          ),
          const NotificationItem(
            title: 'Application rejected',
            description: 'Certificate not certified — resubmit required',
            time: '2 days ago',
            icon: Icons.error_outline_rounded,
            tone: FdStatusTone.danger,
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final localization = context.watch<LocalizationService>();
    return Scaffold(
      appBar: const FdAppBar(title: 'Settings', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          FdCard(
            child: Column(children: [
              FdAvatar(
                initials: session.displayName
                    .split(' ')
                    .where((part) => part.isNotEmpty)
                    .take(2)
                    .map((part) => part[0])
                    .join(),
                size: 82,
              ),
              const SizedBox(height: 12),
              Text(session.displayName, style: AppTextStyles.subtitle1),
              const SizedBox(height: 4),
              Text(session.specialty.isEmpty
                  ? 'Find Doctor account'
                  : session.specialty),
              const SizedBox(height: 10),
              FdStatusChip(
                label: session.verification.displayName,
                tone: session.verification == VerificationStatus.approved
                    ? FdStatusTone.success
                    : session.verification == VerificationStatus.rejected
                        ? FdStatusTone.danger
                        : FdStatusTone.warning,
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const FdSectionHeader(title: 'Account & preferences'),
          FdCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    session.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.dark_mode_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 21,
                  ),
                ),
                title: Text(
                  'Night mode',
                  style: AppTextStyles.bodyText2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  session.isDarkMode ? 'On' : 'Off',
                  style: AppTextStyles.caption,
                ),
                trailing: Switch.adaptive(
                  value: session.isDarkMode,
                  onChanged: context.read<PrototypeSession>().setDarkMode,
                ),
              ),
              const Divider(height: 1, indent: 68),
              _SettingsAction(
                icon: Icons.verified_user_outlined,
                title: 'Account & verification',
                subtitle: 'Account type, status and review details',
                tint: context.fdColor(AppColors.aqua),
                onTap: () => showAccountStatus(context),
              ),
              const Divider(height: 1, indent: 68),
              _SettingsAction(
                icon: Icons.lock_reset_rounded,
                title: 'Change password',
                subtitle: 'Keep your sign-in secure',
                tint: context.isNightMode
                    ? const Color(0xFF252A47)
                    : const Color(0xFFDDE7FA),
                onTap: () =>
                    Navigator.pushNamed(context, RouteNames.changePassword),
              ),
              const Divider(height: 1, indent: 68),
              _SettingsAction(
                icon: Icons.person_outline_rounded,
                title: 'Edit profile',
                subtitle: 'Name, date of birth or specialty',
                tint: context.fdColor(AppColors.lightBlue),
                onTap: () =>
                    Navigator.pushNamed(context, RouteNames.editProfile),
              ),
              const Divider(height: 1, indent: 68),
              _SettingsAction(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Visits, chat requests and replies',
                tint: context.fdColor(AppColors.lightGrey),
                onTap: () =>
                    Navigator.pushNamed(context, RouteNames.notifications),
              ),
              const Divider(height: 1, indent: 68),
              _SettingsAction(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: LocalizationService.getNativeLanguageName(
                    localization.languageCode),
                tint: context.fdColor(AppColors.surfaceMuted),
                onTap: () async {
                  final selectedLocale = await showDialog<Locale>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Choose language'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: LocalizationService.supportedLocales
                            .map((locale) => ListTile(
                                  title: Text(
                                      LocalizationService.getNativeLanguageName(
                                          locale.languageCode)),
                                  trailing: localization.locale == locale
                                      ? Icon(Icons.check_rounded,
                                          color: context
                                              .fdColor(AppColors.primaryBlue))
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, locale),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                  if (selectedLocale != null && context.mounted) {
                    await context
                        .read<LocalizationService>()
                        .setLocale(selectedLocale);
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          FdButton(
            label: 'Log out',
            icon: Icons.logout_rounded,
            outlined: true,
            destructive: true,
            onPressed: () async {
              await context.read<PrototypeSession>().signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, RouteNames.initial, (_) => false);
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: context.fdColor(AppColors.primaryBlueDark), size: 21),
        ),
        title: Text(title,
            style: AppTextStyles.bodyText2.copyWith(
              fontWeight: FontWeight.w600,
            )),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: Icon(Icons.chevron_right_rounded,
            color: context.fdColor(AppColors.darkGrey)),
      );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _birthday;
  late final TextEditingController _specialty;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = context.read<PrototypeSession>();
    final account = session.account;
    _name = TextEditingController(text: account?.fullName ?? session.displayName);
    _birthday = TextEditingController(text: account?.birthday ?? '');
    _specialty = TextEditingController(
        text: account?.specialty ?? session.specialty);
  }

  @override
  void dispose() {
    _name.dispose();
    _birthday.dispose();
    _specialty.dispose();
    super.dispose();
  }

  bool get _isDoctor {
    final account = context.read<PrototypeSession>().account;
    return account != null && account.practises;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<PrototypeSession>();
    final account = session.account;
    final messenger = ScaffoldMessenger.of(context);
    if (account == null) {
      session.updateProfile(
          displayName: _name.text,
          email: session.email,
          workplace: session.workplace);
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await AccountService.instance.updateProfile(
        account.email,
        fullName: _name.text,
        birthday: _isDoctor ? null : _birthday.text,
        specialty: _isDoctor ? _specialty.text : null,
      );
      session.signInWithAccount(updated);
      await ConnectService.instance.refresh();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved.')));
      Navigator.pop(context);
    } on AccountException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  Widget _locked(String label, String value, String help) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.bodyText2
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: context.fdColor(AppColors.surfaceMuted),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.fdColor(AppColors.borderGrey)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(value.isEmpty ? '—' : value,
                    style: AppTextStyles.bodyText2.copyWith(
                        color: context.fdColor(AppColors.neutralBlack))),
              ),
              Icon(Icons.lock_outline_rounded,
                  size: 16, color: context.fdColor(AppColors.darkGrey)),
            ]),
          ),
          const SizedBox(height: 4),
          Text(help,
              style: AppTextStyles.caption
                  .copyWith(color: context.fdColor(AppColors.darkGrey))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final account = session.account;
    final isStaff = account != null &&
        (account.practises ||
            account.role == UserRole.manager ||
            account.managerLevel != null);
    return Scaffold(
      appBar: const FdAppBar(title: 'Edit profile', showBack: true),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Center(
                    child: FdAvatar(
                        initials: session.displayName
                            .split(' ')
                            .map((e) => e.isEmpty ? '' : e[0])
                            .take(2)
                            .join(),
                        size: 82)),
                const SizedBox(height: 22),
                FdTextField(
                  label: 'Full name',
                  controller: _name,
                  hint: 'Your name',
                  validator: (value) =>
                      (value == null || value.trim().length < 2)
                          ? 'Enter your full name'
                          : null,
                ),
                const SizedBox(height: 16),
                _locked('Email address', session.email,
                    'Your email is how you sign in, so it can\'t be changed here.'),
                const SizedBox(height: 16),
                if (_isDoctor) ...[
                  FdTextField(
                    label: 'Specialty',
                    controller: _specialty,
                    hint: 'e.g. Cardiology',
                  ),
                  const SizedBox(height: 16),
                ] else if (!isStaff) ...[
                  FdTextField(
                    label: 'Date of birth',
                    controller: _birthday,
                    hint: 'DD/MM/YYYY',
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(text)
                          ? null
                          : 'Use the format DD/MM/YYYY';
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                if (isStaff) ...[
                  _locked('Hospital', session.workplace,
                      'Your hospital is set by HR when you are hired.'),
                  const SizedBox(height: 16),
                ],
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(
                          color: context.fdColor(AppColors.errorRed))),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                FdButton(
                  label: _saving ? 'Saving…' : 'Save changes',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, this.medicalContent = false});

  final bool medicalContent;

  @override
  Widget build(BuildContext context) {
    final post = ModalRoute.of(context)?.settings.arguments as MockPost? ??
        MockData.posts.first;
    return Scaffold(
      appBar: FdAppBar(
          title: medicalContent ? 'Health content' : 'Post details',
          showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: medicalContent
            ? [
                FdCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.health_and_safety_outlined,
                              color: context.fdColor(AppColors.primaryBlue)),
                          const SizedBox(width: 8),
                          Text('MEDICAL UPDATE',
                              style: AppTextStyles.caption.copyWith(
                                  color: context.fdColor(AppColors.primaryBlue),
                                  fontWeight: FontWeight.w700))
                        ]),
                        const SizedBox(height: 14),
                        Text(post.mediaLabel,
                            style:
                                AppTextStyles.headline2.copyWith(fontSize: 22)),
                        const SizedBox(height: 8),
                        Text('${post.workplace} · ${post.date}',
                            style: AppTextStyles.caption),
                        const Divider(height: 24),
                        Text(post.content, style: AppTextStyles.bodyText1),
                      ]),
                ),
                const SizedBox(height: 12),
                FdPostCard(
                    post: post,
                    onComment: () => Navigator.pushNamed(
                        context, RouteNames.comments,
                        arguments: post)),
              ]
            : [
                FdPostCard(
                  post: post,
                  onComment: () => Navigator.pushNamed(
                      context, RouteNames.comments,
                      arguments: post),
                  onProfile: () => Navigator.pushNamed(
                      context, RouteNames.authorProfile,
                      arguments: post),
                ),
              ],
      ),
    );
  }
}

class CommentsScreen extends StatelessWidget {
  const CommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Comments', showBack: true),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              children: [
                FdCard(
                    child: Text(
                        'Dr. Wei Jun Tan: Agree with confirming home BP before titration.')),
                const SizedBox(height: 12),
                FdCard(
                    child: Text(
                        'Farah Aziz: Please share this protocol in the hospital briefing.')),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: TextField(
                decoration:
                    InputDecoration(hintText: 'Write a professional comment')),
          ),
        ],
      ),
    );
  }
}

class AuthorProfileScreen extends StatelessWidget {
  const AuthorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final post = ModalRoute.of(context)?.settings.arguments as MockPost? ??
        MockData.posts.first;
    return Scaffold(
      appBar: const FdAppBar(title: 'Profile', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(child: FdAvatar(initials: post.initials, size: 80)),
          const SizedBox(height: 12),
          Text(post.author,
              style: AppTextStyles.headline2, textAlign: TextAlign.center),
          Text('${post.role} · ${post.workplace}',
              style: AppTextStyles.secondary, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FdPostCard(post: post),
        ],
      ),
    );
  }
}

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Create educational post', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const FdPreviewNotice(
              message: 'Posts cannot be published from this preview.'),
          const SizedBox(height: 16),
          const FdTextField(label: 'Title', hint: 'Clinical topic'),
          const SizedBox(height: 16),
          const FdTextField(label: 'Content', maxLines: 6),
          const SizedBox(height: 16),
          FdCard(
            child: Row(
              children: [
                Icon(Icons.attach_file,
                    color: context.fdColor(AppColors.darkGrey)),
                SizedBox(width: 12),
                Text('Attachments unavailable in preview'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const FdButton(label: 'Publishing unavailable in preview'),
        ],
      ),
    );
  }
}

class SearchEmptyScreen extends StatelessWidget {
  const SearchEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: FdAppBar(title: 'Search', showBack: true),
      body: FdEmptyState(
        title: 'No results',
        message:
            'Users can search doctors only. Try a specialty such as Cardiology.',
        icon: Icons.search,
      ),
    );
  }
}

class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctor = ModalRoute.of(context)?.settings.arguments as MockDoctor? ??
        MockData.doctors.first;
    final session = context.watch<PrototypeSession>();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primaryBlueDark,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(doctor.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      AppColors.primaryBlueDark,
                      AppColors.primaryBlue,
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 52, right: 28),
                    child: Icon(
                      Icons.local_hospital_outlined,
                      size: 74,
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DoctorAvatar(doctor: doctor, size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor.specialty,
                                style: AppTextStyles.subtitle2),
                            Text(doctor.hospital, style: AppTextStyles.caption),
                            const SizedBox(height: 8),
                            FdStatusChip(
                              label:
                                  doctor.verified ? 'Verified' : 'Unverified',
                              tone: doctor.verified
                                  ? FdStatusTone.success
                                  : FdStatusTone.warning,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const FdSectionHeader(title: 'About'),
                  Text(doctor.bio, style: AppTextStyles.bodyText2),
                  const SizedBox(height: 16),
                  FdCard(
                    child: Row(
                      children: [
                        Icon(Icons.medical_information_outlined,
                            color: context.fdColor(AppColors.primaryBlue)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Clinical experience',
                                style: AppTextStyles.bodyText2)),
                        Text('${doctor.yearsExperience} years',
                            style: AppTextStyles.bodyText2
                                .copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(
                          label: 'Consults', value: '${doctor.consultations}'),
                      _Stat(label: 'Operations', value: '${doctor.operations}'),
                      _Stat(
                          label: 'Rating',
                          value: doctor.rating.toStringAsFixed(1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FdCard(
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: context.fdColor(AppColors.primaryBlue)),
                        const SizedBox(width: 12),
                        Text('Consultation price  RM ${doctor.priceRm}',
                            style: AppTextStyles.bodyText2
                                .copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                          label: const Text('Certificates'),
                          onPressed: () => Navigator.pushNamed(
                              context, RouteNames.doctorCertificates,
                              arguments: doctor)),
                      ActionChip(
                          label: const Text('Reviews'),
                          onPressed: () => Navigator.pushNamed(
                              context, RouteNames.doctorReviews,
                              arguments: doctor)),
                      ActionChip(
                          label: const Text('Schedule'),
                          onPressed: () => Navigator.pushNamed(
                              context, RouteNames.weeklySchedule,
                              arguments: doctor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const FdSectionHeader(title: 'Posts and education'),
                  FdPostCard(
                    post: MockData.posts.first,
                    onOpen: () => Navigator.pushNamed(
                      context,
                      RouteNames.postDetail,
                      arguments: MockData.posts.first,
                    ),
                    onComment: () => Navigator.pushNamed(
                      context,
                      RouteNames.comments,
                      arguments: MockData.posts.first,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FdSectionHeader(title: 'Photos and videos'),
                  FdCard(
                    onTap: () => Navigator.pushNamed(
                      context,
                      RouteNames.medicalContentDetail,
                      arguments: MockData.posts[1],
                    ),
                    child: Row(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.fdColor(AppColors.surfaceMuted),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.play_circle_outline,
                            color: context.fdColor(AppColors.primaryBlue),
                            size: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACL rehabilitation guidance',
                                style: AppTextStyles.bodyText2
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text('Clinical education video',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: context.fdColor(AppColors.darkGrey)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const FdSectionHeader(title: 'Availability'),
                  FdStatusChip(
                    label: doctor.available
                        ? 'Available for booking'
                        : 'Currently unavailable',
                    tone: doctor.available
                        ? FdStatusTone.success
                        : FdStatusTone.warning,
                  ),
                  const SizedBox(height: 24),
                  if (session.role?.name == 'patient') ...[
                    FdButton(
                      label: 'Request consultation',
                      onPressed: () => Navigator.pushNamed(
                          context, RouteNames.requestConsultation,
                          arguments: doctor),
                    ),
                    const SizedBox(height: 12),
                    FdButton(
                      label: 'Book appointment',
                      outlined: true,
                      onPressed: () => Navigator.pushNamed(
                          context, RouteNames.bookAppointment,
                          arguments: doctor),
                    ),
                    const SizedBox(height: 12),
                    FdButton(
                      label: 'Message doctor',
                      outlined: true,
                      icon: Icons.chat_bubble_outline,
                      onPressed: () => Navigator.pushNamed(
                          context, RouteNames.chatThread,
                          arguments: MockData.chats.first),
                    ),
                  ] else if (session.role?.name == 'doctor') ...[
                    FdButton(
                      label: 'Request collaboration',
                      onPressed: () => Navigator.pushNamed(
                          context, RouteNames.collaborationRequest,
                          arguments: doctor),
                    ),
                    const SizedBox(height: 12),
                    FdButton(
                      label: 'Request operation',
                      outlined: true,
                      onPressed: () =>
                          Navigator.pushNamed(context, RouteNames.operations),
                    ),
                  ] else ...[
                    FdButton(
                      label: 'Manage schedule',
                      onPressed: () => Navigator.pushNamed(
                          context, RouteNames.manageSchedule,
                          arguments: doctor),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FdCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.subtitle2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Certificates', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          FdCard(
              child: ListTile(
                  title: Text('MBBS, Universiti Malaya'),
                  subtitle: Text('2012'),
                  leading: Icon(Icons.workspace_premium_outlined))),
          SizedBox(height: 12),
          FdCard(
              child: ListTile(
                  title: Text('National Specialist Register'),
                  subtitle: Text('Cardiology'),
                  leading: Icon(Icons.verified_outlined))),
        ],
      ),
    );
  }
}

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Reviews', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          FdCard(
              child: Text(
                  'Clear explanation of treatment options. Consultation started on time.')),
          SizedBox(height: 12),
          FdCard(
              child:
                  Text('Professional follow-up after angiography. Rated 5.0.')),
        ],
      ),
    );
  }
}

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  late final List<bool> available =
      MockData.weekly.map((row) => row.$3).toList();

  @override
  Widget build(BuildContext context) {
    final role = context.watch<PrototypeSession>().role;
    final canEdit = role == UserRole.doctor || role == UserRole.manager;
    final doctor = ModalRoute.of(context)?.settings.arguments as MockDoctor?;
    return Scaffold(
      appBar: FdAppBar(
        title: canEdit ? 'Manage schedule' : 'Weekly schedule',
        subtitle: doctor?.name,
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                role == UserRole.manager
                    ? 'Schedule changes apply to the selected doctor.'
                    : 'Set the hours users can book with you.',
                style: AppTextStyles.secondary,
              ),
            ),
          ...List.generate(MockData.weekly.length, (index) {
            final row = MockData.weekly[index];
            final isAvailable = available[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FdCard(
                child: Row(
                  children: [
                    Expanded(
                        child: Text(row.$1,
                            style: AppTextStyles.bodyText2
                                .copyWith(fontWeight: FontWeight.w600))),
                    FdStatusChip(
                      label: isAvailable ? row.$2 : 'Unavailable',
                      tone: isAvailable
                          ? FdStatusTone.success
                          : FdStatusTone.warning,
                    ),
                    if (canEdit) ...[
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: isAvailable,
                        onChanged: (value) =>
                            setState(() => available[index] = value),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class PaymentMethodScreen extends StatelessWidget {
  const PaymentMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Payment method', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const FdPreviewNotice(
              message: 'Payments are not connected. No charge will be made.'),
          const SizedBox(height: 16),
          FdCard(
              child: ListTile(
                  leading: Icon(Icons.credit_card),
                  title: Text('Card payment · preview only'))),
          const SizedBox(height: 12),
          FdCard(
              child: ListTile(
                  leading: Icon(Icons.account_balance_outlined),
                  title: Text('Online banking (FPX)'))),
          const SizedBox(height: 24),
          FdButton(
            label: 'Payment unavailable in preview',
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

class PaymentConfirmScreen extends StatelessWidget {
  const PaymentConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctor = ModalRoute.of(context)?.settings.arguments as MockDoctor? ??
        MockData.doctors.first;
    return Scaffold(
      appBar: const FdAppBar(title: 'Confirm payment', showBack: true),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            const FdPreviewNotice(
                message: 'Payment processing is unavailable in this preview.'),
            const SizedBox(height: 16),
            FdCard(
              child: Column(
                children: [
                  _kv('Doctor', doctor.name),
                  _kv('Selected time', 'Not booked'),
                  _kv('Sample fee', 'RM ${doctor.priceRm}'),
                ],
              ),
            ),
            const Spacer(),
            FdButton(label: 'Payment unavailable in preview'),
          ],
        ),
      ),
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(k, style: AppTextStyles.caption)),
        Text(v,
            style:
                AppTextStyles.bodyText2.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({super.key, this.title = 'Consultation'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final chat = ModalRoute.of(context)?.settings.arguments as MockChat?;
    final name = chat?.title ?? title;
    final doctor = chat?.type == 'consultation' ? MockData.doctors.first : null;
    final isGroup = chat?.type == 'public' || chat?.type == 'private';
    final messages = _sampleConversation(chat?.type ?? 'consultation');
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: AppBar(
        backgroundColor: context.fdColor(Colors.white),
        foregroundColor: context.fdColor(AppColors.primaryBlueDark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            if (isGroup)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.groups_2_rounded,
                    color: context.fdColor(AppColors.primaryBlue), size: 23),
              )
            else
              FdAvatar(
                initials: doctor?.initials ??
                    name
                        .split(RegExp(r'\s+'))
                        .where((part) => part.isNotEmpty)
                        .take(2)
                        .map((part) => part[0])
                        .join(),
                size: 44,
              ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText1.copyWith(
                      color: context.fdColor(AppColors.primaryBlueDark),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor?.specialty ??
                        (isGroup
                            ? 'Care team conversation'
                            : 'Sample conversation'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: context.fdColor(AppColors.darkGrey),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: Column(
        children: [
          if (chat?.type == 'consultation') ...[
            _ConsultationChatContext(doctorName: name),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: EmergencyNotice(),
            ),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              children: [
                const FdPreviewNotice(
                  message:
                      'Sample chat · messages and times shown here are examples only.',
                ),
                const SizedBox(height: 20),
                const _ChatDayDivider(label: 'SAMPLE EXCHANGE'),
                const SizedBox(height: 18),
                for (var index = 0; index < messages.length; index++) ...[
                  Align(
                    alignment: messages[index].$2
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: _ChatBubble(
                      text: messages[index].$1,
                      outgoing: messages[index].$2,
                      time: messages[index].$3,
                      author: messages[index].$2 ? 'You' : doctor?.name,
                    ),
                  ),
                  if (index < messages.length - 1) const SizedBox(height: 13),
                ],
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'End of sample conversation',
                    style: TextStyle(
                      color: context.fdColor(AppColors.darkGrey),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _PreviewChatComposer(),
        ],
      ),
    );
  }
}

List<(String, bool, String)> _sampleConversation(String type) {
  switch (type) {
    case 'consultation':
      return const [
        (
          'Hi Ahmad, your cardiology consultation is coming up on Thursday at 10:00 AM. Do you have any questions you would like to discuss?',
          false,
          '9:12 AM',
        ),
        (
          'Hi Doctor, I have a recent ECG report that I can bring along.',
          true,
          '9:16 AM',
        ),
        (
          'That would be helpful. We can review it together during your visit.',
          false,
          '9:18 AM',
        ),
      ];
    case 'collaboration':
      return const [
        (
          'I have added the case notes for our joint review.',
          false,
          '10:24 AM'
        ),
        (
          'Thanks. I will review them before the care team meeting.',
          true,
          '10:31 AM'
        ),
      ];
    case 'manager':
      return const [
        (
          'The operating room 3 schedule has changed for Friday.',
          false,
          '8:42 AM'
        ),
        (
          'Thanks for the update. I will check the revised schedule.',
          true,
          '8:47 AM'
        ),
      ];
    case 'public':
      return const [
        (
          'This week’s focus is making heart health checks part of routine care.',
          false,
          'Yesterday'
        ),
        (
          'A useful reminder for our community. Thank you for sharing.',
          true,
          'Yesterday'
        ),
      ];
    case 'private':
      return const [
        ('Ward round notes are ready for the team to review.', false, 'Monday'),
        (
          'Received. I will follow up with the team this afternoon.',
          true,
          'Monday'
        ),
      ];
    default:
      return const [
        ('Welcome to your care conversation.', false, 'Today'),
        ('Thank you. I will follow up here after my visit.', true, 'Today'),
      ];
  }
}

class _ConsultationChatContext extends StatelessWidget {
  const _ConsultationChatContext({required this.doctorName});

  final String doctorName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: context.fdColor(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.fdColor(AppColors.borderGrey)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.fdColor(AppColors.surfaceMuted),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_month_outlined,
                color: context.fdColor(AppColors.primaryBlue), size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming consultation · sample',
                  style: TextStyle(
                    color: context.fdColor(AppColors.primaryBlueDark),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$doctorName · Thursday, 10:00 AM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Icon(Icons.info_outline_rounded,
              size: 17, color: context.fdColor(AppColors.darkGrey)),
        ],
      ),
    );
  }
}

class _ChatDayDivider extends StatelessWidget {
  const _ChatDayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _PreviewChatComposer extends StatelessWidget {
  const _PreviewChatComposer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 7),
      decoration: BoxDecoration(
        color: context.fdColor(Colors.white),
        border: Border(
            top: BorderSide(color: context.fdColor(AppColors.borderGrey))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A17324D),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Attachments unavailable in preview',
                  onPressed: null,
                  icon: Icon(Icons.add_circle_outline_rounded),
                ),
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: context.fdColor(AppColors.background),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: context.fdColor(AppColors.borderGrey)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 17,
                            color: context.fdColor(AppColors.darkGrey)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Messaging unavailable in preview',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: context.fdColor(AppColors.darkGrey),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: context.fdColor(AppColors.lightGrey),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.send_rounded,
                      size: 19, color: context.fdColor(AppColors.darkGrey)),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Messages are examples and won’t be sent.',
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class SharePrescriptionScreen extends StatelessWidget {
  const SharePrescriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Share medical file', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FdCard(
              onTap: () => Navigator.pop(context),
              child: const ListTile(
                  title: Text('Prescription'),
                  subtitle: Text('Atorvastatin 20mg · 30 days'))),
          const SizedBox(height: 12),
          FdCard(
              onTap: () => Navigator.pop(context),
              child: const ListTile(
                  title: Text('Appointment'),
                  subtitle: Text('Thu 10:00 · Cardiology'))),
          const SizedBox(height: 12),
          FdCard(
              onTap: () => Navigator.pop(context),
              child: const ListTile(
                  title: Text('Invoice'),
                  subtitle: Text('INV-20418 · RM 180'))),
        ],
      ),
    );
  }
}

class PatientProfileViewScreen extends StatelessWidget {
  const PatientProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient =
        ModalRoute.of(context)?.settings.arguments as MockPatient? ??
            MockData.patients.first;
    return Scaffold(
      appBar: const FdAppBar(title: 'User profile', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          FdCard(
            child: Row(
              children: [
                FdAvatar(initials: patient.initials, size: 68),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name, style: AppTextStyles.subtitle1),
                      const SizedBox(height: 3),
                      Text('User ID · ${patient.id.toUpperCase()}',
                          style: AppTextStyles.secondary),
                      Text('${patient.city} · Born ${patient.birthday}',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 8),
                      const FdStatusChip(
                          label: 'Active user', tone: FdStatusTone.success),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'More user options',
                  onPressed: () {},
                  icon: Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const FdSectionHeader(title: 'Recent vitals'),
          FdCard(
            child: Column(
              children: [
                Row(children: [
                  const Expanded(
                    child: _VitalTile(
                        label: 'Blood pressure', value: '120/80', unit: 'mmHg'),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: _VitalTile(
                        label: 'Heart rate', value: '72', unit: 'bpm'),
                  ),
                ]),
                const SizedBox(height: 10),
                const Row(children: [
                  Expanded(
                    child: _VitalTile(
                        label: 'Temperature', value: '98.6', unit: '°F'),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _VitalTile(label: 'SpO₂', value: '99', unit: '%'),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const FdSectionHeader(title: 'Visit context'),
          FdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileInfoBlock(
                  icon: Icons.assignment_outlined,
                  title: 'Chief complaint',
                  body:
                      'Occasional headaches over the past two weeks. No severe pain reported.',
                ),
                const Divider(height: 24),
                _ProfileInfoBlock(
                  icon: Icons.history_rounded,
                  title: 'Relevant history',
                  body:
                      'No known allergies. Family history of hypertension. Follow-up on recent bloodwork.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const FdSectionHeader(title: 'Attached documents', action: '3 files'),
          FdCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const [
                _PatientDocumentRow(
                    title: 'CBC_Results_October.pdf',
                    subtitle: 'Added 2 days ago · 2.4 MB'),
                Divider(height: 1, indent: 16, endIndent: 16),
                _PatientDocumentRow(
                    title: 'Chest_XRay_Scan.jpg',
                    subtitle: 'Added 1 month ago · 4.1 MB'),
                Divider(height: 1, indent: 16, endIndent: 16),
                _PatientDocumentRow(
                    title: 'Medication_History.pdf',
                    subtitle: 'Added 3 months ago · 1.2 MB'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FdButton(
              label: 'Message user securely',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.chatThread)),
        ],
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: context.fdColor(AppColors.inputBackground),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color:
                  context.fdColor(AppColors.borderGrey).withValues(alpha: .7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 5),
            Text.rich(
              TextSpan(
                text: value,
                style: AppTextStyles.subtitle1.copyWith(fontSize: 18),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ProfileInfoBlock extends StatelessWidget {
  const _ProfileInfoBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 17, color: context.fdColor(AppColors.accentTeal)),
            const SizedBox(width: 8),
            Text(title,
                style: AppTextStyles.bodyText2
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 7),
          Text(body, style: AppTextStyles.secondary),
        ],
      );
}

class _PatientDocumentRow extends StatelessWidget {
  const _PatientDocumentRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 40,
            decoration: BoxDecoration(
              color: context.fdColor(AppColors.surfaceMuted),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_outlined,
                color: context.fdColor(AppColors.primaryBlue), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText2.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(Icons.download_outlined,
              size: 18, color: context.fdColor(AppColors.darkGrey)),
        ]),
      );
}

class ManagerProfileViewScreen extends StatelessWidget {
  const ManagerProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager =
        ModalRoute.of(context)?.settings.arguments as MockManager? ??
            MockData.managers.first;
    return Scaffold(
      appBar: const FdAppBar(title: 'Manager', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(child: FdAvatar(initials: manager.initials, size: 80)),
          const SizedBox(height: 12),
          Text(manager.name,
              textAlign: TextAlign.center, style: AppTextStyles.headline2),
          Text('${manager.level} · ${manager.hospital}',
              textAlign: TextAlign.center, style: AppTextStyles.secondary),
          const SizedBox(height: 24),
          FdButton(
              label: 'Message manager',
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.doctorManagerChat)),
        ],
      ),
    );
  }
}

class CollaborationRequestScreen extends StatelessWidget {
  const CollaborationRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Collaboration request', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const FdTextField(label: 'Colleague', hint: 'Dr. Wei Jun Tan'),
          const SizedBox(height: 16),
          const FdTextField(label: 'Clinical reason', maxLines: 4),
          const SizedBox(height: 24),
          FdButton(
              label: 'Send request',
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.doctorCollabChat)),
        ],
      ),
    );
  }
}

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Operations', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          FdCard(
              child: ListTile(
                  title: Text('OT 3 · Knee arthroscopy'),
                  subtitle: Text('Fri 11:00 · Pending equipment'),
                  trailing: FdStatusChip(
                      label: 'Pending', tone: FdStatusTone.warning))),
          SizedBox(height: 12),
          FdCard(
              child: ListTile(
                  title: Text('OT 1 · Angiography'),
                  subtitle: Text('Thu 08:30'),
                  trailing: FdStatusChip(
                      label: 'Confirmed', tone: FdStatusTone.success))),
        ],
      ),
    );
  }
}

class DoctorScheduleScreen extends StatelessWidget {
  const DoctorScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WeeklyScheduleScreen();
  }
}

class LoadingStateScreen extends StatelessWidget {
  const LoadingStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        appBar: FdAppBar(title: 'Loading', showBack: true),
        body: FdLoadingState());
  }
}

class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: FdAppBar(title: 'Appointments', showBack: true),
      body: FdEmptyState(
          title: 'No upcoming appointments',
          message: 'Book a consultation from Search when you are ready.'),
    );
  }
}

class ErrorStateScreen extends StatelessWidget {
  const ErrorStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FdAppBar(title: 'Error', showBack: true),
      body: FdErrorState(onRetry: () => Navigator.pop(context)),
    );
  }
}

class ConfirmationStateScreen extends StatelessWidget {
  const ConfirmationStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final application =
        ModalRoute.of(context)?.settings.arguments as MockApplication?;
    return Scaffold(
      appBar: FdAppBar(
          title: application == null ? 'Confirm' : 'Approve application',
          showBack: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const FdPreviewNotice(
                message:
                    'This action updates sample data in this preview only.'),
            const SizedBox(height: 16),
            Text(
              application == null
                  ? 'Confirm this action?'
                  : 'Approve ${application.doctorName}?',
              style: AppTextStyles.headline2,
            ),
            const SizedBox(height: 8),
            Text(
              application == null
                  ? 'Review the details before continuing.'
                  : 'Mark this sample application as approved for the current preview session.',
              style: AppTextStyles.secondary,
            ),
            const Spacer(),
            FdButton(
              label: application == null
                  ? 'Confirm preview action'
                  : 'Approve in preview',
              onPressed: () {
                if (application != null) {
                  context
                      .read<PrototypeSession>()
                      .approveApplication(application.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${application.doctorName} marked approved for this preview session only')),
                  );
                  Navigator.popUntil(context,
                      ModalRoute.withName(RouteNames.doctorApplications));
                  return;
                }
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            FdButton(
                label: 'Cancel',
                outlined: true,
                onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    this.outgoing = false,
    this.time,
    this.author,
  });

  final String text;
  final bool outgoing;
  final String? time;
  final String? author;

  @override
  Widget build(BuildContext context) => Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color:
              outgoing
                  ? context.fdColor(AppColors.primaryBlue)
                  : context.fdColor(Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(outgoing ? 16 : 4),
            bottomRight: Radius.circular(outgoing ? 4 : 16),
          ),
          border: outgoing
              ? null
              : Border.all(color: context.fdColor(AppColors.borderGrey)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (author != null) ...[
              Text(
                author!,
                style: AppTextStyles.caption.copyWith(
                  color: outgoing
                      ? Colors.white70
                      : context.fdColor(AppColors.primaryBlue),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              text,
              style: AppTextStyles.bodyText2.copyWith(
                color: outgoing
                    ? Colors.white
                    : context.fdColor(AppColors.neutralBlack),
              ),
            ),
            if (time != null) ...[
              const SizedBox(height: 5),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  time!,
                  style: AppTextStyles.caption.copyWith(
                    color: outgoing
                        ? Colors.white70
                        : context.fdColor(AppColors.darkGrey),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
