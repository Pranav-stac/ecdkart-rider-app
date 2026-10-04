import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/services/notification_service.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await NotificationService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await NotificationService.markAllAsRead();
    await _loadNotifications();
  }

  Future<void> _clearAll() async {
    await NotificationService.clearNotifications();
    await _loadNotifications();
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return 'Just now';
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0C8346);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                if (_notifications.isNotEmpty) ...[
                  TextButton(
                    onPressed: _markAllRead,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Mark read',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: primaryGreen),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                    tooltip: 'Clear all',
                    onPressed: _clearAll,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_none_rounded,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Notifications Yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You will receive notifications here for account approvals, incoming orders, and earnings updates.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final isRead = notif['isRead'] == true;
                          final isApproval = notif['type'] == 'APPROVAL' ||
                              (notif['title']?.toString().toLowerCase().contains('rider approved') ?? false) ||
                              (notif['title']?.toString().toLowerCase().contains('profile approved') ?? false);
                          final isOrder = notif['type'] == 'ORDER' ||
                              (notif['title']?.toString().toLowerCase().contains('order') ?? false);
                          final isPayoutApproved = notif['type'] == 'PAYOUT_APPROVED' ||
                              (notif['title']?.toString().toLowerCase().contains('payout approved') ?? false) ||
                              (notif['title']?.toString().toLowerCase().contains('withdrawal approved') ?? false);
                          final isPayoutRejected = notif['type'] == 'PAYOUT_REJECTED' ||
                              (notif['title']?.toString().toLowerCase().contains('payout rejected') ?? false) ||
                              (notif['title']?.toString().toLowerCase().contains('withdrawal rejected') ?? false);
                          final isPayout = isPayoutApproved || isPayoutRejected ||
                              notif['type'] == 'PAYOUT_REQUESTED' ||
                              (notif['title']?.toString().toLowerCase().contains('payout') ?? false) ||
                              (notif['title']?.toString().toLowerCase().contains('withdrawal') ?? false);

                          Color iconColor = primaryGreen;
                          IconData iconData = Icons.notifications_rounded;
                          Color bgBadgeColor = primaryGreen.withValues(alpha: 0.1);

                          if (isApproval) {
                            iconColor = const Color(0xFF0C8346);
                            iconData = Icons.verified_rounded;
                            bgBadgeColor = const Color(0xFF0C8346).withValues(alpha: 0.12);
                          } else if (isPayoutRejected) {
                            iconColor = Colors.red[700]!;
                            iconData = Icons.cancel_outlined;
                            bgBadgeColor = Colors.red.withValues(alpha: 0.12);
                          } else if (isPayout) {
                            iconColor = const Color(0xFF0284C7);
                            iconData = Icons.account_balance_wallet_rounded;
                            bgBadgeColor = const Color(0xFF0284C7).withValues(alpha: 0.12);
                          } else if (isOrder) {
                            iconColor = Colors.orange[800]!;
                            iconData = Icons.delivery_dining_rounded;
                            bgBadgeColor = Colors.orange.withValues(alpha: 0.12);
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: isRead ? Colors.white : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isRead ? Colors.grey[200]! : primaryGreen.withValues(alpha: 0.3),
                                width: isRead ? 1 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: bgBadgeColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconData, color: iconColor, size: 22),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif['title'] ?? 'Notification',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTime(notif['timestamp']?.toString()),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notif['body'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF475569),
                                        height: 1.35,
                                      ),
                                    ),
                                    if (isPayoutApproved && notif['data'] != null) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (notif['data']['paidVia'] != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                (notif['data']['paidVia'] ?? '').toString().toUpperCase(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF0284C7),
                                                ),
                                              ),
                                            ),
                                          if (notif['data']['utrNumber'] != null && notif['data']['utrNumber'].toString().isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0C8346).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Ref: ${notif['data']['utrNumber']}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF0C8346),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
