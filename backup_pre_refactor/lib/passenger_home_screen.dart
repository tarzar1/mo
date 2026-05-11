import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';
import 'providers.dart';
import 'driver_api_service.dart';
import 'notification_screen.dart';
import 'chat_list_screen.dart';

class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen> with WidgetsBindingObserver {
  bool _multiSelectMode = false;
  final Set<String> _selectedTripIds = {};
  final Map<String, String> _requestStatuses = {};
  bool _sending = false;
  bool _waitingForAcceptance = false;
  Timer? _acceptanceTimer;
  List<String> _sentRequestIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTrips();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAcceptanceWatcher();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTrips();
    }
  }

  Future<void> _refreshTrips() async {
    if (mounted) {
      await ref.read(tripsProvider.notifier).loadTrips();
    }
  }

  void _toggleMultiSelect() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) _selectedTripIds.clear();
    });
  }

  void _toggleSelection(String tripId) {
    setState(() {
      if (_selectedTripIds.contains(tripId)) {
        _selectedTripIds.remove(tripId);
      } else {
        _selectedTripIds.add(tripId);
      }
    });
  }

  Future<void> _requestJoin(Trip trip) async {
    final tripId = trip.id;
    setState(() => _requestStatuses[tripId] = 'sending');

    try {
      await ref.read(rideRequestsProvider.notifier).createRequest(tripId);
      _startSingleAcceptanceWatcher(tripId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestStatuses.remove(tripId));
      final msg = e is ApiException ? e.message : 'Error al enviar solicitud';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  void _startSingleAcceptanceWatcher(String tripId) {
    _acceptanceTimer?.cancel();
    _acceptanceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) { _stopAcceptanceWatcher(); return; }
      final requests = ref.read(rideRequestsProvider);
      final accepted = requests.where((r) => r.offerId == tripId && r.status == 'accepted').toList();
      if (accepted.isNotEmpty) {
        _stopAcceptanceWatcher();
        if (!mounted) return;
        setState(() => _requestStatuses[tripId] = 'accepted');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Viaje confirmado con ${accepted.first.driverName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          _navigateToChat(accepted.first.driverId);
        });
      }
    });
  }

  void _stopAcceptanceWatcher() {
    _acceptanceTimer?.cancel();
    _acceptanceTimer = null;
  }

  Future<void> _sendBatchRequests() async {
    if (_selectedTripIds.isEmpty) return;

    setState(() {
      _sending = true;
      _waitingForAcceptance = true;
      for (final id in _selectedTripIds) {
        _requestStatuses[id] = 'sending';
      }
    });

    try {
      final requestIds = await ref.read(rideRequestsProvider.notifier).batchCreateRequests(
        _selectedTripIds.toList(),
      );
      if (!mounted) return;
      _sentRequestIds = requestIds;
      _startBatchAcceptanceWatcher();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _waitingForAcceptance = false;
        for (final id in _selectedTripIds) {
          _requestStatuses.remove(id);
        }
      });
      final msg = e is ApiException ? e.message : 'Error al enviar solicitudes';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  void _startBatchAcceptanceWatcher() {
    _acceptanceTimer?.cancel();
    _acceptanceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) { _stopAcceptanceWatcher(); return; }
      final requests = ref.read(rideRequestsProvider);
      final accepted = requests.where((r) => _sentRequestIds.contains(r.id) && r.status == 'accepted').toList();
      if (accepted.isNotEmpty) {
        _stopAcceptanceWatcher();
        _onBatchAccepted(accepted.first);
      }
    });
  }

  void _onBatchAccepted(RideRequest acceptedRequest) {
    final otherIds = _sentRequestIds.where((id) => id != acceptedRequest.id).toList();
    ref.read(rideRequestsProvider.notifier).dropRequests(otherIds);

    if (!mounted) return;
    setState(() {
      _waitingForAcceptance = false;
      _sending = false;
      _multiSelectMode = false;
      _selectedTripIds.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00D97E), size: 64),
            const SizedBox(height: 16),
            const Text('Viaje confirmado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Conductor: ${acceptedRequest.driverName}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text('${acceptedRequest.recogida} → ${acceptedRequest.destino}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToChat(acceptedRequest.driverId);
            },
            child: const Text('Ir al chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(String otherUserId) {
    final myId = ref.read(userProfileProvider).id;
    if (myId.isEmpty) return;
    ref.read(driverApiProvider).ensureConversation(myId, otherUserId).then((conv) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversationId: conv.id),
      ));
    });
  }

  void _cancelBatchSearch() {
    _stopAcceptanceWatcher();
    final remainingIds = _sentRequestIds;
    if (remainingIds.isNotEmpty) {
      for (final id in remainingIds) {
        try {
          ref.read(rideRequestsProvider.notifier).cancelRequest(id);
        } catch (_) {}
      }
    }
    setState(() {
      _waitingForAcceptance = false;
      _sending = false;
      _multiSelectMode = false;
      _selectedTripIds.clear();
      _sentRequestIds = [];
    });
  }

  int get _selectedCount => _selectedTripIds.length;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final trips = ref.watch(tripsProvider);

    final primary = AppThemes.primaryColor(appTheme, isDark);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light).scaffoldBackgroundColor;
    final card = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textPri = isDark ? Colors.white : const Color(0xFF0D1E30);
    final textSec = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;

    final currentUserId = ref.watch(userProfileProvider).id;
    final availableTrips = trips
        .where((t) => t.status == TripStatus.available && t.driverId != currentUserId)
        .toList();

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  decoration: BoxDecoration(
                    color: card,
                    border: Border(bottom: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Viajes disponibles',
                                style: TextStyle(color: textSec, fontSize: 13))
                                .animate().fadeIn(duration: 400.ms),
                            Text('${availableTrips.length} viajes',
                                style: TextStyle(color: textPri, fontSize: 22, fontWeight: FontWeight.bold))
                                .animate().fadeIn(duration: 500.ms, delay: 100.ms),
                          ],
                        ),
                      ),
                      // Multi-select toggle
                      GestureDetector(
                        onTap: _multiSelectMode ? null : _toggleMultiSelect,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _multiSelectMode ? primary.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _multiSelectMode ? primary : border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _multiSelectMode ? Icons.checklist : Icons.playlist_add_check_rounded,
                                size: 18,
                                color: _multiSelectMode ? primary : textSec,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _multiSelectMode ? 'Hecho' : 'Multi',
                                style: TextStyle(
                                  color: _multiSelectMode ? primary : textSec,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _NotificationIcon(ref: ref, primary: primary, border: border, notificationScreen: const NotificationScreen()),
                    ],
                  ),
                ),
              ),
              // Trips list
              if (availableTrips.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: textSec),
                        const SizedBox(height: 16),
                        Text('No hay viajes disponibles',
                            style: TextStyle(color: textPri, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Vuelve más tarde o cambia tus filtros',
                            style: TextStyle(color: textSec, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final trip = availableTrips[i];
                      final status = _requestStatuses[trip.id] ?? 'idle';
                      final isSelected = _selectedTripIds.contains(trip.id);
                      return _TripCard(
                        trip: trip,
                        isDark: isDark,
                        card: card,
                        primary: primary,
                        textPri: textPri,
                        textSec: textSec,
                        border: border,
                        isMultiSelectMode: _multiSelectMode,
                        isSelected: isSelected,
                        requestStatus: status,
                        onRequestJoin: status == 'idle' ? () => _requestJoin(trip) : null,
                        onToggleSelection: _multiSelectMode ? () => _toggleSelection(trip.id) : null,
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: 60 * i),
                        duration: 400.ms,
                      ).slideY(begin: 0.15, curve: Curves.easeOut);
                    },
                    childCount: availableTrips.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          // Waiting for acceptance modal
          if (_waitingForAcceptance)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 48, height: 48,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 20),
                      Text('Esperando respuesta...',
                          style: TextStyle(color: textPri, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Solicitudes enviadas a $_selectedCount conductores',
                          style: TextStyle(color: textSec, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('El primero que acepte será tu viaje',
                          style: TextStyle(color: textSec, fontSize: 12)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _cancelBatchSearch,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancelar búsqueda'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Multi-select bottom bar
          if (_multiSelectMode && !_waitingForAcceptance)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                height: _selectedCount > 0 ? 80 : 0,
                child: _selectedCount > 0
                    ? Container(
                        padding: EdgeInsets.only(
                          left: 20, right: 20, top: 12,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                        ),
                        decoration: BoxDecoration(
                          color: card,
                          border: Border(top: BorderSide(color: border)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$_selectedCount seleccionado${_selectedCount > 1 ? 's' : ''}',
                                        style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('Toca para deseleccionar',
                                        style: TextStyle(color: textSec, fontSize: 11)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _sending ? null : _sendBatchRequests,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 18, height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.send_rounded, size: 18),
                                  label: Text(
                                    _sending ? 'Enviando...' : 'Solicitar a $_selectedCount',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── NOTIFICATION ICON ─────────────────────────────────────────────────────

class _NotificationIcon extends StatelessWidget {
  final WidgetRef ref;
  final Color primary;
  final Color border;
  final Widget notificationScreen;

  const _NotificationIcon({
    required this.ref,
    required this.primary,
    required this.border,
    required this.notificationScreen,
  });

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final hasUnread = notifications.any((n) => !n.isRead);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => notificationScreen)),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border),
          color: Colors.transparent,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_outlined, color: primary, size: 20),
            if (hasUnread)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── TRIP CARD ─────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  final Color card, primary, textPri, textSec, border;
  final bool isMultiSelectMode;
  final bool isSelected;
  final String requestStatus;
  final VoidCallback? onRequestJoin;
  final VoidCallback? onToggleSelection;

  const _TripCard({
    required this.trip,
    required this.isDark,
    required this.card,
    required this.primary,
    required this.textPri,
    required this.textSec,
    required this.border,
    this.isMultiSelectMode = false,
    this.isSelected = false,
    this.requestStatus = 'idle',
    this.onRequestJoin,
    this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleSelection,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  if (isMultiSelectMode) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? primary : textSec,
                        size: 24,
                      ),
                    ),
                  ],
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primary.withValues(alpha: 0.15),
                    child: Text(trip.driverAvatar,
                        style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.driverName,
                            style: TextStyle(color: textPri, fontWeight: FontWeight.w700, fontSize: 14)),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: 13),
                            const SizedBox(width: 3),
                            Text('${trip.driverRating}',
                                style: TextStyle(color: textSec, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${trip.price.toInt()}',
                          style: TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('por persona',
                          style: TextStyle(color: textSec, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Icon(Icons.circle, size: 10, color: primary),
                      Container(width: 2, height: 24, color: isDark ? Colors.white24 : Colors.black26),
                      Icon(Icons.location_on, size: 14, color: primary),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.origin,
                            style: TextStyle(color: textPri, fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(trip.destination,
                            style: TextStyle(color: textPri, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(trip.departureTime,
                          style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(trip.arrivalTime,
                          style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.event_seat_outlined, color: primary, size: 14),
                  const SizedBox(width: 4),
                  Text('${trip.seatsAvailable} asientos',
                      style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  const Spacer(),
                ],
              ),
            ),
            Divider(color: border, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _buildButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    if (isMultiSelectMode) {
      return const SizedBox.shrink();
    }

    if (requestStatus == 'accepted') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF00D97E).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF00D97E), size: 18),
            SizedBox(width: 8),
            Text('Viaje confirmado', style: TextStyle(color: Color(0xFF00D97E), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }

    if (requestStatus == 'sending') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary.withValues(alpha: 0.5),
            disabledBackgroundColor: primary.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
              SizedBox(width: 8),
              Text('Esperando confirmación...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onRequestJoin,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('Solicitar unirse', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
