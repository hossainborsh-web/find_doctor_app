import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/fd_palette.dart';
import '../theme/app_text_style.dart';

class FdAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FdAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final List<Widget>? actions;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 68 : 76);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.fdColor(AppColors.background),
      foregroundColor: context.fdColor(AppColors.primaryBlueDark),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: const BackButtonIcon(),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: subtitle == null
          ? Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headline2.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.fdColor(AppColors.primaryBlueDark),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline2.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.fdColor(AppColors.primaryBlueDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
      actions: [
        if (onNotificationTap != null)
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationTap,
            icon: Badge(
              isLabelVisible: notificationCount > 0,
              label: Text('$notificationCount'),
              backgroundColor: AppColors.primaryBlue,
              child: Icon(Icons.notifications_outlined),
            ),
          ),
        ...?actions,
        const SizedBox(width: 4),
      ],
    );
  }
}

class FdMedicalMark extends StatelessWidget {
  const FdMedicalMark({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.fdColor(AppColors.surfaceMuted),
        shape: BoxShape.circle,
        border: Border.all(color: context.fdColor(AppColors.borderGrey)),
      ),
      child: Image.asset(
        'assets/images/find_doctor_logo.png',
        width: size * 0.86,
        height: size * 0.86,
        fit: BoxFit.contain,
      ),
    );
  }
}

class FdButton extends StatelessWidget {
  const FdButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.destructive = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = destructive ? AppColors.errorRed : AppColors.primaryBlue;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor:
                destructive ? AppColors.errorRed : AppColors.primaryBlue,
            side: BorderSide(
              color: destructive
                  ? AppColors.errorRed
                  : context.fdColor(AppColors.borderGrey),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      ),
    );
  }
}

class FdCard extends StatelessWidget {
  const FdCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.fdColor(AppColors.cardBackground),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.fdColor(AppColors.borderGrey)),
        boxShadow: context.isNightMode
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F4F46E5),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: content,
      ),
    );
  }
}

class FdTextField extends StatelessWidget {
  const FdTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.suffix,
    this.validator,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                AppTextStyles.bodyText2.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class FdStatusChip extends StatelessWidget {
  const FdStatusChip({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final FdStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (tone) {
      case FdStatusTone.success:
        color = AppColors.successGreen;
        break;
      case FdStatusTone.warning:
        color = AppColors.warningOrange;
        break;
      case FdStatusTone.danger:
        color = AppColors.errorRed;
        break;
      case FdStatusTone.neutral:
        color = context.fdColor(AppColors.darkGrey);
        break;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

enum FdStatusTone { success, warning, danger, neutral }

class FdPreviewNotice extends StatelessWidget {
  const FdPreviewNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: context.fdColor(AppColors.surfaceMuted),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 17, color: context.fdColor(AppColors.primaryBlue)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.fdColor(AppColors.primaryBlueDark),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FdAvatar extends StatelessWidget {
  const FdAvatar({
    super.key,
    required this.initials,
    this.size = 48,
    this.imageUrl,
  });

  final String initials;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.fdColor(AppColors.cardBackground),
        border: Border.all(color: context.fdColor(AppColors.borderGrey)),
      ),
      child: CircleAvatar(
        radius: size / 2 - 2,
        backgroundColor: context.fdColor(AppColors.surfaceMuted),
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null
            ? Text(
                initials,
                style: AppTextStyles.bodyText2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.fdColor(AppColors.primaryBlueDark),
                  fontSize: size * 0.32,
                ),
              )
            : null,
      ),
    );
  }
}

class FdEmptyState extends StatelessWidget {
  const FdEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: context.fdColor(AppColors.surfaceMuted),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 38, color: context.fdColor(AppColors.primaryBlue)),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: AppTextStyles.subtitle2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: AppTextStyles.secondary, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FdButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class FdErrorState extends StatelessWidget {
  const FdErrorState({
    super.key,
    this.title = 'Unable to load',
    this.message =
        'Please try again. If the issue continues, contact hospital support.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return FdEmptyState(
      title: title,
      message: message,
      icon: Icons.error_outline,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

class FdLoadingState extends StatelessWidget {
  const FdLoadingState({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label, style: AppTextStyles.secondary),
        ],
      ),
    );
  }
}

class FdSectionHeader extends StatelessWidget {
  const FdSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.subtitle2)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child:
                  Text(action!, style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class FdBottomNav extends StatelessWidget {
  const FdBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
    this.selectedColor = AppColors.primaryBlue,
    this.selectedForegroundColor = Colors.white,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> destinations;
  final Color selectedColor;
  final Color selectedForegroundColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.fdColor(selectedColor);
    final inactiveColor = context.fdColor(AppColors.darkGrey);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.fdColor(AppColors.cardBackground),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.fdColor(AppColors.borderGrey)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1E1B4B),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            children: List.generate(destinations.length, (index) {
              final selected = index == currentIndex;
              final destination = destinations[index];
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: destination.$3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? activeColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? destination.$2 : destination.$1,
                            size: 21,
                            color: selected
                                ? selectedForegroundColor
                                : inactiveColor,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            destination.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              color: selected
                                  ? selectedForegroundColor
                                  : inactiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
