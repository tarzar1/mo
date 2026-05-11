import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';
import 'driver_api_service.dart';
import 'auth_provider.dart';
import 'providers.dart';

/* ================= LOGIN ================= */

class LoginView extends ConsumerWidget {
  final VoidCallback onSwitch;
  final VoidCallback onLoginSuccess;

  const LoginView({
    super.key,
    required this.onSwitch,
    required this.onLoginSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LoginViewContent(
      onSwitch: onSwitch,
      onLoginSuccess: onLoginSuccess,
      ref: ref,
    );
  }
}

class _LoginViewContent extends StatefulWidget {
  final VoidCallback onSwitch;
  final VoidCallback onLoginSuccess;
  final WidgetRef ref;

  const _LoginViewContent({
    required this.onSwitch,
    required this.onLoginSuccess,
    required this.ref,
  });

  @override
  State<_LoginViewContent> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginViewContent> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await widget.ref.read(authProvider.notifier).login(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
      if (!mounted) return;
      widget.onLoginSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Error de conexión';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = widget.ref.watch(appThemeProvider);
    final primary = AppThemes.primaryColor(appTheme, isDark);
    final textColor = isDark ? Colors.white : const Color(0xFF0D1E30);
    final subColor = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final secondary = AppThemes.secondaryColor(appTheme);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.topRight,
            child: _ThemeToggleBtn(isDark: isDark, primary: primary),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          GlowIcon(Icons.directions_car_rounded, primary: primary)
              .animate()
              .fadeIn(duration: 600.ms, delay: 100.ms)
              .scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'CommuteShare',
            style: TextStyle(
              fontSize: 36,
              color: textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: -0.2),
          const SizedBox(height: 6),
          Text(
            'Tu ruta compartida al trabajo',
            style: TextStyle(color: subColor, fontSize: 14),
          ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
          const SizedBox(height: 48),
          GlowInput(
              hint: 'Correo electrónico',
              controller: _emailCtrl,
              icon: Icons.email_outlined,
              isDark: isDark,
              primary: primary)
              .animate().fadeIn(duration: 400.ms, delay: 400.ms).slideX(begin: -0.1),
          const SizedBox(height: 12),
          GlowInput(
            hint: 'Contraseña',
            controller: _passCtrl,
            icon: Icons.lock_outline,
            obscure: _obscure,
            isDark: isDark,
            primary: primary,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                  color: subColor, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideX(begin: -0.1),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showForgotPassword(context, widget.ref),
              child: Text('¿Olvidaste tu contraseña?',
                  style: TextStyle(color: subColor, fontSize: 13)),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
          const SizedBox(height: 12),
          GradientButton(
            text: _loading ? 'Iniciando sesión...' : 'Iniciar sesión',
            onTap: _loading ? null : _login,
            primary: primary,
            secondary: secondary,
          ).animate().fadeIn(duration: 400.ms, delay: 700.ms).slideY(begin: 0.2),
          const SizedBox(height: 20),
          BouncingWidget(
            onTap: widget.onSwitch,
            child: RichText(
              text: TextSpan(
                text: '¿No tienes cuenta? ',
                style: TextStyle(color: subColor, fontSize: 15),
                children: [
                  TextSpan(
                    text: 'Regístrate',
                    style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.5),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _showForgotPassword(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.read(appThemeProvider);
    final primary = AppThemes.primaryColor(appTheme, isDark);
    final secondary = AppThemes.secondaryColor(appTheme);
    final bgColor = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0D1E30);
    final subColor = isDark ? Colors.white54 : const Color(0xFF546E7A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text('Recuperar contraseña',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Ingresa tu correo para restablecer tu contraseña',
                style: TextStyle(color: subColor, fontSize: 13)),
            const SizedBox(height: 16),
            GlowInput(
                hint: 'Tu correo electrónico',
                controller: emailCtrl,
                icon: Icons.email_outlined,
                isDark: isDark,
                primary: primary),
            const SizedBox(height: 16),
            GradientButton(
              text: 'Enviar enlace',
              onTap: () async {
                if (emailCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ingresa tu correo'),
                      backgroundColor: Colors.red));
                  return;
                }
                try {
                  await ref.read(driverApiProvider).resetPasswordLegacy(
                      email: emailCtrl.text.trim(), newPassword: '');
                  if (context.mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Enlace enviado'),
                      backgroundColor: Colors.green));
                } catch (e) {
                  final msg =
                      e is ApiException ? e.message : 'Error al enviar enlace';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(msg), backgroundColor: Colors.red));
                }
              },
              primary: primary,
              secondary: secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= SIGNUP ================= */

class SignupView extends ConsumerWidget {
  final VoidCallback onSwitch;

  const SignupView({super.key, required this.onSwitch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SignupViewContent(onSwitch: onSwitch, ref: ref);
  }
}

class _SignupViewContent extends StatefulWidget {
  final VoidCallback onSwitch;
  final WidgetRef ref;

  const _SignupViewContent({required this.onSwitch, required this.ref});

  @override
  State<_SignupViewContent> createState() => _SignupViewState();
}

class _SignupViewState extends State<_SignupViewContent> {
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  int _role = 1;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _register() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.red));
      return;
    }
    if (_emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty ||
        _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Completa todos los campos obligatorios'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _loading = true);
    try {
      final userRole = _role == 0 ? 'driver' : 'passenger';
      await widget.ref.read(driverApiProvider).createDriver(
            name: _nameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            phone: _phoneCtrl.text.trim(),
            role: userRole,
          );

      widget.ref.read(userProfileProvider.notifier).update(
            widget.ref.read(userProfileProvider).copyWith(
                  name: _nameCtrl.text.trim(),
                  email: _emailCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim(),
                  role: _role == 0 ? UserRole.driver : UserRole.passenger,
                ),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cuenta creada. ¡Inicia sesión!'),
          backgroundColor: Colors.green));
      widget.onSwitch();
    } catch (e) {
      final msg = e is ApiException ? e.message : 'Error al registrarse';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = widget.ref.watch(appThemeProvider);
    final primary = AppThemes.primaryColor(appTheme, isDark);
    final textColor = isDark ? Colors.white : const Color(0xFF0D1E30);
    final subColor = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final secondary = AppThemes.secondaryColor(appTheme);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.topRight,
            child: _ThemeToggleBtn(isDark: isDark, primary: primary),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 10),
          GlowIcon(Icons.person_add_rounded, primary: primary)
              .animate()
              .fadeIn(duration: 600.ms, delay: 100.ms)
              .scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text('Crear cuenta',
              style: TextStyle(
                  fontSize: 28,
                  color: textColor,
                  fontWeight: FontWeight.bold))
              .animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: -0.2),
          Text('Únete a la comunidad de commuters',
              style: TextStyle(color: subColor, fontSize: 13))
              .animate().fadeIn(duration: 500.ms, delay: 300.ms),
          const SizedBox(height: 28),

          // Role selector
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
          children: [
              _roleBtn(0, Icons.drive_eta, 'Conductor', primary, subColor, isDark),
              _roleBtn(1, Icons.person, 'Pasajero', primary, subColor, isDark),
            ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

          const SizedBox(height: 20),
          GlowInput(
              hint: 'Nombre',
              controller: _nameCtrl,
              icon: Icons.person_outline,
              isDark: isDark,
              primary: primary)
              .animate().fadeIn(duration: 400.ms, delay: 450.ms).slideX(begin: -0.1),
          const SizedBox(height: 10),
          GlowInput(
              hint: 'Apellido',
              controller: _lastNameCtrl,
              icon: Icons.person_outline,
              isDark: isDark,
              primary: primary)
              .animate().fadeIn(duration: 400.ms, delay: 500.ms).slideX(begin: -0.1),
          const SizedBox(height: 10),
          GlowInput(
              hint: 'Correo electrónico',
              controller: _emailCtrl,
              icon: Icons.email_outlined,
              isDark: isDark,
              primary: primary)
              .animate().fadeIn(duration: 400.ms, delay: 550.ms).slideX(begin: -0.1),
          const SizedBox(height: 10),
          GlowInput(
              hint: 'Teléfono',
              controller: _phoneCtrl,
              icon: Icons.phone_outlined,
              isDark: isDark,
              primary: primary)
              .animate().fadeIn(duration: 400.ms, delay: 600.ms).slideX(begin: -0.1),
          const SizedBox(height: 10),
          GlowInput(
              hint: 'Contraseña',
              controller: _passCtrl,
              icon: Icons.lock_outline,
              obscure: _obscure,
              isDark: isDark,
              primary: primary,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: subColor, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ))
              .animate().fadeIn(duration: 400.ms, delay: 650.ms).slideX(begin: -0.1),
          const SizedBox(height: 10),
          GlowInput(
              hint: 'Confirmar contraseña',
              controller: _confirmCtrl,
              icon: Icons.lock_outline,
              obscure: true,
              isDark: isDark,
              primary: primary)
              .animate().fadeIn(duration: 400.ms, delay: 700.ms).slideX(begin: -0.1),
          const SizedBox(height: 24),

          GradientButton(
            text: _loading ? 'Registrando...' : 'Crear cuenta',
            onTap: _loading ? null : _register,
            primary: primary,
            secondary: secondary,
          ).animate().fadeIn(duration: 400.ms, delay: 800.ms).slideY(begin: 0.2),
          const SizedBox(height: 20),
          BouncingWidget(
            onTap: widget.onSwitch,
            child: RichText(
              text: TextSpan(
                text: '¿Ya tienes cuenta? ',
                style: TextStyle(color: subColor, fontSize: 15),
                children: [
                  TextSpan(
                      text: 'Inicia sesión',
                      style:
                          TextStyle(color: primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.5),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _roleBtn(int index, IconData icon, String text, Color primary, Color subColor, bool isDark) {
    final active = _role == index;
    return Expanded(
      child: BouncingWidget(
        onTap: () => setState(() => _role = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            border: active ? Border.all(color: primary.withValues(alpha: 0.5)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? primary : subColor),
              const SizedBox(width: 6),
              Text(text,
                  style: TextStyle(
                      color: active ? primary : subColor,
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================= SHARED UI COMPONENTS ================= */

BoxDecoration bgGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF1A2F4A), Color(0xFF0A1628)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
}

class _ThemeToggleBtn extends ConsumerWidget {
  final bool isDark;
  final Color primary;

  const _ThemeToggleBtn({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BouncingWidget(
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            color: primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class GlowIcon extends StatelessWidget {
  final IconData icon;
  final Color primary;
  const GlowIcon(this.icon, {super.key, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.12),
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: Icon(icon, color: primary, size: 34),
    );
  }
}

class GlowInput extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextEditingController? controller;
  final IconData icon;
  final Widget? suffixIcon;
  final bool isDark;
  final Color primary;

  const GlowInput({
    super.key,
    required this.hint,
    this.obscure = false,
    this.controller,
    required this.icon,
    this.suffixIcon,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white : const Color(0xFF0D1E30);
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: bgColor,
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        cursorColor: primary,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          prefixIcon: Icon(icon, color: hintColor, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }
}

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final Color primary;
  final Color secondary;

  const GradientButton({
    super.key,
    required this.text,
    this.onTap,
    required this.primary,
    required this.secondary,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _controller.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedOpacity(
          opacity: widget.onTap == null ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [widget.primary, widget.secondary],
              ),
              boxShadow: [
                BoxShadow(
                    color: widget.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: Text(
                widget.text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
