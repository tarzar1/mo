import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';
import 'providers.dart';
import 'driver_api_service.dart';
import 'public_profile_screen.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> with WidgetsBindingObserver {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadRequests();
        _startPolling();
      }
    });
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadRequests();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    debugPrint('RequestsScreen: Cargando solicitudes...');
    final user = ref.read(userProfileProvider);
    if (!mounted) return;
    await ref.read(rideRequestsProvider.notifier).loadByRole(user.role);
    if (!mounted) return;
    debugPrint('RequestsScreen: Solicitudes cargadas');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bottomNavIndexProvider, (previous, next) {
      if (next == 1) _loadRequests();
    });

    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final user = ref.watch(userProfileProvider);
    final requests = ref.watch(rideRequestsProvider);

    final primary = AppThemes.primaryColor(appTheme, isDark);
    final secondary = AppThemes.secondaryColor(appTheme);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light)
            .scaffoldBackgroundColor;
    final card = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textPri = isDark ? Colors.white : const Color(0xFF0D1E30);
    final textSec = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;

    final isDriver = user.role == UserRole.driver;
    final pending = requests.where((r) => r.status == 'pending').toList();
    final active = requests.where((r) => r.status == 'pending' || r.status == 'accepted').toList();

    const statusColors = {
      'pending': Color(0xFFFFB800),
      'accepted': Color(0xFF00D97E),
      'rejected': Color(0xFFFF3B5C),
      'cancelled': Color(0xFF9E9E9E),
    };

    const statusLabels = {
      'pending': 'Pendiente',
      'accepted': 'Aceptado',
      'rejected': 'Rechazado',
      'cancelled': 'Cancelado',
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            Container(
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
                      Text(isDriver ? 'Pasajeros' : 'Mis solicitudes',
                              style: TextStyle(color: textSec, fontSize: 13))
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.1),
                      Text(
                              isDriver
                                  ? '${pending.length} pendientes'
                                  : '${active.length} activas',
                              style: TextStyle(
                                  color: textPri,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold))
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 100.ms)
                          .slideX(begin: -0.1),
                    ],
                  ),
                  const Spacer(),
                  if (isDriver && pending.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          '${pending.length} nuevo${pending.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Color(0xFFFFB800),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 200.ms)
                        .scaleXY(
                            begin: 0.5,
                            duration: 400.ms,
                            curve: Curves.elasticOut),
                ],
              ),
            ),
            Container(
              color: card,
              child: TabBar(
                indicatorColor: primary,
                labelColor: primary,
                unselectedLabelColor: textSec,
                tabs: const [
                  Tab(text: 'Activas'),
                  Tab(text: 'Historial'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildListTab(
                    requests: active,
                    emptyIcon: isDriver ? Icons.people_outline : Icons.send_outlined,
                    emptyTitle: isDriver ? 'Sin solicitudes' : 'Sin solicitudes activas',
                    emptySubtitle: isDriver ? 'Los pasajeros aparecerán aquí' : 'Solicita unirte a un viaje disponible',
                    isDriver: isDriver, isDark: isDark, appTheme: appTheme,
                    card: card, primary: primary, secondary: secondary,
                    textPri: textPri, textSec: textSec, border: border,
                    statusColors: statusColors, statusLabels: statusLabels,
                    onAccept: (req) => _handleAccept(context, ref, req),
                    onReject: (req) => _handleReject(context, ref, req),
                    onCancel: (req) => _handleCancel(context, ref, req),
                  ),
                  _buildHistoryTab(
                    cancelled: requests.where((r) => r.status == 'cancelled').toList(),
                    rejected: requests.where((r) => r.status == 'rejected').toList(),
                    isDriver: isDriver, isDark: isDark, appTheme: appTheme,
                    card: card, primary: primary, secondary: secondary,
                    textPri: textPri, textSec: textSec, border: border,
                    statusColors: statusColors, statusLabels: statusLabels,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAccept(
      BuildContext context, WidgetRef ref, RideRequest req) async {
    try {
      await ref.read(rideRequestsProvider.notifier).acceptRequest(req.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitud aceptada ✅'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is ApiException ? e.message : 'Error al aceptar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleReject(
      BuildContext context, WidgetRef ref, RideRequest req) async {
    try {
      await ref.read(rideRequestsProvider.notifier).rejectRequest(req.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitud rechazada'),
            backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is ApiException ? e.message : 'Error al rechazar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleCancel(
      BuildContext context, WidgetRef ref, RideRequest req) async {
    try {
      await ref.read(rideRequestsProvider.notifier).cancelRequest(req.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitud cancelada'),
            backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is ApiException ? e.message : 'Error al cancelar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildListTab({
    required List<RideRequest> requests,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isDriver,
    required bool isDark,
    required AppThemeVariant appTheme,
    required Color card, primary, secondary, textPri, textSec, border,
    required Map<String, Color> statusColors,
    required Map<String, String> statusLabels,
    void Function(RideRequest)? onAccept,
    void Function(RideRequest)? onReject,
    void Function(RideRequest)? onCancel,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: textSec),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: TextStyle(color: textPri, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(emptySubtitle,
                style: TextStyle(color: textSec, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: primary,
      backgroundColor: card,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 100),
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final req = requests[i];
          return _buildCard(req, isDriver, isDark, appTheme,
              card, primary, secondary, textPri, textSec, border,
              statusColors, statusLabels,
              onAccept: onAccept, onReject: onReject, onCancel: onCancel,
          ).animate().fadeIn(
            delay: Duration(milliseconds: 40 * i),
            duration: 400.ms,
          ).slideY(begin: 0.1, curve: Curves.easeOut);
        },
      ),
    );
  }

  Widget _buildHistoryTab({
    required List<RideRequest> cancelled,
    required List<RideRequest> rejected,
    required bool isDriver,
    required bool isDark,
    required AppThemeVariant appTheme,
    required Color card, primary, secondary, textPri, textSec, border,
    required Map<String, Color> statusColors,
    required Map<String, String> statusLabels,
  }) {
    if (cancelled.isEmpty && rejected.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: textSec),
            const SizedBox(height: 16),
            Text('Sin historial',
                style: TextStyle(color: textPri, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('No hay viajes cancelados o rechazados',
                style: TextStyle(color: textSec, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: primary,
      backgroundColor: card,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 100),
        children: [
          if (cancelled.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text('Cancelados',
                  style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            ...cancelled.map((req) => _buildCard(req, isDriver, isDark, appTheme,
                card, primary, secondary, textPri, textSec, border, statusColors, statusLabels)),
          ],
          if (rejected.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Rechazados',
                  style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            ...rejected.map((req) => _buildCard(req, isDriver, isDark, appTheme,
                card, primary, secondary, textPri, textSec, border, statusColors, statusLabels)),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(
    RideRequest req, bool isDriver, bool isDark, AppThemeVariant appTheme,
    Color card, Color primary, Color secondary, Color textPri, Color textSec, Color border,
    Map<String, Color> statusColors, Map<String, String> statusLabels, {
    void Function(RideRequest)? onAccept,
    void Function(RideRequest)? onReject,
    void Function(RideRequest)? onCancel,
  }) {
    final targetId = isDriver ? req.passengerId : req.driverId;
    final targetName = isDriver ? req.passengerName : req.driverName;
    final targetAvatar = isDriver ? req.passengerAvatar : '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(
            userId: targetId,
            userName: targetName,
            userAvatar: targetAvatar,
            requestId: req.id,
            requestStatus: req.status,
            isDriverView: isDriver,
          ),
        ),
      ),
      child: _RequestCard(
        request: req,
        isDriver: isDriver,
        isDark: isDark,
        card: card,
        primary: primary,
        secondary: secondary,
        textPri: textPri,
        textSec: textSec,
        border: border,
        statusColor: statusColors[req.status] ?? Colors.grey,
        statusLabel: statusLabels[req.status] ?? req.status,
        onAccept: onAccept != null && isDriver && req.status == 'pending'
            ? () => onAccept(req) : null,
        onReject: onReject != null && isDriver && req.status == 'pending'
            ? () => onReject(req) : null,
        onCancel: onCancel != null && !isDriver && (req.status == 'pending' || req.status == 'accepted')
            ? () => onCancel(req) : null,
      ),
    );
  }
}

String _formatRequestTime(String isoDate) {
  try {
    return formatRelativeTime(DateTime.parse(isoDate));
  } catch (_) {
    return isoDate;
  }
}

class _RequestCard extends StatelessWidget {
  final RideRequest request;
  final bool isDriver;
  final bool isDark;
  final Color card, primary, secondary, textPri, textSec, border;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const _RequestCard({
    required this.request,
    required this.isDriver,
    required this.isDark,
    required this.card,
    required this.primary,
    required this.secondary,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.statusColor,
    required this.statusLabel,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = isDriver ? request.passengerName : request.driverName;
    final displayAvatar = isDriver ? request.passengerAvatar : '?';
    final route = '${request.recogida} → ${request.destino}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              request.status == 'pending' ? primary.withValues(alpha: 0.3) : border,
          width: request.status == 'pending' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    (isDriver ? primary : secondary).withValues(alpha: 0.15),
                child: Text(displayAvatar,
                    style: TextStyle(
                        color: isDriver ? primary : secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName.isNotEmpty ? displayName : 'Usuario',
                        style: TextStyle(
                            color: textPri,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    if (request.passengerPhone.isNotEmpty && isDriver)
                      Text(request.passengerPhone,
                          style: TextStyle(color: textSec, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.route_outlined, size: 14, color: textSec),
              const SizedBox(width: 6),
              Expanded(
                child: Text(route,
                    style: TextStyle(
                        color: textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (request.price > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.attach_money, size: 14, color: textSec),
                const SizedBox(width: 6),
                Text('\$${request.price.toInt()}',
                    style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: textSec),
              const SizedBox(width: 6),
              Text(_formatRequestTime(request.createdAt),
                  style: TextStyle(color: textSec, fontSize: 12)),
            ],
          ),
          if (request.status == 'pending' && isDriver) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AnimatedActionButton(
                    onTap: onReject,
                    icon: Icons.close,
                    label: 'Rechazar',
                    bgColor: const Color(0xFFFF3B5C).withValues(alpha: 0.15),
                    fgColor: const Color(0xFFFF3B5C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AnimatedActionButton(
                    onTap: onAccept,
                    icon: Icons.check,
                    label: 'Aceptar',
                    bgColor: primary,
                    fgColor: Colors.white,
                  ),
                ),
              ],
            ),
          ] else if (!isDriver && (request.status == 'pending' || request.status == 'accepted')) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _AnimatedActionButton(
                onTap: onCancel,
                icon: Icons.cancel_outlined,
                label: 'Cancelar solicitud',
                bgColor: const Color(0xFFFF3B5C).withValues(alpha: 0.1),
                fgColor: const Color(0xFFFF3B5C),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color fgColor;

  const _AnimatedActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _ctrl.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _ctrl.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: widget.fgColor),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                      color: widget.fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
