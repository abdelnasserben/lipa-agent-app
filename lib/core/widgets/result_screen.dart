import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'common.dart';

/// A success / outcome screen shown after a completed operation (cash-in,
/// cash-out, card sale/replacement, enrollment). A green check hero, the key
/// figure, a detail card, and a primary "Terminé" action that pops back to the
/// flow's entry point.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.title,
    required this.headline,
    this.subtitle,
    this.detail,
    required this.onDone,
    this.kind = ResultKind.success,
    this.replayed = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String headline;
  final String? subtitle;
  final Widget? detail;
  final VoidCallback onDone;
  final ResultKind kind;
  final bool replayed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (kind) {
      ResultKind.success =>
        (Icons.check_rounded, AppColors.brandDeep, AppColors.brandSoft),
      ResultKind.pending =>
        (Icons.hourglass_top_rounded, AppColors.warn, AppColors.warnSoft),
      ResultKind.info =>
        (Icons.info_outline_rounded, AppColors.info, AppColors.infoSoft),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDone();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: title),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(color: bg, shape: BoxShape.circle),
                        child: Icon(icon, size: 40, color: color),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(headline,
                        textAlign: TextAlign.center,
                        style: AppText.ui(
                            size: 22,
                            weight: FontWeight.w700,
                            letterSpacing: -0.4)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitle!,
                          textAlign: TextAlign.center,
                          style: AppText.ui(
                              size: 14, color: AppColors.inkMid, height: 1.5)),
                    ],
                    if (replayed) ...[
                      const SizedBox(height: 14),
                      const InfoBanner(
                        kind: PillKind.info,
                        icon: Icons.replay_rounded,
                        text:
                            'Opération déjà traitée — résultat précédent renvoyé (idempotent).',
                      ),
                    ],
                    if (detail != null) ...[
                      const SizedBox(height: 20),
                      detail!,
                    ],
                    const SizedBox(height: 24),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      LipaButton(
                        label: secondaryLabel!,
                        variant: BtnVariant.secondary,
                        size: BtnSize.lg,
                        full: true,
                        onPressed: onSecondary,
                      ),
                      const SizedBox(height: 10),
                    ],
                    LipaButton(
                      label: 'Terminé',
                      size: BtnSize.lg,
                      full: true,
                      onPressed: onDone,
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

enum ResultKind { success, pending, info }
