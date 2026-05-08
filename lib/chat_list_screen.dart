import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_outlined, color: primary, size: 20),
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
                return GestureDetector(
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
                            conv.unread > 0 ? primary.withOpacity(0.3) : border,
                        width: conv.unread > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: primary.withOpacity(0.15),
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

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final userId = ref.read(userProfileProvider).id;
    if (userId.isEmpty) return;
    ref
        .read(conversationsProvider.notifier)
        .sendMessage(widget.conversationId, text, userId);
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
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
    final conv = conversations.firstWhere((c) => c.id == widget.conversationId);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primary.withOpacity(0.15),
                  child: Text(conv.avatar,
                      style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
                if (conv.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: card, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conv.name,
                    style: TextStyle(
                        color: textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(conv.isOnline ? 'En línea' : 'Desconectado',
                    style: TextStyle(
                        color: conv.isOnline ? primary : textSec,
                        fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: Icon(Icons.phone_outlined, color: primary, size: 22),
              onPressed: () {}),
          IconButton(
              icon: Icon(Icons.more_vert_rounded, color: textSec, size: 22),
              onPressed: () {}),
        ],
        bottom: PreferredSize(
            child: Divider(color: border, height: 1),
            preferredSize: const Size.fromHeight(1)),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: conv.messages.length,
              itemBuilder: (context, i) {
                final msg = conv.messages[i];
                final showTime =
                    i == 0 || conv.messages[i - 1].isMe != msg.isMe;
                return _MessageBubble(
                  message: msg,
                  showTime: showTime,
                  isDark: isDark,
                  primary: primary,
                  textSec: textSec,
                ).animate().fadeIn(
                    delay: Duration(milliseconds: 40 * i),
                    duration: 300.ms).slideY(begin: 0.1, curve: Curves.easeOut);
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
                          ? Colors.white.withOpacity(0.06)
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
                            color: primary.withOpacity(0.4),
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

  const _MessageBubble({
    required this.message,
    required this.showTime,
    required this.isDark,
    required this.primary,
    required this.textSec,
  });

  String _timeLabel(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
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
            Text(_timeLabel(message.time),
                style: TextStyle(color: textSec, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
