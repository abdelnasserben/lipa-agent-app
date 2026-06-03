import '../../core/utils/formatters.dart';
import 'enums.dart';

/// `NotificationResponse` (spec §5.8). Title/body are pre-rendered French.
///
/// MVP reality: the agent inbox is empty today (the backend does not target
/// agents as recipients yet), but the model and endpoints are wired so it
/// lights up automatically when agent-targeted categories are added.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.status,
    this.data,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String category;
  final String title;
  final String body;
  final NotificationStatus status;
  final String? data;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isUnread => status.isUnread;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] ?? '') as String,
        category: (json['category'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        body: (json['body'] ?? '') as String,
        status: NotificationStatus.parse(json['status'] as String?),
        data: json['data'] as String?,
        createdAt: tryParseInstant(json['createdAt']),
        readAt: tryParseInstant(json['readAt']),
      );

  AppNotification asRead() => AppNotification(
        id: id,
        category: category,
        title: title,
        body: body,
        status: NotificationStatus.read,
        data: data,
        createdAt: createdAt,
        readAt: readAt ?? DateTime.now(),
      );
}
