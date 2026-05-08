import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'auth_provider.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'chat_list_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'auth_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: CommuteShareApp()));
}

class CommuteShareApp extends ConsumerStatefulWidget {
  const CommuteShareApp({super.key});

  @override
  ConsumerState<CommuteShareApp> createState() => _CommuteShareAppState();
}

class _CommuteShareAppState extends ConsumerState<CommuteShareApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (next.isLoggedIn && prev?.isLoggedIn != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authProvider.notifier).loadAllData(ref);
        });
      }
    });

    final themeMode = ref.watch(themeModeProvider);
    final appTheme = ref.watch(appThemeProvider);

    return MaterialApp(
      title: 'CommuteShare',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.getTheme(appTheme, Brightness.light),
      darkTheme: AppThemes.getTheme(appTheme, Brightness.dark),
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}

// ─── AUTH GATE ────────────────────────────────────────────────────────────────
// Watches auth state and routes between Login and Main app

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.loading) {
      final bg = ref.watch(themeModeProvider) == ThemeMode.dark
          ? const Color(0xFF071520)
          : const Color(0xFFF0F4F8);
      final primary = AppThemes.primaryColor(
          ref.watch(appThemeProvider),
          ref.watch(themeModeProvider) == ThemeMode.dark);
      final textColor = ref.watch(themeModeProvider) == ThemeMode.dark
          ? Colors.white
          : const Color(0xFF0D1E30);
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primary),
              const SizedBox(height: 16),
              Text('CommuteShare',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginGate();
    }

    return const MainShell();
  }
}

// ─── LOGIN GATE ───────────────────────────────────────────────────────────────

class LoginGate extends StatefulWidget {
  const LoginGate({super.key});

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  bool showLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: showLogin
            ? LoginView(
                key: const ValueKey('login'),
                onSwitch: () => setState(() => showLogin = false),
                onLoginSuccess: () {
                  // AuthGate will rebuild automatically via Riverpod
                },
              )
            : SignupView(
                key: const ValueKey('register'),
                onSwitch: () => setState(() => showLogin = true),
              ),
      ),
    );
  }
}

// ─── MAIN SHELL ───────────────────────────────────────────────────────────────

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    ChatListScreen(),
    ProfileScreen(),
    SettingsScreen(),
    NotificationScreen()
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(bottomNavIndexProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);

    return Scaffold(
      body: IndexedStack(index: idx, children: _screens),
      bottomNavigationBar: _BottomBar(
          currentIndex: idx, isDark: isDark, appTheme: appTheme),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final int currentIndex;
  final bool isDark;
  final AppThemeVariant appTheme;
  const _BottomBar(
      {required this.currentIndex,
      required this.isDark,
      required this.appTheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final totalUnread = conversations.fold(0, (sum, c) => sum + c.unread);

    final theme = Theme.of(context);
    final bg = theme.cardColor;
    final selected = AppThemes.primaryColor(appTheme, isDark);
    final unselected =
        isDark ? const Color(0xFF4A6380) : const Color(0xFF9E9E9E);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
            top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.map_rounded,
                  label: 'Mapa',
                  index: 0,
                  current: currentIndex,
                  selected: selected,
                  unselected: unselected),
              _NavItem(
                  icon: Icons.search_rounded,
                  label: 'Buscar',
                  index: 1,
                  current: currentIndex,
                  selected: selected,
                  unselected: unselected),
              _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  index: 2,
                  current: currentIndex,
                  selected: selected,
                  unselected: unselected,
                  badge: totalUnread),
              _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Perfil',
                  index: 3,
                  current: currentIndex,
                  selected: selected,
                  unselected: unselected),
              _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Config',
                  index: 4,
                  current: currentIndex,
                  selected: selected,
                  unselected: unselected),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final Color selected;
  final Color unselected;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.selected,
    required this.unselected,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () {
        ref.read(bottomNavIndexProvider.notifier).state = index;
        HapticFeedback.lightImpact();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? selected.withOpacity( 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? selected : unselected,
                    size: 22,
                  ),
                ),
                  if (badge > 0)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.5, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) => Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B5C),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive ? selected : unselected,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
