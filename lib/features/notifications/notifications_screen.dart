import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/notification.dart';
import '../agent/agent_providers.dart';

/// Shared notification inbox (spec §5.8). MVP reality: the agent inbox is empty
/// today — the backend does not target agents as recipients yet. The screen is
/// wired and renders a clean empty state until that changes.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Notifications',
              onBack: () => Navigator.of(context).pop(),
              action: TextButton(
                onPressed: () async {
                  await ref
                      .read(agentRepositoryProvider)
                      .markAllNotificationsRead();
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadCountProvider);
                },
                child: Text('Tout lire',
                    style: AppText.ui(size: 13, color: AppColors.brand)),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadCountProvider);
                  await ref.read(notificationsProvider.future);
                },
                child: notifications.when(
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand)),
                  error: (_, _) => ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          ErrorRetry(message: 'Notifications indisponibles.'),
                    ),
                  ]),
                  data: (items) {
                    if (items.isEmpty) {
                      return ListView(children: const [
                        EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'Aucune notification',
                          message:
                              'Vos alertes apparaîtront ici dès qu’elles seront disponibles.',
                        ),
                      ]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _NotifRow(
                        notif: items[i],
                        onTap: () async {
                          await ref
                              .read(agentRepositoryProvider)
                              .markNotificationRead(items[i].id);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadCountProvider);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.notif, required this.onTap});
  final AppNotification notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: LipaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: notif.isUnread ? AppColors.brand : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif.title,
                      style: AppText.ui(
                          size: 14,
                          weight: notif.isUnread
                              ? FontWeight.w700
                              : FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(notif.body,
                      style: AppText.ui(
                          size: 13, color: AppColors.inkMid, height: 1.45)),
                  if (notif.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(fmtRelativeFr(notif.createdAt!),
                        style:
                            AppText.ui(size: 11.5, color: AppColors.inkLow)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
