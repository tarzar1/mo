import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'driver_api_service.dart';
import 'chat_list_screen.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchCtrl = TextEditingController();
  List<UserSearchResult> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await ref.read(driverApiProvider).searchUsers(q.trim());
      final userId = ref.read(userProfileProvider).id;
      setState(() => _results = results.where((u) => u.id != userId).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChat(UserSearchResult user) async {
    final myId = ref.read(userProfileProvider).id;
    if (myId.isEmpty) return;
    try {
      final conv = await ref.read(driverApiProvider).ensureConversation(myId, user.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversationId: conv.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nuevo mensaje',
            style: TextStyle(color: textPri, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: textSec, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _search,
                    style: TextStyle(color: textPri),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o email...',
                      hintStyle: TextStyle(color: textSec, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_loading)
                  SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined, size: 64, color: textSec),
                        const SizedBox(height: 16),
                        Text('Busca usuarios para chatear',
                            style: TextStyle(color: textSec, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final user = _results[i];
                      final avatar = user.avatar.isNotEmpty
                          ? user.avatar[0].toUpperCase()
                          : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?');
                      return GestureDetector(
                        onTap: () => _startChat(user),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: primary.withValues(alpha: 0.15),
                                child: Text(avatar,
                                    style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${user.name} ${user.lastName}'.trim(),
                                        style: TextStyle(color: textPri, fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(user.email,
                                        style: TextStyle(color: textSec, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: textSec),
                            ],
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
