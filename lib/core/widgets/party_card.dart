import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'common.dart';

/// An identity confirmation card for the resolved counterparty (customer /
/// merchant / card holder). Shown after a lookup so the agent visually
/// confirms *who* the operation targets before moving money.
class PartyCard extends StatelessWidget {
  const PartyCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.statusLabel,
    this.statusActive = true,
    this.icon = Icons.person_rounded,
    this.trailing,
  });

  final String name;
  final String subtitle;
  final String? statusLabel;
  final bool statusActive;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LipaCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.brandDeep, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(size: 15.5, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: AppText.mono(size: 13, color: AppColors.inkMid)),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (statusLabel != null)
            StatusPill(
              label: statusLabel!,
              kind: statusActive ? PillKind.success : PillKind.warn,
            ),
        ],
      ),
    );
  }
}
