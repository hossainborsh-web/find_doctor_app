import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/route_names.dart';
import '../core/domain/entities/user_role.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/fd_palette.dart';
import '../core/theme/app_text_style.dart';
import '../core/widgets/fd_widgets.dart';
import 'connect_screens.dart';
import 'content_widgets.dart';
import 'explore_tab.dart';
import 'demo_screens.dart';
import 'prototype_session.dart';
import '../services/account_service.dart';
import '../services/connect_service.dart';
import '../services/hr_service.dart';
import '../services/inventory_service.dart';
import '../services/localization_service.dart';

class RoleShell extends StatefulWidget {
  const RoleShell({super.key, this.initialIndex = 1});

  final int initialIndex;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

/// Lets screens inside the shell switch tabs
/// (0 Home, 1 Explore, 2 Chat, 3 Search, 4 Profile).
class ShellTabs extends InheritedWidget {
  const ShellTabs({super.key, required this.go, required super.child});

  final ValueChanged<int> go;

  static void open(BuildContext context, int index) {
    final tabs = context.getInheritedWidgetOfExactType<ShellTabs>();
    if (tabs != null) {
      tabs.go(index);
    } else if (index == 1) {
      Navigator.pushNamed(context, RouteNames.explore);
    } else if (index == 3) {
      Navigator.pushNamed(context, RouteNames.search);
    }
  }

  @override
  bool updateShouldNotify(ShellTabs oldWidget) => false;
}

class _RoleShellState extends State<RoleShell> {
  late int index = widget.initialIndex.clamp(0, 4);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (session.role == null) {
      return const Scaffold(body: Center(child: Text('Session expired')));
    }
    if (session.role == UserRole.doctor && !session.doctorApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, RouteNames.doctorPendingGate);
      });
    }

    final role = session.role!;
    final pages = <Widget>[
      HomeTab(role: role),
      ExploreTab(role: role),
      ChatHubTab(role: role),
      SearchTab(role: role),
      ProfileTab(role: role),
    ];
    final language = context.watch<LocalizationService>();
    final destinations = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, language.text('home')),
      (Icons.explore_outlined, Icons.explore_rounded, language.text('explore')),
      (
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        language.text('chat')
      ),
      (Icons.search_rounded, Icons.search_rounded, language.text('search')),
      (
        Icons.person_outline_rounded,
        Icons.person_rounded,
        language.text('profile')
      ),
    ];

    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;
    final content = Stack(
      children: [
        for (var pageIndex = 0; pageIndex < pages.length; pageIndex++)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: pageIndex != index,
              child: ExcludeSemantics(
                excluding: pageIndex != index,
                child: AnimatedOpacity(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: pageIndex == index ? 1 : 0,
                  child: AnimatedSlide(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    offset: pageIndex == index
                        ? Offset.zero
                        : const Offset(0.025, 0),
                    child: TickerMode(
                      enabled: pageIndex == index,
                      child: pages[pageIndex],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return ShellTabs(
      go: (value) => setState(() => index = value.clamp(0, 4)),
      child: Scaffold(
      body: isDesktop
          ? Row(
              children: [
                _DesktopPrimaryNavigation(
                  role: role,
                  managerLevel: session.managerLevel,
                  destinations: destinations,
                  currentIndex: index,
                  onTap: (value) => setState(() => index = value),
                  onCreate: () => showCreatePostDialog(context),
                ),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: isDesktop
          ? null
          : FdBottomNav(
              // "Create" sits in the middle (index 2), like Instagram.
              currentIndex: index >= 2 ? index + 1 : index,
              destinations: [
                ...destinations.take(2),
                (Icons.add_box_outlined, Icons.add_box_rounded, 'Create'),
                ...destinations.skip(2),
              ],
              selectedColor: context.fdColor(AppColors.primaryBlue),
              selectedForegroundColor: Colors.white,
              onTap: (value) {
                if (value == 2) {
                  showCreatePostDialog(context);
                  return;
                }
                setState(() => index = value > 2 ? value - 1 : value);
              },
            ),
      ),
    );
  }
}

class _DesktopPrimaryNavigation extends StatelessWidget {
  const _DesktopPrimaryNavigation({
    required this.role,
    required this.managerLevel,
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
    required this.onCreate,
  });

  final UserRole role;
  final ManagerLevel? managerLevel;
  final List<(IconData, IconData, String)> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final connect = context.watch<ConnectService>();
    final me = session.account;
    final chatBadge = connect.totalUnread(me) +
        (me == null ? 0 : connect.pendingRequestsFor(me.email).length);
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sidebarTop, AppColors.sidebarBottom],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const FdMedicalMark(size: 42),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Find Doctor',
                            style: AppTextStyles.subtitle2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                        Text('Medical care platform',
                            style: AppTextStyles.caption
                                .copyWith(color: const Color(0xFFB4B8E8))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Divider(height: 1, color: Color(0x26FFFFFF)),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  'MENU',
                  style: TextStyle(
                    color: Color(0xFF8E93D6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              for (var item = 0; item < destinations.length; item++)
                _DesktopNavigationItem(
                  icon: destinations[item].$1,
                  selectedIcon: destinations[item].$2,
                  label: destinations[item].$3,
                  selected: item == currentIndex,
                  badge: item == 2 ? chatBadge : 0,
                  onTap: () => onTap(item),
                ),
              _DesktopNavigationItem(
                icon: Icons.add_box_outlined,
                selectedIcon: Icons.add_box_rounded,
                label: 'Create',
                selected: false,
                onTap: onCreate,
              ),
              _DesktopNavigationItem(
                icon: session.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                selectedIcon: Icons.dark_mode_rounded,
                label: session.isDarkMode ? 'Light mode' : 'Dark mode',
                selected: false,
                onTap: () => session.setDarkMode(!session.isDarkMode),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Row(
                  children: [
                    FdAvatar(
                      initials: session.displayName
                          .trim()
                          .split(RegExp(r'\s+'))
                          .where((part) => part.isNotEmpty)
                          .take(2)
                          .map((part) => part[0])
                          .join(),
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText2.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                          Text(
                            session.accountTypeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption
                                .copyWith(color: const Color(0xFFB4B8E8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: const Color(0x14FFFFFF),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? selectedIcon : icon,
                    size: 20,
                    color: selected
                        ? AppColors.primaryBlue
                        : const Color(0xFFC7CAF0)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText2.copyWith(
                      color: selected
                          ? AppColors.primaryBlueDark
                          : const Color(0xFFE0E2FA),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  )
                else if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accentTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<PrototypeSession>().account;
    if (account != null && account.isJobSeeker) {
      return const CareerScreen(asTab: true);
    }
    switch (role) {
      case UserRole.patient:
        return const PatientHomeScreen();
      case UserRole.doctor:
        return const DoctorHomeScreen();
      case UserRole.manager:
        return const ManagerHomeScreen();
    }
  }
}

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final language = context.watch<LocalizationService>();
    final firstName = session.displayName.trim().split(' ').first;
    return Scaffold(
      backgroundColor: context.fdColor(AppColors.background),
      appBar: FdAppBar(
        title: '${language.text('hello')}, $firstName',
        subtitle: language.text('homeSubtitle'),
        notificationCount: context
            .watch<ConnectService>()
            .unreadNotifications(session.account?.email),
        onNotificationTap: () =>
            Navigator.pushNamed(context, RouteNames.notifications),
        actions: [
          IconButton(
            tooltip: 'Profile and settings',
            onPressed: () => Navigator.pushNamed(context, RouteNames.settings),
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: context.fdColor(AppColors.surfaceMuted),
              child: Icon(Icons.person_outline_rounded,
                  size: 19, color: context.fdColor(AppColors.primaryBlueDark)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('Find the right care for you',
              style: AppTextStyles.subtitle2.copyWith(
                color: context.fdColor(AppColors.primaryBlueDark),
                fontSize: 17,
              )),
          const SizedBox(height: 12),
          _PatientDiscoveryHero(
            title: language.text('findDoctor'),
            subtitle: language.text('searchSupport'),
            hint: language.text('searchHint'),
            onTap: () => ShellTabs.open(context, 3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PatientQuickAction(
                  icon: Icons.calendar_month_outlined,
                  label: 'My visits',
                  onTap: () => openVisits(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PatientQuickAction(
                  icon: Icons.medical_services_outlined,
                  label: 'Find a doctor',
                  onTap: () => openDoctorDirectory(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PatientQuickAction(
                  icon: Icons.notifications_none_rounded,
                  label: 'Updates',
                  onTap: () =>
                      Navigator.pushNamed(context, RouteNames.notifications),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          FdSectionHeader(
            title: 'Your next visit',
            action: 'All visits',
            onAction: () => openVisits(context),
          ),
          Builder(builder: (context) {
            final email = context.watch<PrototypeSession>().account?.email;
            final upcoming = email == null
                ? const <Visit>[]
                : context.watch<ConnectService>().upcomingVisitsFor(email);
            if (upcoming.isEmpty) {
              return FdEmptyState(
                title: 'No upcoming visits',
                message: 'Book a time with a doctor on Find Doctor. The doctor '
                    'confirms it first.',
                icon: Icons.event_available_outlined,
                actionLabel: 'Find a doctor',
                onAction: () => openDoctorDirectory(context),
              );
            }
            return VisitCard(visit: upcoming.first);
          }),
          const SizedBox(height: 24),
          Builder(builder: (context) {
            final me = context.watch<PrototypeSession>().account;
            final doctors = context
                .watch<ConnectService>()
                .doctors
                .where((doctor) => doctor.email != me?.email)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FdSectionHeader(
                  title: 'Doctors on Find Doctor',
                  action: doctors.isEmpty ? null : language.text('seeAll'),
                  onAction: doctors.isEmpty
                      ? null
                      : () => openDoctorDirectory(context),
                ),
                if (doctors.isEmpty)
                  FdCard(
                    child: Row(children: [
                      Icon(Icons.person_search_outlined,
                          color: context.fdColor(AppColors.primaryBlue)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No doctors have joined yet. Doctors appear here '
                          'once a Doctor Manager approves them.',
                          style: AppTextStyles.bodyText2.copyWith(
                              color: context.fdColor(AppColors.darkGrey)),
                        ),
                      ),
                    ]),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: doctors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: 410,
                        child: RealDoctorTile(doctor: doctors[index]),
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 24),
          FdSectionHeader(
            title: language.text('community'),
            action: language.text('exploreAction'),
            onAction: () => ShellTabs.open(context, 1),
          ),
          FdCard(
            onTap: () => ShellTabs.open(context, 1),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.play_circle_outline_rounded,
                    color: context.fdColor(AppColors.primaryBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Health tips & reels',
                        style: AppTextStyles.bodyText2
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text('Posts and short videos from doctors and the '
                        'community',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: context.fdColor(AppColors.darkGrey)),
            ]),
          ),
          const CommunitySuggestions(),
        ],
      ),
    );
  }
}

class _PatientDiscoveryHero extends StatelessWidget {
  const _PatientDiscoveryHero({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Fixed indigo: stays dark and readable in both themes.
          colors: const [AppColors.primaryBlue, AppColors.primaryBlueDark],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x242563EB),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -65,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.health_and_safety_rounded,
                            size: 14, color: Color(0xFF9BE9E3)),
                        SizedBox(width: 5),
                        Text(
                          'CARE, MADE SIMPLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headline2.copyWith(
                  color: Colors.white,
                  fontSize: 23,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: .82),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: context.fdColor(Colors.white),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: context.fdColor(AppColors.primaryBlue),
                              size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              hint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: context.fdColor(AppColors.darkGrey),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: context.fdColor(AppColors.surfaceMuted),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(Icons.tune_rounded,
                                size: 17,
                                color: context.fdColor(AppColors.primaryBlue)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatientQuickAction extends StatelessWidget {
  const _PatientQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.fdColor(Colors.white),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.fdColor(AppColors.borderGrey)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: context.fdColor(AppColors.primaryBlue), size: 21),
                const SizedBox(height: 7),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.fdColor(AppColors.primaryBlueDark),
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      );
}

class _Weekday extends StatelessWidget {
  const _Weekday(
      {required this.label,
      required this.day,
      this.selected = false,
      this.dotColor});
  final String label;
  final String day;
  final bool selected;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? context.fdColor(AppColors.primaryBlue)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? Colors.white
                      : context.fdColor(AppColors.darkGrey))),
          const SizedBox(height: 5),
          Text(day,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : context.fdColor(AppColors.neutralBlack))),
          if (dotColor != null) ...[
            const SizedBox(height: 5),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? Colors.white : dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ]),
      );
}

String _initialsOf(String name) => name
    .replaceFirst(RegExp(r'^Dr\.?\s+', caseSensitive: false), '')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();

class _HomeStatCard extends StatelessWidget {
  const _HomeStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FdCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.fdColor(AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon,
                    size: 18, color: context.fdColor(AppColors.primaryBlue)),
              ),
              const Spacer(),
              Icon(Icons.north_east_rounded,
                  size: 15, color: context.fdColor(AppColors.darkGrey)),
            ]),
            const SizedBox(height: 12),
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(label),
          ],
        ),
      );
}

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});

  static const _dayColors = {
    DayStatus.available: Color(0xFF16A34A),
    DayStatus.busy: Color(0xFFD97706),
    DayStatus.off: Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final connect = context.watch<ConnectService>();
    final email = session.account?.email ?? '';
    final greetingName = session.displayName.toLowerCase().startsWith('dr')
        ? session.displayName
        : 'Dr. ${session.displayName}';
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final today = connect.doctorVisitsOn(email, now);
    final requests = connect.visitRequestsFor(email);
    final chatRequests = connect.pendingRequestsFor(email);
    final next = connect
        .upcomingVisitsFor(email)
        .where((visit) =>
            visit.doctorEmail == email &&
            visit.status == VisitStatus.confirmed)
        .firstOrNull;
    final schedule = connect.scheduleFor(email);
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final statusNow = connect.statusNowLabel(email);

    return Scaffold(
      appBar: FdAppBar(
        title: 'Find Doctor',
        subtitle: 'Clinical workspace',
        notificationCount: connect.unreadNotifications(email),
        onNotificationTap: () =>
            Navigator.pushNamed(context, RouteNames.notifications),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Text('$greeting, $greetingName',
              style: AppTextStyles.headline1.copyWith(fontSize: 25)),
          const SizedBox(height: 5),
          Text(
              today.isEmpty
                  ? 'No visits booked today · $statusNow'
                  : '${today.length} visit${today.length == 1 ? '' : 's'} '
                      'today · $statusNow',
              style: AppTextStyles.bodyText2
                  .copyWith(color: context.fdColor(AppColors.darkGrey))),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryBlueDark, AppColors.primaryBlue],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22073B78),
                    blurRadius: 18,
                    offset: Offset(0, 7)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('NEXT VISIT',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .7)),
                  ),
                  const Spacer(),
                  if (next != null)
                    Text(visitClock(next.start),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 17),
                Text(next?.patientName ?? 'No confirmed visits yet',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    next == null
                        ? 'Users book visits from your profile, inside your '
                            'weekly schedule. Confirm them under My visits.'
                        : '${visitDayLabel(next.start)} · ${next.reason}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFD5E7F9), fontSize: 13)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 43,
                  child: FilledButton.icon(
                    onPressed: () => next == null
                        ? openScheduleEditor(context)
                        : openVisits(context),
                    icon: Icon(
                        next == null
                            ? Icons.edit_calendar_outlined
                            : Icons.event_note_outlined,
                        size: 18),
                    label: Text(
                        next == null ? 'Set weekly schedule' : 'Open my visits'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryBlueDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FdCard(
            onTap: () => openScheduleEditor(context),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Weekday(
                      label: dayNames[i],
                      day: '${DateTime(monday.year, monday.month, monday.day + i).day}',
                      selected: i == now.weekday - 1,
                      dotColor: _dayColors[schedule[i].status],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 23),
          Row(
            children: [
              Expanded(
                child: _HomeStatCard(
                  icon: Icons.event_note_outlined,
                  value: '${requests.length}',
                  label: 'Visit requests',
                  onTap: () => openVisits(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeStatCard(
                  icon: Icons.mark_chat_unread_outlined,
                  value: '${chatRequests.length}',
                  label: 'Chat requests',
                  onTap: () => ShellTabs.open(context, 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FdButton(
            label: 'Create educational post',
            icon: Icons.edit_outlined,
            onPressed: () => showCreatePostDialog(context),
          ),
          const SizedBox(height: 12),
          FdButton(
            label: 'Create community group',
            icon: Icons.groups_outlined,
            outlined: true,
            onPressed: () => showCreateGroupDialog(context, community: true),
          ),
          const SizedBox(height: 24),
          FdSectionHeader(
              title: "Today's visits",
              action: 'All visits',
              onAction: () => openVisits(context)),
          if (today.isEmpty)
            FdCard(
              child: Text('Nothing booked for today.',
                  style: AppTextStyles.bodyText2
                      .copyWith(color: context.fdColor(AppColors.darkGrey))),
            )
          else
            FdCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < today.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ScheduleEntry(
                      time: visitClock(today[i].start),
                      duration: '${today[i].minutes} min',
                      patient: today[i].patientName,
                      visit: today[i].reason,
                      initials: _initialsOf(today[i].patientName),
                      status: today[i].status == VisitStatus.requested
                          ? 'Request'
                          : today[i].id == next?.id
                              ? 'Next up'
                              : null,
                      onTap: () => openVisits(context),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final connect = context.watch<ConnectService>();
    final inventory = context.watch<InventoryService>();
    context.watch<HrService>();
    final me = session.account;
    final general = session.managerLevel != ManagerLevel.doctorManager;
    final level = session.managerLevel?.displayName ?? 'Manager';
    final now = DateTime.now();
    final isDoctor = ConnectService.isDoctor(me);
    final myRequests =
        me == null ? 0 : connect.visitRequestsFor(me.email).length;
    final doctors =
        me == null ? const <AppAccount>[] : hospitalDoctorsFor(connect, me);
    final today = me == null ? const <Visit>[] : visitsTodayFor(connect, me);
    final alerts = me == null
        ? const <HospitalAlert>[]
        : hospitalAlertsFor(connect, inventory, me);
    final monthVisits = me == null
        ? 0
        : hospitalVisitsFor(connect, me)
            .where((visit) =>
                visit.start.year == now.year && visit.start.month == now.month)
            .length;
    final staffRoom = connect
        .hospitalGroupsFor(me)
        .where((group) => group.staffRoom)
        .firstOrNull;
    final staffUnread = staffRoom == null || me == null
        ? 0
        : connect.unreadCount(staffRoom, me.email);
    final equipment = inventory
        .getItemsByCategory('Equipment', hospital: session.workplace)
        .length;
    final medication = inventory
        .getItemsByCategory('Medication', hospital: session.workplace)
        .length;
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      appBar: FdAppBar(
        title: 'Dashboard',
        subtitle: session.workplace.isEmpty
            ? level
            : '$level · ${session.workplace}',
        notificationCount: connect.unreadNotifications(me?.email),
        onNotificationTap: () =>
            Navigator.pushNamed(context, RouteNames.notifications),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const SizedBox(height: 8),
          Text(
            '$greeting, ${session.displayName.trim().split(' ').first}',
            style: AppTextStyles.headline1.copyWith(fontSize: 25),
          ),
          const SizedBox(height: 5),
          Text(
            general
                ? 'Every hospital on Find Doctor at a glance'
                : 'Your hospital at a glance',
            style: AppTextStyles.bodyText2
                .copyWith(color: context.fdColor(AppColors.darkGrey)),
          ),
          const SizedBox(height: 18),
          const HrSummaryCard(),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 640
                    ? 3
                    : 2;
            final width =
                (constraints.maxWidth - 12 * (columns - 1)) / columns;
            Widget tile(String label, String value, VoidCallback onTap) =>
                SizedBox(
                  width: width,
                  child: _DashTile(label: label, value: value, onTap: onTap),
                );
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (isDoctor)
                  tile(
                      'My visits',
                      myRequests == 0 ? 'Open' : '$myRequests new',
                      () => openVisits(context)),
                tile('Doctors', '${doctors.length}',
                    () => _push(context, const HospitalDoctorsScreen())),
                tile('Visits today', '${today.length}',
                    () => _push(context, const HospitalSchedulesScreen())),
                tile('Alerts', '${alerts.length}',
                    () => _push(context, const HospitalAlertsScreen())),
                tile(
                    'Staff room',
                    staffRoom == null
                        ? 'Chat'
                        : staffUnread > 0
                            ? '$staffUnread new'
                            : 'Open',
                    () => staffRoom == null
                        ? ShellTabs.open(context, 2)
                        : openConversation(context, staffRoom.id)),
                tile('Overview', monthVisits == 1 ? '1 visit' : '$monthVisits visits',
                    () => _push(context, const HospitalOverviewScreen())),
                tile('Equipment', equipment == 1 ? '1 item' : '$equipment items',
                    () => Navigator.pushNamed(context, RouteNames.equipment)),
                tile('Medication', medication == 1 ? '1 item' : '$medication items',
                    () => Navigator.pushNamed(context, RouteNames.medication)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _DashTile extends StatelessWidget {
  const _DashTile(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      'My visits' => Icons.event_note_outlined,
      'Doctors' => Icons.medical_services_outlined,
      'Visits today' => Icons.today_outlined,
      'Alerts' => Icons.notifications_active_outlined,
      'Staff room' => Icons.forum_outlined,
      'Overview' => Icons.insights_rounded,
      'Equipment' => Icons.medical_information_outlined,
      'Medication' => Icons.medication_outlined,
      'Operations' => Icons.monitor_heart_outlined,
      'Meetings' => Icons.groups_2_outlined,
      _ => Icons.dashboard_outlined,
    };
    return SizedBox(
      width: double.infinity,
      child: FdCard(
        onTap: onTap,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.fdColor(AppColors.surfaceMuted),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      size: 19, color: context.fdColor(AppColors.primaryBlue)),
                ),
                const Spacer(),
                Icon(Icons.north_east_rounded,
                    size: 16, color: context.fdColor(AppColors.darkGrey)),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headline2.copyWith(
                fontSize: 22,
                color: context.fdColor(AppColors.primaryBlueDark),
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _ScheduleEntry extends StatelessWidget {
  const _ScheduleEntry({
    required this.time,
    required this.duration,
    required this.patient,
    required this.visit,
    required this.initials,
    required this.onTap,
    this.status,
  });

  final String time;
  final String duration;
  final String patient;
  final String visit;
  final String initials;
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 66,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time,
                      style: AppTextStyles.bodyText2
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(duration, style: AppTextStyles.caption),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 42,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: status == null
                    ? context.fdColor(AppColors.accentTeal)
                    : context.fdColor(AppColors.primaryBlue),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FdAvatar(initials: initials, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        patient,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (status != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.fdColor(AppColors.surfaceMuted),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status!,
                          style: AppTextStyles.caption.copyWith(
                            color: context.fdColor(AppColors.primaryBlue),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ]),
                  Text(visit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.secondary),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: context.fdColor(AppColors.darkGrey), size: 20),
          ],
        ),
      ),
    );
  }
}

class ExploreRouteScreen extends StatelessWidget {
  const ExploreRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<PrototypeSession>().role ?? UserRole.patient;
    return ExploreTab(role: role);
  }
}

class SearchRouteScreen extends StatelessWidget {
  const SearchRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<PrototypeSession>().role ?? UserRole.patient;
    return SearchTab(role: role);
  }
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.role});
  final UserRole role;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String query = '';
  String filter = 'Doctors';
  String specialty = 'All specialties';
  String hospital = 'All hospitals';
  bool availableToday = false;
  String sortBy = 'Name';

  @override
  void initState() {
    super.initState();
    ConnectService.instance.refresh();
  }

  List<String> get filters {
    switch (widget.role) {
      case UserRole.patient:
        return const ['Doctors'];
      case UserRole.doctor:
        return const ['Doctors', 'My patients', 'Colleagues'];
      case UserRole.manager:
        return const ['Doctors', 'Staff'];
    }
  }

  Widget _people(List<(String, String, String)> people, String emptyTitle,
      String emptyMessage) {
    final q = query.trim().toLowerCase();
    final list = people
        .where((person) => '${person.$2} ${person.$3}'.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    if (list.isEmpty) {
      return FdEmptyState(
        title: people.isEmpty ? emptyTitle : 'No one found',
        message: people.isEmpty ? emptyMessage : 'Try another name.',
        icon: Icons.person_search_outlined,
      );
    }
    return Column(
      children: [
        for (final person in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FdPersonTile(
              name: person.$2,
              subtitle: person.$3,
              initials: _initialsOf(person.$2),
              onTap: () => showPersonCard(context,
                  email: person.$1, name: person.$2, subtitle: person.$3),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final connect = context.watch<ConnectService>();
    final me = context.watch<PrototypeSession>().account;
    final q = query.trim().toLowerCase();
    final activeFilter = filters.contains(filter) ? filter : filters.first;

    final allDoctors =
        connect.doctors.where((doctor) => doctor.email != me?.email).toList();
    final specialties = {
      for (final doctor in allDoctors)
        if (doctor.specialty.trim().isNotEmpty) doctor.specialty.trim(),
    }.toList()
      ..sort();
    final hospitals = {
      for (final doctor in allDoctors)
        if (doctor.hospital.trim().isNotEmpty) doctor.hospital.trim(),
    }.toList()
      ..sort();
    final chosenSpecialty =
        specialties.contains(specialty) ? specialty : 'All specialties';
    final chosenHospital =
        hospitals.contains(hospital) ? hospital : 'All hospitals';

    Widget results;
    if (activeFilter == 'Doctors') {
      final list = allDoctors
          .where((doctor) =>
              '${doctor.fullName} ${doctor.specialty} ${doctor.hospital} '
                      '${doctor.typeLabel}'
                  .toLowerCase()
                  .contains(q) &&
              (chosenSpecialty == 'All specialties' ||
                  doctor.specialty.trim() == chosenSpecialty) &&
              (chosenHospital == 'All hospitals' ||
                  doctor.hospital.trim() == chosenHospital) &&
              (!availableToday ||
                  connect.todayFor(doctor.email).status ==
                      DayStatus.available))
          .toList();
      if (sortBy == 'Available first') {
        int rank(AppAccount doctor) =>
            connect.todayFor(doctor.email).status.index;
        list.sort((a, b) => rank(a).compareTo(rank(b)));
      }
      results = list.isEmpty
          ? FdEmptyState(
              title: allDoctors.isEmpty ? 'No doctors yet' : 'No doctors found',
              message: allDoctors.isEmpty
                  ? 'Doctors appear here once a Doctor Manager approves them.'
                  : 'Try another name, specialty or hospital.',
              icon: Icons.search_off,
            )
          : Column(children: [
              for (final doctor in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RealDoctorTile(doctor: doctor),
                ),
            ]);
    } else if (activeFilter == 'My patients') {
      final people = <String, (String, String, String)>{};
      if (me != null) {
        for (final visit in connect.visitsFor(me.email)) {
          if (visit.doctorEmail != me.email) continue;
          people[visit.patientEmail] = (
            visit.patientEmail,
            visit.patientName,
            '${visit.start.isAfter(DateTime.now()) ? 'Upcoming visit' : 'Last visit'} '
                '${ConnectService.fullDate(visit.start)}',
          );
        }
        for (final chat in connect.directChatsFor(me.email)) {
          final other = connect.otherMember(chat, me.email);
          final account = connect.accountByEmail(other);
          if (account == null || ConnectService.isStaff(account)) continue;
          people.putIfAbsent(
              other,
              () => (
                    other,
                    ConnectService.displayName(account),
                    'In your chats',
                  ));
        }
      }
      results = _people(
          people.values.toList(),
          'No patients yet',
          'Users you chat with or who book visits with you appear here.');
    } else {
      final staff = me == null
          ? const <AppAccount>[]
          : widget.role == UserRole.manager && !me.isDoctorManager
              ? connect.accounts
                  .where((account) =>
                      account.email != me.email &&
                      account.status == AccountStatus.active &&
                      ConnectService.isStaff(account))
                  .toList()
              : connect.colleaguesOf(me);
      results = _people(
          [
            for (final account in staff)
              (
                account.email,
                ConnectService.displayName(account),
                [
                  account.typeLabel,
                  if (account.hospital.trim().isNotEmpty) account.hospital,
                ].join(' · '),
              ),
          ],
          'No colleagues yet',
          'Doctors and managers of your hospital appear here.');
    }

    return Scaffold(
      appBar: FdAppBar(
        title: widget.role == UserRole.patient ? 'Find a doctor' : 'Directory',
        subtitle: widget.role == UserRole.patient
            ? 'Doctors on Find Doctor'
            : 'Doctors, patients and colleagues',
        notificationCount: connect.unreadNotifications(me?.email),
        onNotificationTap: () =>
            Navigator.pushNamed(context, RouteNames.notifications),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: activeFilter == 'Doctors'
                      ? 'Search by name, specialty or hospital'
                      : 'Search by name',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              if (filters.length > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in filters)
                      ChoiceChip(
                        label: Text(f),
                        selected: activeFilter == f,
                        showCheckmark: false,
                        selectedColor: context.fdColor(AppColors.primaryBlue),
                        labelStyle: TextStyle(
                          color: activeFilter == f
                              ? Colors.white
                              : context.fdColor(AppColors.neutralBlack),
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => filter = f),
                      ),
                  ],
                ),
              ],
              if (activeFilter == 'Doctors' && allDoctors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('specialty-$chosenSpecialty'),
                      initialValue: chosenSpecialty,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Specialty',
                          prefixIcon: Icon(Icons.medical_services_outlined)),
                      items: [
                        for (final value in ['All specialties', ...specialties])
                          DropdownMenuItem(
                              value: value,
                              child: Text(value,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) => setState(
                          () => specialty = value ?? 'All specialties'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('hospital-$chosenHospital'),
                      initialValue: chosenHospital,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Hospital',
                          prefixIcon: Icon(Icons.local_hospital_outlined)),
                      items: [
                        for (final value in ['All hospitals', ...hospitals])
                          DropdownMenuItem(
                              value: value,
                              child: Text(value,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) =>
                          setState(() => hospital = value ?? 'All hospitals'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  FilterChip(
                    label: const Text('Available today'),
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    selected: availableToday,
                    onSelected: (value) =>
                        setState(() => availableToday = value),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Sort results',
                    initialValue: sortBy,
                    onSelected: (value) => setState(() => sortBy = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Name', child: Text('Name')),
                      PopupMenuItem(
                          value: 'Available first',
                          child: Text('Available first')),
                    ],
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sort_rounded,
                          size: 18,
                          color: context.fdColor(AppColors.primaryBlue)),
                      const SizedBox(width: 4),
                      Text(sortBy,
                          style: AppTextStyles.caption.copyWith(
                              color: context.fdColor(AppColors.primaryBlue),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              results,
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    return Scaffold(
      appBar: FdAppBar(
        title: 'Profile',
        notificationCount: context
            .watch<ConnectService>()
            .unreadNotifications(session.account?.email),
        onNotificationTap: () =>
            Navigator.pushNamed(context, RouteNames.notifications),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                FdAvatar(
                    initials: session.displayName
                        .split(' ')
                        .map((e) => e.isEmpty ? '' : e[0])
                        .take(2)
                        .join(),
                    size: 88),
                const SizedBox(height: 12),
                Text(session.displayName,
                    style: AppTextStyles.headline2.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text(session.accountTypeLabel,
                    style: AppTextStyles.secondary),
                const SizedBox(height: 8),
                FdStatusChip(
                  label: session.verification.displayName,
                  tone: session.verification == VerificationStatus.approved
                      ? FdStatusTone.success
                      : session.verification == VerificationStatus.rejected
                          ? FdStatusTone.danger
                          : FdStatusTone.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FdCard(
            child: Column(
              children: [
                _ProfileRow(label: 'Email', value: session.email),
                const Divider(),
                _ProfileRow(
                    label: role == UserRole.patient ? 'Workplace' : 'Hospital',
                    value: session.workplace.isNotEmpty
                        ? session.workplace
                        : session.account?.isJobSeeker ?? false
                            ? 'Not hired yet (${session.accountTypeLabel})'
                            : '—'),
                if (session.doctorKind != null) ...[
                  const Divider(),
                  _ProfileRow(
                      label: 'Doctor type',
                      value: session.doctorKind!.displayName),
                ],
                if (session.specialty.isNotEmpty) ...[
                  const Divider(),
                  _ProfileRow(label: 'Specialty', value: session.specialty),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FdButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.editProfile),
          ),
          const SizedBox(height: 22),
          const FdSectionHeader(title: 'Account'),
          FdCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _AccountRow(
                    icon: Icons.person_outline,
                    label: 'Personal information',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.editProfile)),
                const Divider(height: 1, indent: 52),
                _AccountRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Account & verification',
                    onTap: () => showAccountStatus(context)),
                const Divider(height: 1, indent: 52),
                if (AccountService.isHr(session.account)) ...[
                  _AccountRow(
                      icon: Icons.badge_outlined,
                      label: 'Hiring & staff',
                      onTap: () => openHrCenter(context)),
                  const Divider(height: 1, indent: 52),
                ],
                if (AccountService.isGeneralManager(session.account)) ...[
                  _AccountRow(
                      icon: Icons.school_outlined,
                      label: 'Demo examples for teachers',
                      onTap: () => openDemoExamples(context)),
                  const Divider(height: 1, indent: 52),
                ],
                if (session.account?.isJobSeeker ?? false) ...[
                  _AccountRow(
                      icon: Icons.work_outline_rounded,
                      label: 'My career',
                      onTap: () => openCareer(context)),
                  const Divider(height: 1, indent: 52),
                ],
                if (role != UserRole.manager ||
                    ConnectService.isDoctor(session.account)) ...[
                  _AccountRow(
                      icon: Icons.event_note_outlined,
                      label: 'My visits',
                      onTap: () => openVisits(context)),
                  const Divider(height: 1, indent: 52),
                ],
                ListTile(
                  leading: Icon(
                      session.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.dark_mode_outlined,
                      color: context.fdColor(AppColors.primaryBlue)),
                  title: Text('Dark mode',
                      style: AppTextStyles.bodyText2
                          .copyWith(fontWeight: FontWeight.w500)),
                  trailing: Switch(
                    value: session.isDarkMode,
                    onChanged: (value) =>
                        context.read<PrototypeSession>().setDarkMode(value),
                  ),
                  onTap: () => context
                      .read<PrototypeSession>()
                      .setDarkMode(!session.isDarkMode),
                ),
                const Divider(height: 1, indent: 52),
                if (ConnectService.isDoctor(session.account)) ...[
                  _AccountRow(
                      icon: Icons.edit_calendar_outlined,
                      label: 'My weekly schedule',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const ScheduleEditorScreen()))),
                  const Divider(height: 1, indent: 52),
                  _AccountRow(
                      icon: Icons.badge_outlined,
                      label: 'My public profile',
                      onTap: () => openDoctorProfile(
                          context, session.account!.email)),
                  const Divider(height: 1, indent: 52),
                ],
                _AccountRow(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.notifications)),
                const Divider(height: 1, indent: 52),
                _AccountRow(
                    icon: Icons.password_rounded,
                    label: 'Change password',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.changePassword)),
                const Divider(height: 1, indent: 52),
                _AccountRow(
                    icon: Icons.lock_outline,
                    label: 'Privacy',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.settings)),
                const Divider(height: 1, indent: 52),
                _AccountRow(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.settings)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FdButton(
            label: 'Sign out',
            outlined: true,
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

void showAccountStatus(BuildContext context) {
  final session = context.read<PrototypeSession>();
  final account = session.account;
  String date(DateTime? value) =>
      value == null ? '—' : ConnectService.fullDate(value);
  final status = switch (account?.status) {
    AccountStatus.active => ('Active', const Color(0xFF16A34A)),
    AccountStatus.pending => ('Waiting for approval', const Color(0xFFD97706)),
    AccountStatus.rejected => ('Not approved', const Color(0xFFC62828)),
    null => (session.verification.displayName, const Color(0xFF64748B)),
  };
  final rows = <(String, String)>[
    ('Account type', session.accountTypeLabel),
    ('Email', session.email),
    if (account != null) ('Member since', date(account.createdAt)),
    if (session.workplace.isNotEmpty) ('Hospital', session.workplace),
    if (account?.documentName != null)
      ('Document sent', account!.documentName!),
    if (account?.reviewedBy != null) ('Reviewed by', account!.reviewedBy!),
    if (account?.reviewedAt != null) ('Reviewed on', date(account!.reviewedAt)),
  ];
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Account & verification'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.$2.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.$1,
                    style: TextStyle(
                        color: status.$2, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows) _ProfileRow(label: row.$1, value: row.$2),
            const SizedBox(height: 8),
            Text(
              account != null && ConnectService.isStaff(account)
                  ? 'Doctor and manager accounts are checked by a Doctor '
                      'Manager before they can see patients.'
                  : 'Your account is ready to book visits and chat with '
                      'doctors.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 100, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.bodyText2)),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: context.fdColor(AppColors.primaryBlue)),
        title: Text(label,
            style:
                AppTextStyles.bodyText2.copyWith(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right,
            color: context.fdColor(AppColors.darkGrey)),
        onTap: onTap,
      );
}
