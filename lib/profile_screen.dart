import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final user = ref.watch(userProfileProvider);

    final primary = AppThemes.primaryColor(appTheme, isDark);
    final secondary = AppThemes.secondaryColor(appTheme);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark)
            .scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light)
            .scaffoldBackgroundColor;
    final card = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textPri = isDark ? Colors.white : const Color(0xFF0D1E30);
    final textSec = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // Header banner
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              decoration: BoxDecoration(
                color: card,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Mi perfil',
                          style: TextStyle(
                              color: textPri,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Visibility(
                        visible: false,
                        child: GestureDetector(
                          onTap: () => _showEditProfile(
                              context, ref, user, isDark, appTheme),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primary.withOpacity( 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.edit_outlined,
                                color: primary, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Avatar with role badge
                  Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppThemes.gradientColors(appTheme),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: primary.withOpacity( 0.4),
                                blurRadius: 20,
                                spreadRadius: 2),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name
                                    .split(' ')
                                    .where((p) => p.isNotEmpty)
                                    .map((p) => p[0])
                                    .take(2)
                                    .join()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (user.isVerified)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: card, width: 2),
                            ),
                            child: const Icon(Icons.verified,
                                color: Colors.white, size: 12),
                          ),
                        ),
                      // Role badge
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () =>
                              _showRoleSwitch(context, ref, user, isDark, appTheme),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: secondary,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: card, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(user.roleIcon,
                                    color: Colors.white, size: 10),
                                const SizedBox(width: 4),
                                Text(user.roleLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(user.name,
                      style: TextStyle(
                          color: textPri,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user.bio,
                      style: TextStyle(color: textSec, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  if (!user.isVerified)
                    GestureDetector(
                      onTap: () {
                        ref.read(userProfileProvider.notifier).verify();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('✅ Identidad verificada')),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800)
                              .withOpacity( 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFFB800)
                                  .withOpacity( 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFFFB800), size: 14),
                            SizedBox(width: 6),
                            Text('Verificar identidad',
                                style: TextStyle(
                                    color: Color(0xFFFFB800),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Stats cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _StatCard(
                      value: '${user.tripsCompleted}',
                      label: 'Viajes\ntomados',
                      color: primary,
                      card: card,
                      textPri: textPri,
                      textSec: textSec,
                      border: border),
                  const SizedBox(width: 12),
                  _StatCard(
                      value: '${user.tripsOffered}',
                      label: 'Viajes\nofrecidos',
                      color: secondary,
                      card: card,
                      textPri: textPri,
                      textSec: textSec,
                      border: border),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: '${user.rating}',
                    label: 'Calificación\npromedio',
                    color: const Color(0xFFFFB800),
                    card: card,
                    textPri: textPri,
                    textSec: textSec,
                    border: border,
                    suffix: '⭐',
                  ),
                ],
              ),
            ),
          ),

          // Contact info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Información de contacto',
                  style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ),
          ),
          SliverToBoxAdapter(
            child: _InfoCard(
              isDark: isDark,
              card: card,
              textPri: textPri,
              textSec: textSec,
              border: border,
              primary: primary,
              items: [
                _InfoItem(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email),
                _InfoItem(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: user.phone),
              ],
            ),
          ),

          // Reviews section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Reseñas recientes',
                  style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _ReviewCard(
                name: 'María G.',
                avatar: 'MG',
                stars: 5,
                comment: 'Excelente pasajero, muy puntual y amable.',
                date: 'hace 2 días',
                isDark: isDark,
                card: card,
                textPri: textPri,
                textSec: textSec,
                border: border,
                secondary: secondary,
              ),
              _ReviewCard(
                name: 'Juan R.',
                avatar: 'JR',
                stars: 5,
                comment: 'Muy buena onda, recomendado 100%.',
                date: 'hace 1 semana',
                isDark: isDark,
                card: card,
                textPri: textPri,
                textSec: textSec,
                border: border,
                secondary: secondary,
              ),
              _ReviewCard(
                name: 'Ana M.',
                avatar: 'AM',
                stars: 4,
                comment: 'Llegó a tiempo y fue muy considerado.',
                date: 'hace 2 semanas',
                isDark: isDark,
                card: card,
                textPri: textPri,
                textSec: textSec,
                border: border,
                secondary: secondary,
              ),
            ]),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showEditProfile(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    bool isDark,
    AppThemeVariant appTheme,
  ) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final bioCtrl = TextEditingController(text: user.bio);
    final bgColor = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0D1E30);
    final subColor = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Editar perfil',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _InputField(
                ctrl: nameCtrl,
                hint: 'Nombre completo',
                icon: Icons.person_outline,
                isDark: isDark,
                textPri: textColor,
                textSec: subColor,
                border: borderColor),
            const SizedBox(height: 10),
            _InputField(
                ctrl: emailCtrl,
                hint: 'Email',
                icon: Icons.email_outlined,
                isDark: isDark,
                textPri: textColor,
                textSec: subColor,
                border: borderColor),
            const SizedBox(height: 10),
            _InputField(
                ctrl: phoneCtrl,
                hint: 'Teléfono',
                icon: Icons.phone_outlined,
                isDark: isDark,
                textPri: textColor,
                textSec: subColor,
                border: borderColor),
            const SizedBox(height: 10),
            _InputField(
                ctrl: bioCtrl,
                hint: 'Bio',
                icon: Icons.edit_outlined,
                isDark: isDark,
                textPri: textColor,
                textSec: subColor,
                border: borderColor,
                maxLines: 2),
            const SizedBox(height: 20),
            _GradBtn(
              label: 'Guardar cambios',
              onTap: () {
                ref.read(userProfileProvider.notifier).update(
                      user.copyWith(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        bio: bioCtrl.text.trim(),
                      ),
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil actualizado ✅')),
                );
              },
              gradientColors: AppThemes.gradientColors(appTheme),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleSwitch(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    bool isDark,
    AppThemeVariant appTheme,
  ) {
    final primary = AppThemes.primaryColor(appTheme, isDark);
    final secondary = AppThemes.secondaryColor(appTheme);
    final bgColor = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Cambiar rol',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Selecciona tu rol en la aplicación',
                style: TextStyle(color: subColor, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity( 0.06)
                    : const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(userProfileProvider.notifier).update(
                            user.copyWith(role: UserRole.passenger));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Rol cambiado a Pasajero ✅')),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: user.role == UserRole.passenger
                              ? primary.withOpacity( 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: user.role == UserRole.passenger
                              ? Border.all(
                                  color: primary.withOpacity( 0.5))
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person,
                                color: user.role == UserRole.passenger
                                    ? primary
                                    : subColor,
                                size: 28),
                            const SizedBox(height: 8),
                            Text('Pasajero',
                                style: TextStyle(
                                    color: user.role == UserRole.passenger
                                        ? primary
                                        : subColor,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(userProfileProvider.notifier).update(
                            user.copyWith(role: UserRole.driver));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Rol cambiado a Conductor ✅')),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: user.role == UserRole.driver
                              ? secondary.withOpacity( 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: user.role == UserRole.driver
                              ? Border.all(
                                  color: secondary.withOpacity( 0.5))
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.drive_eta,
                                color: user.role == UserRole.driver
                                    ? secondary
                                    : subColor,
                                size: 28),
                            const SizedBox(height: 8),
                            Text('Conductor',
                                style: TextStyle(
                                    color: user.role == UserRole.driver
                                        ? secondary
                                        : subColor,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cerrar',
                    style: TextStyle(color: subColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color, card, textPri, textSec, border;
  final String? suffix;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.card,
    required this.textPri,
    required this.textSec,
    required this.border,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Text(value + (suffix ?? ''),
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(color: textSec, fontSize: 10),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _InfoItem {
  final IconData icon;
  final String label, value;
  const _InfoItem(
      {required this.icon, required this.label, required this.value});
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final Color card, textPri, textSec, border, primary;
  final List<_InfoItem> items;

  const _InfoCard({
    required this.isDark,
    required this.card,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.primary,
    required this.items,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          children: items.asMap().entries.map((e) {
            final item = e.value;
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(item.icon, color: primary, size: 20),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style:
                                  TextStyle(color: textSec, fontSize: 11)),
                          Text(item.value,
                              style: TextStyle(
                                  color: textPri,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(height: 1, color: border, indent: 50, endIndent: 16),
              ],
            );
          }).toList(),
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  final String name, avatar, comment, date;
  final int stars;
  final bool isDark;
  final Color card, textPri, textSec, border;
  final Color secondary;

  const _ReviewCard({
    required this.name,
    required this.avatar,
    required this.comment,
    required this.date,
    required this.stars,
    required this.isDark,
    required this.card,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: secondary.withOpacity( 0.15),
              child: Text(avatar,
                  style: TextStyle(
                      color: secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: textPri,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const Spacer(),
                      Text(date,
                          style: TextStyle(color: textSec, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                      children: List.generate(
                            5,
                            (i) => Icon(Icons.star_rounded,
                                color: i < stars
                                    ? const Color(0xFFFFB800)
                                    : (isDark
                                        ? Colors.white24
                                        : Colors.black12),
                                size: 13)),
                    ),
                  const SizedBox(height: 6),
                  Text(comment,
                      style: TextStyle(color: textSec, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool isDark;
  final Color textPri, textSec, border;
  final int maxLines;

  const _InputField({
    required this.ctrl,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.textPri,
    required this.textSec,
    required this.border,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity( 0.06)
              : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, color: textSec, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: maxLines,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: textSec, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      );
}

class _GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  const _GradBtn(
      {required this.label,
      required this.onTap,
      required this.gradientColors});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: gradientColors),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
      );
}
