import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../utils/user_notifications.dart';
import 'brand_icon.dart';

/// Bell that opens a bottom sheet of profile notifications.
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.profile,
    this.onViewProfile,
    this.onDark = false,
  });

  final Map<String, dynamic> profile;
  final VoidCallback? onViewProfile;

  /// Light outline and icon for use on the navy hero background.
  final bool onDark;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<String> _readIds = const [];

  String? get _mobile {
    final raw = widget.profile['mobile'];
    if (raw == null) return null;
    final value = '$raw'.trim();
    return value.isEmpty ? null : value;
  }

  List<UserNotification> get _notifications =>
      notificationsFromProfile(widget.profile);

  int get _unreadCount =>
      _notifications.where((item) => !_readIds.contains(item.id)).length;

  @override
  void initState() {
    super.initState();
    _loadReadIds();
  }

  @override
  void didUpdateWidget(NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ('${oldWidget.profile['mobile']}' != '${widget.profile['mobile']}') {
      _loadReadIds();
    }
  }

  Future<void> _loadReadIds() async {
    final ids = await getReadNotificationIds(_mobile);
    if (mounted) setState(() => _readIds = ids);
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '';
    // Avoid locale data init — plain DateFormat works without initializeDateFormatting.
    return DateFormat('dd MMM, hh:mm a').format(parsed.toLocal());
  }

  String _iconFor(String? type) {
    if (type == 'loan_approved') return 'check';
    if (type == 'action_required') return 'document';
    return 'clock';
  }

  Future<void> _openSheet() async {
    await _loadReadIds();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _NotificationSheet(
          notifications: _notifications,
          readIds: _readIds,
          formatDate: _formatDate,
          iconFor: _iconFor,
          onMarkAllRead: () async {
            await markAllNotificationsRead(
              _mobile,
              _notifications.map((item) => item.id).toList(),
            );
            final ids = await getReadNotificationIds(_mobile);
            if (mounted) setState(() => _readIds = ids);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
          onSelect: (notification) async {
            await markNotificationRead(_mobile, notification.id);
            await _loadReadIds();
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            widget.onViewProfile?.call();
          },
        );
      },
    );

    // Refresh badge after the sheet closes (mark-all / select may have updated).
    await _loadReadIds();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unreadCount;

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: widget.onDark ? const Color(0x1AFFFFFF) : Colors.transparent,
            shape: CircleBorder(
              side: BorderSide(
                color: widget.onDark ? const Color(0x4DFFFFFF) : AppColors.line,
              ),
            ),
            child: InkWell(
              onTap: _openSheet,
              customBorder: const CircleBorder(),
              highlightColor: widget.onDark
                  ? const Color(0x33FFFFFF)
                  : AppColors.brandSoft,
              child: Center(
                child: BrandIcon(
                  'bell',
                  size: 20,
                  color: widget.onDark ? Colors.white : AppColors.navy,
                ),
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                height: 16,
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.emerald600,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({
    required this.notifications,
    required this.readIds,
    required this.formatDate,
    required this.iconFor,
    required this.onMarkAllRead,
    required this.onSelect,
  });

  final List<UserNotification> notifications;
  final List<String> readIds;
  final String Function(String?) formatDate;
  final String Function(String?) iconFor;
  final VoidCallback onMarkAllRead;
  final ValueChanged<UserNotification> onSelect;

  @override
  Widget build(BuildContext context) {
    final unread = notifications
        .where((item) => !readIds.contains(item.id))
        .length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate200,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                if (unread > 0)
                  TextButton(
                    onPressed: onMarkAllRead,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.slate500,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Flexible(
            child: notifications.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(20, 40, 20, 40 + bottomInset),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 36,
                          color: AppColors.slate300,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No notifications yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(bottom: 12 + bottomInset),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationRow(
                        notification: notification,
                        isRead: readIds.contains(notification.id),
                        onTap: () => onSelect(notification),
                        dateLabel: formatDate(notification.createdAt),
                        iconName: iconFor(notification.type),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.isRead,
    required this.onTap,
    required this.dateLabel,
    required this.iconName,
  });

  final UserNotification notification;
  final bool isRead;
  final VoidCallback onTap;
  final String dateLabel;
  final String iconName;

  @override
  Widget build(BuildContext context) {
    final approved = notification.isApproved;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead
            ? Colors.white
            : AppColors.emerald50.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(top: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: approved ? AppColors.emerald100 : AppColors.slate100,
              ),
              child: BrandIcon(
                iconName,
                size: 16,
                color: approved ? AppColors.emerald700 : AppColors.slate600,
              ),
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
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate900,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6, left: 8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.emerald600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.slate600,
                    ),
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate400,
                      ),
                    ),
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
