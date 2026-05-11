import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    final bg = theme.scaffoldBackgroundColor;
    final card = theme.cardColor;
    final primary = AppThemes.primaryColor(ref.watch(appThemeProvider), isDark);
    final text = isDark ? Colors.white : const Color(0xFF0D1E30);
    final sub = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;

    final displayName = user.name.isNotEmpty ? user.name : 'Usuario';
    final displayEmail = user.email.isNotEmpty ? user.email : '';
    final displayPhone = user.phone.isNotEmpty ? user.phone : '';

    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
          bottom: 40,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.settings_rounded, color: primary),
                const SizedBox(width: 10),
                Text("Configuración",
                    style: TextStyle(
                        color: text,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _ProfileCard(
            displayName: displayName,
            displayEmail: displayEmail,
            user: user,
            primary: primary,
            card: card,
            text: text,
            sub: sub,
            border: border,
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2),

          const SizedBox(height: 20),

          _Section(title: "CUENTA", sub: sub),
          _Card(card: card, border: border, children: [
            _Tile(
              icon: Icons.person_outline,
              title: "Editar perfil",
              subtitle: displayName,
              text: text, sub: sub,
              onTap: () => _showEditProfile(context, ref, user),
            ),
            _Divider(border: border),
            _Tile(
              icon: Icons.phone_outlined,
              title: "Teléfono",
              subtitle: displayPhone,
              text: text, sub: sub,
              onTap: () => _showEditPhone(context, ref, user),
            ),
            _Divider(border: border),
            _Tile(
              icon: Icons.lock_outline,
              title: "Cambiar contraseña",
              text: text, sub: sub,
              onTap: () => _showChangePassword(context, ref),
            ),
            _Divider(border: border),
            _Tile(
              icon: Icons.swap_horiz_rounded,
              title: "Cambiar rol",
              subtitle: user.role == UserRole.driver ? 'Conductor' : 'Pasajero',
              text: text, sub: sub,
              onTap: () => _showRoleSwitch(context, ref, user, isDark, ref.watch(appThemeProvider)),
            ),
          ]),

          const SizedBox(height: 20),

          _Section(title: "NOTIFICACIONES", sub: sub),
          _Card(card: card, border: border, children: [
            _SwitchTile(
              icon: Icons.notifications_outlined,
              title: "Push notifications",
              subtitle: "Recibir notificaciones en el dispositivo",
              value: settings.notifications,
              text: text, sub: sub,
              onChanged: (_) => ref.read(settingsProvider.notifier).toggle('notifications'),
            ),
            _Divider(border: border),
            _SwitchTile(
              icon: Icons.email_outlined,
              title: "Alertas por email",
              subtitle: "Recibir alertas en $displayEmail",
              value: settings.emailAlerts,
              text: text, sub: sub,
              onChanged: (_) => ref.read(settingsProvider.notifier).toggle('emailAlerts'),
            ),
            _Divider(border: border),
            _SwitchTile(
              icon: Icons.volume_up_outlined,
              title: "Sonidos",
              subtitle: "Sonidos de la aplicación",
              value: settings.soundEffects,
              text: text, sub: sub,
              onChanged: (_) => ref.read(settingsProvider.notifier).toggle('soundEffects'),
            ),
          ]),

          const SizedBox(height: 20),

          _Section(title: "PRIVACIDAD", sub: sub),
          _Card(card: card, border: border, children: [
            _SwitchTile(
              icon: Icons.location_on_outlined,
              title: "Ubicación siempre activa",
              subtitle: "Compartir ubicación en tiempo real",
              value: settings.locationAlways,
              text: text, sub: sub,
              onChanged: (_) => ref.read(settingsProvider.notifier).toggle('locationAlways'),
            ),
          ]),

          const SizedBox(height: 20),

          _Section(title: "APARIENCIA", sub: sub),
          _Card(card: card, border: border, children: [
            _SwitchTile(
              icon: Icons.dark_mode_outlined,
              title: "Modo oscuro",
              subtitle: isDark ? "Activado" : "Desactivado",
              value: isDark,
              text: text, sub: sub,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
            _Divider(border: border),
            _Tile(
              icon: Icons.palette_outlined,
              title: "Tema de color",
              subtitle: AppThemes.label(ref.watch(appThemeProvider)),
              text: text, sub: sub,
              trailing: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppThemes.gradientColors(ref.watch(appThemeProvider)),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onTap: () => _showThemeSelector(context, ref),
            ),
          ]),

          const SizedBox(height: 20),

          _Section(title: "IDIOMA", sub: sub),
          _Card(card: card, border: border, children: [
            _Tile(
              icon: Icons.language,
              title: "Idioma",
              subtitle: settings.language,
              text: text, sub: sub,
              onTap: () => _showLanguageSelector(context, ref),
            ),
          ]),

          const SizedBox(height: 20),

          _Section(title: "AYUDA", sub: sub),
          _Card(card: card, border: border, children: [
            _Tile(
              icon: Icons.help_outline,
              title: "Centro de ayuda",
              subtitle: "Preguntas frecuentes y soporte",
              text: text, sub: sub,
              onTap: () => _showComingSoon(context, 'Centro de ayuda'),
            ),
            _Divider(border: border),
            _Tile(
              icon: Icons.description_outlined,
              title: "Términos y condiciones",
              text: text, sub: sub,
              onTap: () => _showComingSoon(context, 'Términos y condiciones'),
            ),
            _Divider(border: border),
            _Tile(
              icon: Icons.privacy_tip_outlined,
              title: "Política de privacidad",
              text: text, sub: sub,
              onTap: () => _showComingSoon(context, 'Política de privacidad'),
            ),
          ]),

          const SizedBox(height: 30),

          _DangerButton(
            text: "Cerrar sesión",
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),

          const SizedBox(height: 20),

          Center(
            child: Column(
              children: [
                Text("CommuteShare v2.0.0", style: TextStyle(color: sub, fontSize: 12)),
                const SizedBox(height: 4),
                Text("Hecho con ❤️ para la comunidad", style: TextStyle(color: sub, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── WIDGETS ───────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String displayName, displayEmail;
  final UserProfile user;
  final Color primary, card, text, sub, border;

  const _ProfileCard({
    required this.displayName, required this.displayEmail,
    required this.user, required this.primary, required this.card,
    required this.text, required this.sub, required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: primary.withValues(alpha: 0.2),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(displayEmail, style: TextStyle(color: sub, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${user.rating}', style: TextStyle(color: sub, fontSize: 13)),
                      const SizedBox(width: 12),
                      Text('${user.tripsCompleted} viajes', style: TextStyle(color: sub, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color sub;
  const _Section({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Text(title,
          style: TextStyle(
              color: sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color card, border;
  const _Card({required this.children, required this.card, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color text, sub;
  final Widget? trailing;
  final VoidCallback onTap;

  const _Tile({
    required this.icon, required this.title, this.subtitle,
    required this.text, required this.sub, this.trailing, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: sub),
      title: Text(title, style: TextStyle(color: text, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: sub, fontSize: 12))
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right, size: 18, color: sub),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final Color text, sub;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon, required this.title, this.subtitle,
    required this.value, required this.text, required this.sub, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: sub),
      title: Text(title, style: TextStyle(color: text, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: sub, fontSize: 12))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: theme.colorScheme.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color border;
  const _Divider({required this.border});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: border, indent: 70, endIndent: 16);
  }
}

class _DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _DangerButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.error),
            color: theme.colorScheme.error.withValues(alpha: 0.08),
          ),
          child: Center(
            child: Text(text,
                style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

// ─── DIALOGOS ───────────────────────────────────────

void _showComingSoon(BuildContext context, String feature) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature — Próximamente'),
      backgroundColor: theme.colorScheme.primary,
    ),
  );
}

void _showEditProfile(BuildContext context, WidgetRef ref, UserProfile user) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primary = theme.colorScheme.primary;
  final bg = theme.cardColor;
  final text = isDark ? Colors.white : const Color(0xFF0D1E30);
  final sub = isDark ? Colors.white54 : const Color(0xFF546E7A);

  final nameCtrl = TextEditingController(text: user.name);
  final bioCtrl = TextEditingController(text: user.bio);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _handle(isDark)),
          const SizedBox(height: 20),
          Text('Editar perfil',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 16),
          _dialogField(ctx, nameCtrl, 'Nombre', Icons.person_outline, text, sub),
          const SizedBox(height: 12),
          _dialogField(ctx, bioCtrl, 'Biografía', Icons.edit_outlined, text, sub, maxLines: 3),
          const SizedBox(height: 20),
          _gradientBtn('Guardar cambios', primary, () {
            ref.read(userProfileProvider.notifier).updateName(nameCtrl.text);
            ref.read(userProfileProvider.notifier).updateBio(bioCtrl.text);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green),
            );
          }),
        ],
      ),
    ),
  );
}

void _showEditPhone(BuildContext context, WidgetRef ref, UserProfile user) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primary = theme.colorScheme.primary;
  final bg = theme.cardColor;
  final text = isDark ? Colors.white : const Color(0xFF0D1E30);
  final sub = isDark ? Colors.white54 : const Color(0xFF546E7A);

  final phoneCtrl = TextEditingController(text: user.phone);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _handle(isDark)),
          const SizedBox(height: 20),
          Text('Editar teléfono',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 16),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              labelText: 'Teléfono',
              labelStyle: TextStyle(color: sub),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          _gradientBtn('Guardar', primary, () {
            ref.read(userProfileProvider.notifier).updatePhone(phoneCtrl.text);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Teléfono actualizado'), backgroundColor: Colors.green),
            );
          }),
        ],
      ),
    ),
  );
}

void _showChangePassword(BuildContext context, WidgetRef ref) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primary = theme.colorScheme.primary;
  final bg = theme.cardColor;
  final text = isDark ? Colors.white : const Color(0xFF0D1E30);
  final sub = isDark ? Colors.white54 : const Color(0xFF546E7A);

  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _handle(isDark)),
          const SizedBox(height: 20),
          Text('Cambiar contraseña',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 16),
          _dialogField(ctx, newPassCtrl, 'Nueva contraseña', Icons.lock_outline, text, sub,
              obscure: true),
          const SizedBox(height: 12),
          _dialogField(ctx, confirmPassCtrl, 'Confirmar contraseña', Icons.lock_outline, text, sub,
              obscure: true),
          const SizedBox(height: 20),
          _gradientBtn('Actualizar contraseña', primary, () async {
            if (newPassCtrl.text != confirmPassCtrl.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red),
              );
              return;
            }
            try {
              final u = ref.read(userProfileProvider);
              await ref.read(authProvider.notifier).changePassword(
                    email: u.email, newPassword: newPassCtrl.text,
                  );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Contraseña actualizada'), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            }
          }),
        ],
      ),
    ),
  );
}

void _showRoleSwitch(BuildContext context, WidgetRef ref, UserProfile user, bool isDark, AppThemeVariant appTheme) {
  final theme = Theme.of(context);
  final primary = theme.colorScheme.primary;
  final secondary = AppThemes.secondaryColor(appTheme);
  final bg = theme.cardColor;
  final text = isDark ? Colors.white : Colors.black;
  final sub = isDark ? Colors.white54 : Colors.black54;

  showModalBottomSheet(
    context: context,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Cambiar rol', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Selecciona tu rol en la aplicación', style: TextStyle(color: sub, fontSize: 13)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _roleOption(
                  icon: Icons.person, label: 'Pasajero',
                  active: user.role == UserRole.passenger,
                  activeColor: primary, sub: sub, isDark: isDark,
                  onTap: () {
                    ref.read(userProfileProvider.notifier).update(user.copyWith(role: UserRole.passenger));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rol cambiado a Pasajero ✅')),
                    );
                  },
                ),
                _roleOption(
                  icon: Icons.drive_eta, label: 'Conductor',
                  active: user.role == UserRole.driver,
                  activeColor: secondary, sub: sub, isDark: isDark,
                  onTap: () {
                    ref.read(userProfileProvider.notifier).update(user.copyWith(role: UserRole.driver));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rol cambiado a Conductor ✅')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar', style: TextStyle(color: sub)),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _roleOption({
  required IconData icon, required String label, required bool active,
  required Color activeColor, required Color sub, required bool isDark,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: activeColor.withValues(alpha: 0.5)) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? activeColor : sub, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: active ? activeColor : sub, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ),
  );
}

void _showThemeSelector(BuildContext context, WidgetRef ref) {
  final currentTheme = ref.watch(appThemeProvider);
  final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? const Color(0xFF0D1E30) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Text('Seleccionar tema',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: AppThemeVariant.values.map((variant) {
              final isSelected = currentTheme == variant;
              final gradient = AppThemes.gradientColors(variant);
              final label = AppThemes.label(variant);
              return GestureDetector(
                onTap: () {
                  ref.read(appThemeProvider.notifier).set(variant);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 100, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: isSelected ? [BoxShadow(color: gradient[0].withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)] : null,
                  ),
                  child: Column(
                    children: [
                      Icon(isSelected ? Icons.check_circle : Icons.palette_outlined, color: Colors.white, size: 28),
                      const SizedBox(height: 8),
                      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white24 : Colors.black12,
                foregroundColor: isDark ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showLanguageSelector(BuildContext context, WidgetRef ref) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primary = theme.colorScheme.primary;
  final bg = theme.cardColor;
  final text = isDark ? Colors.white : const Color(0xFF0D1E30);

  final languages = ['Español', 'English', 'Français', 'Português'];
  final settings = ref.watch(settingsProvider);

  showModalBottomSheet(
    context: context,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Text('Seleccionar idioma',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 16),
          ...languages.map((lang) => ListTile(
            title: Text(lang, style: TextStyle(color: text)),
            trailing: settings.language == lang ? Icon(Icons.check_circle, color: primary) : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setLanguage(lang);
              Navigator.pop(ctx);
            },
          )),
        ],
      ),
    ),
  );
}

// ─── HELPERS ────────────────────────────────────────

Widget _handle(bool isDark) {
  return Container(
    width: 40, height: 4,
    decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(10)),
  );
}

Widget _dialogField(
    BuildContext ctx, TextEditingController ctrl, String hint, IconData icon,
    Color text, Color sub, {bool obscure = false, int maxLines = 1}) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return TextField(
    controller: ctrl,
    obscureText: obscure,
    maxLines: maxLines,
    style: TextStyle(color: text),
    decoration: InputDecoration(
      labelText: hint,
      labelStyle: TextStyle(color: sub),
      prefixIcon: Icon(icon, color: sub, size: 20),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Widget _gradientBtn(String label, Color primary, VoidCallback onTap) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    ),
  );
}
