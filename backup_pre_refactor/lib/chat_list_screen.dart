import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'driver_api_service.dart' show MessageStatus;
import 'new_chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> with WidgetsBindingObserver {
  Timer? _pollingTimer;
  bool _appInForeground = true;

  String _formatTime(DateTime t) => formatRelativeTime(t);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_appInForeground && mounted) {
        _checkForNewMessages();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  final Map<String, String> _previousLastMessages = {};

  Future<void> _checkForNewMessages() async {
    final userId = ref.read(userProfileProvider).id;
    if (userId.isEmpty) return;
    
    try {
      final newConversations = await ref.read(driverApiProvider).getConversations(userId);
      final currentConvId = ref.read(currentConversationIdProvider);
      
      for (final newConv in newConversations) {
        final previousLastMsg = _previousLastMessages[newConv.id];
        if (previousLastMsg != null && previousLastMsg != newConv.lastMessage) {
          ref.read(conversationsProvider.notifier).updateConversationMeta(
            newConv.id,
            lastMessage: newConv.lastMessage,
            lastTime: DateTime.tryParse(newConv.lastTime ?? '') ?? DateTime.now(),
          );
          if (currentConvId != newConv.id) {
            final convName = _getConversationName(newConv.id);
            ref.read(notificationsProvider.notifier).addLocalNotification(
              title: 'Nuevo mensaje',
              body: '$convName: ${newConv.lastMessage}',
              type: NotificationType.message,
              targetId: newConv.id,
            );
          }
}
        _previousLastMessages[newConv.id] = newConv.lastMessage;
      }
    } catch (e) {
      debugPrint('Check new messages error: $e');
    }
  }

  String _getConversationName(String conversationId) {
    final conversations = ref.read(conversationsProvider);
    final conv = conversations.where((c) => c.id == conversationId).firstOrNull;
    return conv?.name ?? 'Chat';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light).scaffoldBackgroundColor;
    final card = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final primary = AppThemes.primaryColor(appTheme, isDark);
    final textPri = isDark ? Colors.white : const Color(0xFF0D1E30);
    final textSec = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;

    final conversations = ref.watch(conversationsProvider);
    final totalUnread = conversations.fold(0, (sum, c) => sum + c.unread);

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mensajes',
                          style: TextStyle(
                              color: textPri,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      if (totalUnread > 0)
                        Text('$totalUnread sin leer',
                            style: TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_outlined, color: primary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Conversations
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final conv = conversations[i];
                return Dismissible(
                  key: ValueKey(conv.id),
                  direction: DismissDirection.endToStart,
                  dismissThresholds: const {DismissDirection.endToStart: 0.35},
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar chat'),
                        content: Text('¿Eliminar el chat con ${conv.name}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ) ?? false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    margin: EdgeInsets.fromLTRB(16, i == 0 ? 12 : 0, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                  ),
                  onDismissed: (_) {
                    ref.read(conversationsProvider.notifier).deleteConversation(conv.id);
                  },
                  child: GestureDetector(
                  onTap: () {
                    ref
                        .read(conversationsProvider.notifier)
                        .markAsRead(conv.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatDetailScreen(conversationId: conv.id),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.fromLTRB(16, i == 0 ? 12 : 0, 16, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            conv.unread > 0 ? primary.withValues(alpha: 0.3) : border,
                        width: conv.unread > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: primary.withValues(alpha: 0.15),
                              child: Text(conv.avatar,
                                  style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                            if (conv.isOnline)
                              Positioned(
                                bottom: 1,
                                right: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: card, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(conv.name,
                                      style: TextStyle(
                                          color: textPri,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  const Spacer(),
                                  Text(_formatTime(conv.lastTime),
                                      style: TextStyle(
                                          color: textSec, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conv.lastMessage,
                                      style: TextStyle(
                                        color:
                                            conv.unread > 0 ? textPri : textSec,
                                        fontSize: 12,
                                        fontWeight: conv.unread > 0
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (conv.unread > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: primary,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text('${conv.unread}',
                                          style:  TextStyle(
                                              color: !isDark ? Colors.white : Colors.black,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],)
                    ),
                  ),
                ).animate().fadeIn(
                    delay: Duration(milliseconds: 60 * i),
                    duration: 400.ms).slideX(begin: 0.1, curve: Curves.easeOut);
              },
              childCount: conversations.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── CHAT DETAIL SCREEN ───────────────────────────────────────────────────────
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatDetailScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  WebSocket? _ws;
  StreamSubscription? _wsSubscription;
  bool _appInForeground = true;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentConversationIdProvider.notifier).state = widget.conversationId;
      _ensureLoaded();
      _connectWebSocket();
      _startPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) {
      _ensureLoaded();
      _connectWebSocket();
      _startPolling();
    } else {
      _stopPolling();
      _ws?.close();
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appInForeground && mounted) {
        _refreshMessages();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _refreshMessages() async {
    final userId = ref.read(userProfileProvider).id;
    if (userId.isEmpty) return;
    try {
      await ref.read(conversationsProvider.notifier).loadMessages(
        widget.conversationId, userId,
      );
      final conv = ref.read(conversationsProvider).where((c) => c.id == widget.conversationId).firstOrNull;
      if (conv != null) {
        final unreadIds = conv.messages
            .where((m) => !m.isMe && m.status != MessageStatus.read)
            .map((m) => m.id)
            .toList();
        if (unreadIds.isNotEmpty) {
          ref.read(conversationsProvider.notifier).updateMessageStatus(
            widget.conversationId, unreadIds, MessageStatus.read,
          );
          _sendWsMessage({'type': 'message_read', 'message_ids': unreadIds});
        }
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  Future<void> _ensureLoaded() async {
    final userId = ref.read(userProfileProvider).id;
    if (userId.isEmpty) return;
    final convs = ref.read(conversationsProvider);
    final exists = convs.any((c) => c.id == widget.conversationId);
    if (!exists) {
      await ref.read(conversationsProvider.notifier).loadConversations(userId);
    }
    await ref.read(conversationsProvider.notifier).loadMessages(
      widget.conversationId, userId,
    );
    ref.read(conversationsProvider.notifier).markAsRead(widget.conversationId);
    ref.read(driverApiProvider).markConversationRead(widget.conversationId, userId);
    // Mark all incoming messages as read
    final conv = ref.read(conversationsProvider).where((c) => c.id == widget.conversationId).firstOrNull;
    if (conv != null) {
      final unreadIds = conv.messages
          .where((m) => !m.isMe && m.status != MessageStatus.read)
          .map((m) => m.id)
          .toList();
      if (unreadIds.isNotEmpty) {
        ref.read(conversationsProvider.notifier).updateMessageStatus(
          widget.conversationId, unreadIds, MessageStatus.read,
        );
        _sendWsMessage({'type': 'message_read', 'message_ids': unreadIds});
      }
    }
    _scrollToBottom();
  }

  void _connectWebSocket() {
    _ws?.close();
    _reconnectTimer?.cancel();
    
    final api = ref.read(driverApiProvider);
    final token = api.token;
    if (token == null) return;
    
    final wsUrl = '${api.wsBaseUrl}/ws/chat/${widget.conversationId}?token=$token';
    
    try {
      WebSocket.connect(wsUrl).then((ws) {
        if (!mounted) { ws.close(); return; }
        
        _ws = ws;
        _reconnectAttempts = 0;
        debugPrint('WebSocket connected to $wsUrl');
        
        _wsSubscription = ws.listen(
          (data) {
            if (!mounted) return;
            try {
              final json = jsonDecode(data as String) as Map<String, dynamic>;
              final type = json['type'] as String?;
              
              if (type == 'new_message') {
                final userId = ref.read(userProfileProvider).id;
                if (json['sender_id'] == userId) return;
                
                final msg = ChatMessage(
                  id: json['id'] as String,
                  text: json['text'] as String,
                  isMe: false,
                  time: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
                  status: MessageStatus.delivered,
                );
                
                ref.read(conversationsProvider.notifier).addRealtimeMessage(
                  convId: widget.conversationId,
                  message: msg,
                );
                
                // Auto-reply read receipt via WebSocket v2
                _sendWsMessage({
                  'type': 'message_read',
                  'message_ids': [json['id'] as String],
                });
                
                _scrollToBottom();
                
              } else if (type == 'messages_read') {
                final messageIds = (json['message_ids'] as List<dynamic>).cast<String>();
                ref.read(conversationsProvider.notifier).markMessagesRead(
                  widget.conversationId, messageIds,
                );
              } else if (type == 'message_status') {
                final messageIds = (json['message_ids'] as List<dynamic>).cast<String>();
                final statusStr = json['status'] as String? ?? 'delivered';
                final status = statusStr == 'read' ? MessageStatus.read : MessageStatus.delivered;
                ref.read(conversationsProvider.notifier).updateMessageStatus(
                  widget.conversationId, messageIds, status,
                );
              } else if (type == 'message_deleted') {
                final messageId = json['message_id'] as String;
                ref.read(conversationsProvider.notifier).removeMessage(
                  widget.conversationId, messageId,
                );
              } else if (type == 'reaction_added') {
                final messageId = json['message_id'] as String;
                final rUserId = json['user_id'] as String;
                final emoji = json['emoji'] as String;
                ref.read(conversationsProvider.notifier).addReaction(
                  widget.conversationId, messageId, rUserId, emoji,
                );
              } else if (type == 'reaction_removed') {
                final messageId = json['message_id'] as String;
                final rUserId = json['user_id'] as String;
                ref.read(conversationsProvider.notifier).removeReaction(
                  widget.conversationId, messageId, rUserId,
                );
              }
            } catch (e) {
              debugPrint('WS parse error: $e');
            }
          },
          onError: (e) {
            debugPrint('WebSocket error: $e');
            _scheduleReconnect();
          },
          onDone: () {
            debugPrint('WebSocket closed');
            _scheduleReconnect();
          },
        );
      });
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    
    _reconnectAttempts++;
    final delaySeconds = (1 << (_reconnectAttempts - 1)).clamp(1, 30);
    debugPrint('WebSocket reconnecting in $delaySeconds seconds (attempt $_reconnectAttempts)');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (mounted) {
        debugPrint('WebSocket attempting reconnect...');
        _connectWebSocket();
      }
    });
  }

  void _sendWsMessage(Map<String, dynamic> data) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode(data));
    }
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final userId = ref.read(userProfileProvider).id;
    ref.read(conversationsProvider.notifier).sendMessage(
      widget.conversationId, text, userId,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _stopPolling();
    _wsSubscription?.cancel();
    _ws?.close();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final card = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final primary = AppThemes.primaryColor(appTheme, isDark);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light).scaffoldBackgroundColor;
    final textPri = isDark ? Colors.white : const Color(0xFF0D1E30);
    final textSec = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;

    final conversations = ref.watch(conversationsProvider);
    final conv = conversations.where((c) => c.id == widget.conversationId).firstOrNull;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        title: Text(conv?.name ?? 'Chat', style: TextStyle(color: textPri)),
        iconTheme: IconThemeData(color: textPri),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: border, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
              itemCount: conv?.messages.length ?? 0,
              itemBuilder: (context, i) {
                final msg = conv!.messages[i];
                final showTime = i == 0 ||
                    conv.messages[i - 1].isMe != msg.isMe;
                final convId = widget.conversationId;
                final userId = ref.read(userProfileProvider).id;
                final bubble = _MessageBubble(
                  message: msg,
                  showTime: showTime,
                  isDark: isDark,
                  primary: primary,
                  textSec: textSec,
                  userId: userId,
                  onReact: (emoji) {
                    final existing = msg.reactions.where((r) => r.userId == userId).firstOrNull;
                    if (existing?.emoji == emoji) {
                      ref.read(conversationsProvider.notifier).removeReaction(convId, msg.id, userId);
                      ref.read(driverApiProvider).removeReaction(msg.id, userId);
                    } else {
                      if (existing != null) {
                        ref.read(conversationsProvider.notifier).removeReaction(convId, msg.id, userId);
                      }
                      ref.read(conversationsProvider.notifier).addReaction(convId, msg.id, userId, emoji);
                      ref.read(driverApiProvider).addReaction(msg.id, userId, emoji);
                    }
                  },
                  onDelete: msg.isMe ? () {
                    ref.read(conversationsProvider.notifier).deleteMessage(convId, msg.id);
                  } : null,
                );

                return bubble;
              },
            ),
          ),
          // Input bar
          Container(
            decoration: BoxDecoration(
              color: card,
              border: Border(top: BorderSide(color: border)),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      style: TextStyle(color: textPri),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(color: textSec, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, const Color(0xFF0066FF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTime;
  final bool isDark;
  final Color primary, textSec;
  final String userId;
  final VoidCallback? onDelete;
  final void Function(String emoji)? onReact;

  const _MessageBubble({
    required this.message,
    required this.showTime,
    required this.isDark,
    required this.primary,
    required this.textSec,
    required this.userId,
    this.onDelete,
    this.onReact,
  });

  String _timeLabel(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime t) =>
      '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _statusLabel(MessageStatus s) {
    switch (s) {
      case MessageStatus.sending: return 'Enviando...';
      case MessageStatus.sent: return 'Enviado';
      case MessageStatus.delivered: return 'Entregado';
      case MessageStatus.read: return 'Leído';
      case MessageStatus.failed: return 'Error';
    }
  }

  void _showMessageActions(BuildContext context) {
    const quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    final myReaction = message.reactions.where((r) => r.userId == userId).firstOrNull;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in quickEmojis)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onReact?.call(e);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: myReaction?.emoji == e
                              ? primary.withValues(alpha: 0.15)
                              : null,
                          border: myReaction?.emoji == e
                              ? Border.all(color: primary.withValues(alpha: 0.5))
                              : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Más emojis pronto')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(Icons.add, size: 20, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Información'),
              onTap: () {
                Navigator.pop(ctx);
                _showMessageInfo(context);
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Eliminar mensaje'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () { Navigator.pop(dCtx); onDelete!(); },
                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showMessageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Info del mensaje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Enviado', _dateLabel(message.time)),
            if (message.isMe && message.status.index >= MessageStatus.sent.index)
              _infoRow('Estado', _statusLabel(message.status)),
            if (message.deliveredAt != null)
              _infoRow('Entregado', _dateLabel(message.deliveredAt!)),
            if (message.readAt != null)
              _infoRow('Leído', _dateLabel(message.readAt!)),
            if (message.editedAt != null)
              _infoRow('Editado', message.editedAt!),
            if (message.replyText != null)
              _infoRow('Respondiendo a', message.replyText!.length > 50
                  ? '${message.replyText!.substring(0, 50)}...'
                  : message.replyText!),
            if (message.reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Reacciones:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600)),
              ),
            if (message.reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _ReactionChips(reactions: message.reactions, isDark: false, textSec: Colors.grey.shade600),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
        onLongPress: () => _showMessageActions(context),
        onTap: () {
          if (message.replyToId != null) {
            // Scroll to replied message
            final scaffold = ScaffoldMessenger.maybeOf(context);
            if (scaffold != null) {
              scaffold.showSnackBar(SnackBar(content: Text('Mensaje original: ${message.replyText ?? ""}')));
            }
          }
        },
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment:
              message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: message.isMe
                    ? LinearGradient(
                        colors: [primary, const Color(0xFF0066FF)])
                    : null,
                color: message.isMe
                    ? null
                    : isDark
                        ? const Color(0xFF0F2235)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: message.isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: message.isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isMe
                      ? isDark ? const Color(0xFF0D1E30) : Colors.white 
                      : isDark
                          ? Colors.white
                          : const Color(0xFF0D1E30) ,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.editedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('editado', style: TextStyle(color: textSec, fontSize: 9)),
                  ),
                Text(_timeLabel(message.time),
                    style: TextStyle(color: textSec, fontSize: 10)),
                if (message.isMe) ...[
                  const SizedBox(width: 4),
                  _StatusIcon(status: message.status, primary: primary, isDark: isDark),
                ],
              ],
            ),
            if (message.reactions.isNotEmpty) ...[
              const SizedBox(height: 4),
              _ReactionChips(reactions: message.reactions, isDark: isDark, textSec: textSec),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final Color primary;
  final bool isDark;

  const _StatusIcon({
    required this.status,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: Colors.grey.shade500);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: Colors.grey.shade500);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: primary);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.redAccent);
    }
  }
}

class _ReactionChips extends StatelessWidget {
  final List<MessageReaction> reactions;
  final bool isDark;
  final Color textSec;

  const _ReactionChips({
    required this.reactions,
    required this.isDark,
    required this.textSec,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, int>{};
    for (final r in reactions) {
      grouped[r.emoji] = (grouped[r.emoji] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: grouped.entries.map((e) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${e.key}${e.value > 1 ? ' ${e.value}' : ''}',
            style: TextStyle(fontSize: 11, color: textSec),
          ),
        ),
      ).toList(),
    );
  }
}
