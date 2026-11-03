import 'package:flutter/material.dart';

import '../core/constants/route_names.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/fd_palette.dart';
import '../core/theme/app_text_style.dart';
import '../core/widgets/fd_widgets.dart';
import 'mock_data.dart';

class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({super.key, required this.doctor, this.size = 56});

  final MockDoctor doctor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = doctor.photoAsset;
    if (photo == null || photo.isEmpty) {
      return FdAvatar(initials: doctor.initials, size: size);
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: context.fdColor(AppColors.surfaceMuted),
      backgroundImage: AssetImage(photo),
    );
  }
}

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, this.onTap});

  final MockDoctor doctor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoctorAvatar(doctor: doctor, size: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(doctor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyText1
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (doctor.verified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded,
                          size: 17,
                          color: context.fdColor(AppColors.accentTeal)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(doctor.specialty,
                    style: AppTextStyles.bodyText2.copyWith(
                      color: context.fdColor(AppColors.primaryBlueDark),
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFE3A82B)),
                    const SizedBox(width: 3),
                    Text(doctor.rating.toStringAsFixed(1),
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 9),
                    Icon(Icons.location_on_outlined,
                        size: 15, color: context.fdColor(AppColors.darkGrey)),
                    const SizedBox(width: 2),
                    Expanded(
                        child: Text(doctor.hospital,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FdStatusChip(
                        label: doctor.available ? 'Available' : 'Unavailable',
                        tone: doctor.available
                            ? FdStatusTone.success
                            : FdStatusTone.neutral),
                    const Spacer(),
                    Text('RM ${doctor.priceRm} / consult',
                        style: AppTextStyles.bodyText2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.fdColor(AppColors.primaryBlueDark))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.doctor,
    required this.date,
    required this.time,
    required this.status,
    required this.type,
    required this.onTap,
  });

  final MockDoctor doctor;
  final String date;
  final String time;
  final String status;
  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status.toLowerCase()) {
      'confirmed' || 'accepted' => FdStatusTone.success,
      'pending' => FdStatusTone.warning,
      'cancelled' || 'declined' || 'rejected' || 'no-show' =>
        FdStatusTone.danger,
      _ => FdStatusTone.neutral,
    };

    return FdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DoctorAvatar(doctor: doctor, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText1.copyWith(
                            color: context.fdColor(AppColors.primaryBlueDark),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(doctor.specialty, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FdStatusChip(label: status, tone: tone),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _AppointmentMeta(
                  icon: Icons.calendar_today_outlined, label: date),
              _AppointmentMeta(icon: Icons.schedule_rounded, label: time),
              _AppointmentMeta(
                icon: type.toLowerCase().contains('video')
                    ? Icons.videocam_outlined
                    : Icons.local_hospital_outlined,
                label: type,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 15, color: context.fdColor(AppColors.darkGrey)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(doctor.hospital,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 19, color: context.fdColor(AppColors.darkGrey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentMeta extends StatelessWidget {
  const _AppointmentMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.fdColor(AppColors.primaryBlue)),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      );
}

class NotificationItem extends StatelessWidget {
  const NotificationItem({
    super.key,
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    this.tone = FdStatusTone.neutral,
    this.onTap,
  });

  final String title;
  final String description;
  final String time;
  final IconData icon;
  final FdStatusTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      FdStatusTone.success => context.fdColor(AppColors.successGreen),
      FdStatusTone.warning => context.fdColor(AppColors.warningOrange),
      FdStatusTone.danger => context.fdColor(AppColors.errorRed),
      FdStatusTone.neutral => context.fdColor(AppColors.primaryBlue),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FdCard(
        onTap: onTap,
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            style: AppTextStyles.bodyText2.copyWith(
                                color:
                                    context.fdColor(AppColors.primaryBlueDark),
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text(time, style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(description, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FdPostCard extends StatefulWidget {
  const FdPostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onComment,
    this.onProfile,
  });

  final MockPost post;
  final VoidCallback? onOpen;
  final VoidCallback? onComment;
  final VoidCallback? onProfile;

  @override
  State<FdPostCard> createState() => _FdPostCardState();
}

class _FdPostCardState extends State<FdPostCard> {
  late int likes;
  bool liked = false;

  @override
  void initState() {
    super.initState();
    likes = widget.post.likes;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return FdCard(
      onTap: widget.onOpen,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onProfile,
            child: Row(
              children: [
                FdAvatar(initials: post.initials, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(post.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText2
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (post.role == 'Doctor') ...[
                          const SizedBox(width: 4),
                          const VerifiedAuthorBadge(),
                        ],
                      ]),
                      Text('${post.role} · ${post.date}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Post options',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showPostOptions(context, post),
                  icon: Icon(Icons.more_horiz_rounded,
                      size: 20, color: context.fdColor(AppColors.darkGrey)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(post.content, style: AppTextStyles.bodyText2),
          const SizedBox(height: 12),
          if (post.role == 'Manager')
            SizedBox(
              width: double.infinity,
              height: 38,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.appointments),
                style: FilledButton.styleFrom(
                  backgroundColor: context.fdColor(AppColors.primaryBlue),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                  textStyle:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('Book Appointment'),
              ),
            )
          else
            _PostMediaPreview(label: post.mediaLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    liked = !liked;
                    likes += liked ? 1 : -1;
                  });
                },
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: liked
                      ? context.fdColor(AppColors.primaryBlue)
                      : context.fdColor(AppColors.darkGrey),
                ),
                label: Text('$likes'),
              ),
              TextButton.icon(
                onPressed: widget.onComment,
                icon: Icon(Icons.mode_comment_outlined, size: 18),
                label: Text('${post.comments}'),
              ),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Post shared to your professional feed.')),
                  );
                },
                icon: Icon(Icons.share_outlined, size: 18),
                label: Text('${post.shares}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostMediaPreview extends StatelessWidget {
  const _PostMediaPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    if (normalized.contains('video')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 154,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/therapy_rehabilitation.png',
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryBlueDark.withValues(alpha: 0.05),
                      AppColors.primaryBlueDark.withValues(alpha: 0.66),
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context
                            .fdColor(AppColors.primaryBlueDark)
                            .withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: context.fdColor(AppColors.primaryBlueDark),
                      size: 30),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText2.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const Positioned(
                right: 12,
                bottom: 12,
                child: Text('04:32',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }
    if (normalized.contains('study') || normalized.contains('pdf')) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.fdColor(AppColors.surfaceMuted),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.fdColor(AppColors.borderGrey)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 52,
              decoration: BoxDecoration(
                color: context.fdColor(Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: context.fdColor(AppColors.borderGrey)),
              ),
              child: Icon(Icons.description_outlined,
                  color: context.fdColor(AppColors.primaryBlue), size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                          color: context.fdColor(AppColors.primaryBlue),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text('Clinical reference material',
                      style: AppTextStyles.bodyText2
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Reviewed by the hospital education team',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: context.fdColor(AppColors.darkGrey)),
          ],
        ),
      );
    }
    return Container(
      height: 154,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.fdColor(AppColors.surfaceMuted),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset(
        'assets/images/therapy_rehabilitation.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

class FdPersonTile extends StatelessWidget {
  const FdPersonTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.initials,
    this.trailing,
    this.onTap,
    this.available,
    this.rating,
  });

  final String name;
  final String subtitle;
  final String initials;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? available;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    return FdCard(
      onTap: onTap,
      child: Row(
        children: [
          FdAvatar(initials: initials, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.bodyText1
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.caption),
                if (rating != null || available != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(Icons.star,
                            size: 16,
                            color: context.fdColor(AppColors.primaryBlue)),
                        const SizedBox(width: 4),
                        Text(rating!.toStringAsFixed(1),
                            style: AppTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                      ],
                      if (available != null)
                        FdStatusChip(
                          label: available! ? 'Available' : 'Unavailable',
                          tone: available!
                              ? FdStatusTone.success
                              : FdStatusTone.warning,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              Icon(Icons.chevron_right,
                  color: context.fdColor(AppColors.darkGrey)),
        ],
      ),
    );
  }
}

/// Blue tick shown next to content from a verified clinician.
class VerifiedAuthorBadge extends StatelessWidget {
  const VerifiedAuthorBadge({super.key, this.size = 15});
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Verified clinician',
        child: Icon(Icons.verified_rounded,
            size: size, color: context.fdColor(AppColors.primaryBlue)),
      );
}

/// Post menu with reporting, so misleading or abusive health content can
/// be flagged for review.
Future<void> showPostOptions(BuildContext context, MockPost post) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Report post'),
          subtitle: const Text('Misleading, harmful or offensive content'),
          onTap: () => Navigator.pop(sheetContext, 'report'),
        ),
        ListTile(
          leading: const Icon(Icons.visibility_off_outlined),
          title: const Text('Not interested'),
          onTap: () => Navigator.pop(sheetContext, 'hide'),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text('About ${post.author}'),
          onTap: () => Navigator.pop(sheetContext, 'author'),
        ),
      ]),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'author':
      Navigator.pushNamed(context, RouteNames.authorProfile, arguments: post);
    case 'hide':
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You will see fewer posts like this.')));
    case 'report':
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Why are you reporting this?'),
          children: [
            for (final r in const [
              'Misleading health information',
              'Presented as a diagnosis',
              'Offensive or abusive',
              'Spam or advertising',
              'Shares private medical details',
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, r),
                child: Text(r),
              ),
          ],
        ),
      );
      if (reason != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Thanks. Our moderation team will review this post.')));
      }
  }
}
