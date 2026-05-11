import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'driver_api_service.dart';
import 'chat_list_screen.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String userAvatar;
  final String? requestId;
  final String? requestStatus;
  final bool isDriverView;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.userName = '',
    this.userAvatar = '',
    this.requestId,
    this.requestStatus,
    this.isDriverView = false,
  });

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  UserProfileResponse? _profile;
  bool _loading = true;
  bool _canceling = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  bool get _isAccepted => widget.requestStatus == 'accepted';
  bool get _isPending => widget.requestStatus == 'pending';
  bool get _canCancel => widget.requestId != null && (_isPending || _isAccepted);

  Future<void> _cancelRequest() async {
    if (widget.requestId == null) return;
    
    final isAccepted = _isAccepted;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAccepted ? 'Cancelar viaje' : 'Cancelar solicitud'),
        content: Text(isAccepted 
            ? '¿Estás seguro de que deseas cancelar este viaje? El conductor será notificado.'
            : '¿Estás seguro de que deseas cancelar esta solicitud?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isAccepted ? 'Sí, cancelar viaje' : 'Sí, cancelar', 
              style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _canceling = true);
    try {
      await ref.read(rideRequestsProvider.notifier).cancelRequest(widget.requestId!);
      await ref.read(tripsProvider.notifier).loadTrips();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAccepted ? 'Viaje cancelado' : 'Solicitud cancelada'), 
          backgroundColor: Colors.orange),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Error al cancelar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(driverApiProvider).getPublicProfile(widget.userId);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startChat() async {
    final myId = ref.read(userProfileProvider).id;
    if (myId.isEmpty) return;
    try {
      final conv = await ref.read(driverApiProvider).ensureConversation(myId, widget.userId);
      if (!mounted) return;
      Navigator.push(
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

    final displayName = _profile != null
        ? '${_profile!.name} ${_profile!.lastName}'.trim()
        : widget.userName;
    final avatar = _profile != null
        ? (_profile!.avatarUrl.isNotEmpty
            ? _profile!.avatarUrl[0].toUpperCase()
            : (_profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?'))
        : (widget.userAvatar.isNotEmpty ? widget.userAvatar[0].toUpperCase() : '?');
    final role = _profile?.role ?? 'passenger';
    final phone = _profile?.phone ?? '';
    final rating = _profile?.rating ?? 5.0;
    final tripsCompleted = _profile?.tripsCompleted ?? 0;
    final tripsOffered = _profile?.tripsOffered ?? 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Perfil', style: TextStyle(color: textPri)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    decoration: BoxDecoration(
                      color: card,
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Column(
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
                          ),
                          child: Center(
                            child: Text(avatar,
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(displayName,
                            style: TextStyle(color: textPri, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (role == 'driver' ? primary : const Color(0xFF00D97E)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(role == 'driver' ? 'Conductor' : 'Pasajero',
                                  style: TextStyle(
                                      color: role == 'driver' ? primary : const Color(0xFF00D97E),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                                Text(' $rating',
                                    style: TextStyle(color: textPri, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('Información',
                        style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.email_outlined, label: 'Email', value: _profile?.email ?? '', textSec: textSec, textPri: textPri),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: phone, textSec: textSec, textPri: textPri),
                        ],
                        const SizedBox(height: 12),
                        _InfoRow(icon: Icons.directions_car_outlined, label: 'Viajes tomados', value: '$tripsCompleted', textSec: textSec, textPri: textPri),
                        const SizedBox(height: 12),
                        _InfoRow(icon: Icons.drive_eta_outlined, label: 'Viajes ofrecidos', value: '$tripsOffered', textSec: textSec, textPri: textPri),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startChat,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        label: const Text('Enviar mensaje', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_canCancel)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _canceling ? null : _cancelRequest,
                          icon: _canceling
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(_isAccepted ? Icons.close : Icons.cancel_outlined, size: 20),
                          label: Text(_canceling 
                              ? 'Cancelando...' 
                              : (_isAccepted ? 'Cancelar viaje' : 'Cancelar solicitud'), 
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
   }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color textSec, textPri;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textSec,
    required this.textPri,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: textSec, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: textSec, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: textPri, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );
}
