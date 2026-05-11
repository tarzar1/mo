import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'chat_list_screen.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> with WidgetsBindingObserver {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
      _connectWs();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _stopPolling();
    _disconnectWs();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectWs();
      _startPolling();
      _loadNotifications();
    } else {
      _stopPolling();
      _disconnectWs();
    }
  }

  void _connectWs() {
    final token = ref.read(driverApiProvider).token;
    if (token != null) {
      ref.read(notificationsProvider.notifier).connectNotificationWs(token);
    }
  }

  void _disconnectWs() {
    ref.read(notificationsProvider.notifier).disconnectNotificationWs();
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadNotifications();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _loadNotifications() {
    final user = ref.read(userProfileProvider);
    if (user.id.isNotEmpty) {
      ref.read(notificationsProvider.notifier).loadNotifications(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final notifications = ref.watch(notificationsProvider);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light).scaffoldBackgroundColor;
    final card = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textPri = isDark ? Colors.white : const Color(0xFF0D1E30);
    final textSec = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;
    final primary = AppThemes.primaryColor(appTheme, isDark);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: card,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Text(
                    'Notificaciones',
                    style: TextStyle(
                      color: textPri,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(notificationsProvider.notifier).markAllRead();
                      },
                      child: Text(
                        'Leer todas',
                        style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Vaciar notificaciones'),
                            content: const Text('¿Eliminar todas las notificaciones?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref.read(notificationsProvider.notifier).clearAll();
                                },
                                child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        'Vaciar',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Notifications list
          if (notifications.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 64,
                      color: textSec,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes notificaciones',
                      style: TextStyle(
                        color: textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aquí aparecerán tus notificaciones',
                      style: TextStyle(color: textSec, fontSize: 13),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOut),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final notification = notifications[i];
                  return Dismissible(
                    key: ValueKey(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                    ),
                    onDismissed: (_) {
                      ref.read(notificationsProvider.notifier).removeNotification(notification.id);
                    },
                    child: _NotificationCard(
                      notification: notification,
                      isDark: isDark,
                      card: card,
                      textPri: textPri,
                      textSec: textSec,
                      border: border,
                      onTap: () {
                        ref
                            .read(notificationsProvider.notifier)
                            .markRead(notification.id);
                        _handleNotificationTap(
                            context, ref, notification);
                      },
                    ).animate().fadeIn(
                        delay: Duration(milliseconds: 60 * i),
                        duration: 400.ms).slideX(begin: 0.1, curve: Curves.easeOut),
                  );
                },
                childCount: notifications.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) {
    switch (notification.type) {
      case NotificationType.message:
        ref.read(bottomNavIndexProvider.notifier).state = 2;
        if (notification.targetId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                conversationId: notification.targetId!,
              ),
            ),
          );
        }
      case NotificationType.rideRequest:
        ref.read(bottomNavIndexProvider.notifier).state = 1;
      case NotificationType.payment:
        ref.read(bottomNavIndexProvider.notifier).state = 3;
      case NotificationType.system:
        break;
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final Color card;
  final Color textPri;
  final Color textSec;
  final Color border;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.card,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? card
              : notification.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead ? border : notification.color.withValues(alpha: 0.3),
            width: notification.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                notification.icon,
                color: notification.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: textPri,
                            fontSize: 14,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: notification.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.time),
                    style: TextStyle(
                      color: textSec,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) => formatRelativeTime(t);
}
