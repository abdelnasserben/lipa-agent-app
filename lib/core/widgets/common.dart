import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

enum BtnVariant { primary, primaryDark, secondary, ghost, danger, dangerOutline }

enum BtnSize { sm, md, lg }

/// Atom button, matching the Lipa design's `Btn`.
class LipaButton extends StatelessWidget {
  const LipaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = BtnVariant.primary,
    this.size = BtnSize.md,
    this.icon,
    this.full = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BtnVariant variant;
  final BtnSize size;
  final Widget? icon;
  final bool full;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final (h, px, fs, gap) = switch (size) {
      BtnSize.sm => (32.0, 12.0, 13.0, 6.0),
      BtnSize.md => (44.0, 16.0, 14.5, 8.0),
      BtnSize.lg => (52.0, 22.0, 15.5, 10.0),
    };
    final (bg, fg, bd) = switch (variant) {
      BtnVariant.primary => (AppColors.brand, Colors.white, AppColors.brand),
      BtnVariant.primaryDark =>
        (AppColors.nearBlack, Colors.white, AppColors.nearBlack),
      BtnVariant.secondary =>
        (AppColors.surface, AppColors.inkHi, AppColors.borderHi),
      BtnVariant.ghost =>
        (Colors.transparent, AppColors.inkHi, Colors.transparent),
      BtnVariant.danger => (AppColors.danger, Colors.white, AppColors.danger),
      BtnVariant.dangerOutline =>
        (AppColors.surface, AppColors.danger, AppColors.danger),
    };
    final disabled = onPressed == null || loading;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: SizedBox(
        width: full ? double.infinity : null,
        height: h,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: disabled ? null : onPressed,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: px),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: bd),
              ),
              child: Row(
                mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: fg),
                    )
                  else if (icon != null)
                    IconTheme(
                        data: IconThemeData(color: fg, size: 18), child: icon!),
                  if ((icon != null || loading)) SizedBox(width: gap),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(
                        size: fs,
                        weight: FontWeight.w600,
                        color: fg,
                        letterSpacing: -0.07,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum PillKind { success, pending, declined, warn, info, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.kind = PillKind.success});

  final String label;
  final PillKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.success => (AppColors.brandSoft, AppColors.brandDeep),
      PillKind.pending => (AppColors.pendingSoft, const Color(0xFF3F3D39)),
      PillKind.declined => (AppColors.dangerSoft, AppColors.danger),
      PillKind.warn => (AppColors.warnSoft, AppColors.warn),
      PillKind.info => (AppColors.infoSoft, AppColors.info),
      PillKind.neutral => (const Color(0xFFEFECE4), const Color(0xFF3F3D39)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.ui(size: 11, weight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// A small circular icon button (the bell / search / download header buttons).
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.child,
    this.onTap,
    this.badge,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: const BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: onTap,
              child: Center(
                child: IconTheme(
                  data: const IconThemeData(color: AppColors.inkHi, size: 20),
                  child: child,
                ),
              ),
            ),
          ),
          if (badge != null) Positioned(top: -2, right: -2, child: badge!),
        ],
      ),
    );
  }
}

/// Red numeric badge for the notifications bell.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(text,
          style: AppText.ui(
              size: 10, weight: FontWeight.w700, color: Colors.white)),
    );
  }
}

/// Screen header with optional back button + trailing action.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.action,
    this.subtitle,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? action;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          if (onBack != null) ...[
            CircleButton(
              onTap: onBack,
              child: const Icon(Icons.arrow_back, size: 20),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.ui(
                        size: 19,
                        weight: FontWeight.w700,
                        letterSpacing: -0.28)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: AppText.ui(
                            size: 12.5, color: AppColors.inkMid)),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// A label/value row inside a white detail card.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.copy = false,
    this.last = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool mono;
  final bool copy;
  final bool last;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(label, style: AppText.ui(size: 13, color: AppColors.inkMid)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: mono
                        ? AppText.mono(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: valueColor ?? AppColors.inkHi)
                        : AppText.ui(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: valueColor ?? AppColors.inkHi),
                  ),
                ),
                if (copy)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.copy_rounded,
                        size: 14, color: AppColors.inkLow),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A white rounded card container.
class LipaCard extends StatelessWidget {
  const LipaCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.xl,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Info / warn / danger banner box.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.kind = PillKind.info,
  });

  final String text;
  final IconData icon;
  final PillKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.warn => (AppColors.warnSoft, AppColors.warn),
      PillKind.declined => (AppColors.dangerSoft, AppColors.danger),
      PillKind.success => (AppColors.brandSoft, AppColors.brandDeep),
      _ => (AppColors.infoSoft, AppColors.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppText.ui(size: 12.5, color: fg, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// Centered empty-state block (used by lists with no data, e.g. notifications).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.inkLow, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.ui(size: 15, weight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center,
                style: AppText.ui(
                    size: 13, color: AppColors.inkMid, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// Inline error block for failed `AsyncValue` loads, with a retry affordance.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LipaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: AppText.ui(size: 13, color: AppColors.inkMid)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            LipaButton(
              label: 'Réessayer',
              variant: BtnVariant.secondary,
              size: BtnSize.sm,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
