import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';
import 'providers.dart';
import 'driver_api_service.dart';
import 'notification_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripsProvider.notifier).loadTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final trips = ref.watch(tripsProvider);
    final user = ref.watch(userProfileProvider);
    final availableTrips =
        trips.where((t) => t.status == TripStatus.available).length;

    final primary = AppThemes.primaryColor(appTheme, isDark);
    final secondary = AppThemes.secondaryColor(appTheme);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light).scaffoldBackgroundColor;
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buen día,',
                          style: TextStyle(color: textSec, fontSize: 13))
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: -0.2, duration: 400.ms),
                      Text(
                        user.name.split(' ').first,
                        style: TextStyle(
                            color: textPri,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 100.ms)
                          .slideY(begin: -0.2, duration: 500.ms),
                    ],
                  ),
                  const Spacer(),
                  _NotificationIcon(ref: ref, primary: primary, border: border),
                ],
              ),
            ),
          ),

          // Stats row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Viajes disponibles',
                      value: '$availableTrips',
                      icon: Icons.directions_car_rounded,
                      color: primary,
                      card: card,
                      textPri: textPri,
                      textSec: textSec,
                      border: border,
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.3, duration: 400.ms),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Mis viajes',
                      value: '${trips.where((t) => t.isJoined).length}',
                      icon: Icons.check_circle_outline,
                      color: secondary,
                      card: card,
                      textPri: textPri,
                      textSec: textSec,
                      border: border,
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.3, duration: 400.ms),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Calificación',
                      value: '${user.rating}',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFFFB800),
                      card: card,
                      textPri: textPri,
                      textSec: textSec,
                      border: border,
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.3, duration: 400.ms),
                  ),
                ],
              ),
            ),
          ),

          // Map placeholder
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                  gradient: LinearGradient(
                    colors: AppThemes.gradientColors(appTheme),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    CustomPaint(
                        painter: _MapGridPainter(isDark: isDark),
                        size: Size.infinite),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: primary.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    spreadRadius: 4),
                              ],
                            ),
                            child: Icon(Icons.location_on,
                                color: isDark ? const Color(0xFF0D1E30) : Colors.white, size: 28),
                          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10)
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.near_me_rounded,
                                    color: primary, size: 14),
                                const SizedBox(width: 6),
                                Text('Tu ubicación actual',
                                    style: TextStyle(
                                        color: textPri,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
            ),
          ),

          // Quick actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Acciones rápidas',
                  style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                        label: 'Ofrecer viaje',
                        icon: Icons.add_circle_outline,
                        color: primary,
                        card: card,
                        textPri: textPri,
                        border: border,
                        onTap: () => _showOfferTripDialog(context, ref)),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideX(begin: -0.2, duration: 400.ms),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                        label: 'Buscar viaje',
                        icon: Icons.search_rounded,
                        color: secondary,
                        card: card,
                        textPri: textPri,
                        border: border,
                        onTap: () =>
                            ref.read(bottomNavIndexProvider.notifier).state = 1),
                  ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideX(begin: -0.2, duration: 400.ms),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                        label: 'Historial',
                        icon: Icons.history_rounded,
                        color: const Color(0xFFFFB800),
                        card: card,
                        textPri: textPri,
                        border: border,
                        onTap: () => _showHistory(context, ref)),
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideX(begin: -0.2, duration: 400.ms),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                        label: 'Favoritos',
                        icon: Icons.favorite_border_rounded,
                        color: const Color(0xFFFF3B5C),
                        card: card,
                        textPri: textPri,
                        border: border,
                        onTap: () => _showFavorites(context, ref)),
                  ).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideX(begin: -0.2, duration: 400.ms),
                ],
              ),
            ),
          ),

          // Recent trips header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text('Viajes cercanos',
                      style: TextStyle(
                          color: textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8))
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 500.ms),
                  const Spacer(),
                  BouncingWidget(
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 1,
                    child: Text('Ver todos',
                        style: TextStyle(
                            color: primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
                ],
              ),
            ),
          ),

          // Trips list preview
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final trip = trips
                    .where((t) => t.status == TripStatus.available)
                    .take(3)
                    .toList()[i];
                return BouncingWidget(
                  onTap: () => _showTripDetails(context, ref, trip),
                  child: _TripPreviewCard(
                      trip: trip,
                      isDark: isDark,
                      card: card,
                      primary: primary,
                      textPri: textPri,
                      textSec: textSec,
                      border: border,
                      ref: ref),
                ).animate().fadeIn(duration: 400.ms, delay: (700 + i * 100).ms).slideY(begin: 0.2, duration: 400.ms);
              },
              childCount: trips
                  .where((t) => t.status == TripStatus.available)
                  .take(3)
                  .length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showOfferTripDialog(BuildContext context, WidgetRef ref) {
    final originCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final seatsCtrl = TextEditingController(text: '4');
    final hourCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final bgColor = getModalBackground(ref);
    final textColor = getModalTextColor(ref);
    final subColor = getModalTextSecondaryColor(ref);
    final primary = getModalPrimaryColor(ref);
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text('Ofrecer viaje',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                TextField(
                  controller: originCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Origen',
                    labelStyle: TextStyle(color: subColor),
                    prefixIcon: Icon(Icons.location_on_outlined, color: subColor),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: destCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Destino',
                    labelStyle: TextStyle(color: subColor),
                    prefixIcon: Icon(Icons.location_searching_outlined, color: subColor),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hourCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Hora salida',
                          hintText: '08:00',
                          labelStyle: TextStyle(color: subColor),
                          prefixIcon: Icon(Icons.access_time, color: subColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: timeCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Duración',
                          hintText: '30 min',
                          labelStyle: TextStyle(color: subColor),
                          prefixIcon: Icon(Icons.timer_outlined, color: subColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Precio',
                          labelStyle: TextStyle(color: subColor),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: textColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: seatsCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Asientos',
                          labelStyle: TextStyle(color: subColor),
                          prefixIcon: Icon(Icons.event_seat_outlined, color: subColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: modelCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Modelo auto',
                          hintText: 'Toyota Corolla',
                          labelStyle: TextStyle(color: subColor),
                          prefixIcon: Icon(Icons.directions_car, color: subColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: plateCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Placa',
                          hintText: 'ABC-123',
                          labelStyle: TextStyle(color: subColor),
                          prefixIcon: Icon(Icons.confirmation_number, color: subColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: BouncingWidget(
                    onTap: loading
                        ? null
                        : () async {
                            if (originCtrl.text.trim().isEmpty ||
                                destCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Completa origen y destino'),
                                    backgroundColor: Colors.red),
                              );
                              return;
                            }
                            setSheetState(() => loading = true);
                            try {
                              await ref.read(driverApiProvider).createMyOffer(
                                    recogida: originCtrl.text.trim(),
                                    destino: destCtrl.text.trim(),
                                    price: double.tryParse(priceCtrl.text) ?? 0,
                                    trips: int.tryParse(seatsCtrl.text) ?? 4,
                                    hour: hourCtrl.text.trim(),
                                    time: timeCtrl.text.trim(),
                                    modeloAuto: modelCtrl.text.trim(),
                                    placaAuto: plateCtrl.text.trim(),
                                    color: primary.toARGB32().toRadixString(16).padLeft(8, '0'),
                                    colorText: 'FFFFFFFF',
                                  );
                              await ref.read(tripsProvider.notifier).loadTrips();
                              if (ctx.mounted) Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Viaje publicado con éxito ✅'),
                                    backgroundColor: Colors.green),
                              );
                            } catch (e) {
                              final msg = e is ApiException ? e.message : 'Error al publicar';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg), backgroundColor: Colors.red),
                              );
                            } finally {
                              if (ctx.mounted) setSheetState(() => loading = false);
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(loading ? 'Publicando...' : 'Publicar viaje',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    final trips = ref.read(tripsProvider);
    final completedTrips =
        trips.where((t) => t.status == TripStatus.completed).toList();
    final bgColor = getModalBackground(ref);
    final textColor = getModalTextColor(ref);
    final subColor = getModalTextSecondaryColor(ref);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ref.read(themeModeProvider) == ThemeMode.dark
                    ? Colors.white24
                    : Colors.black26,
                borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Historial de viajes',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold))),
            Expanded(
              child: completedTrips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: subColor),
                          const SizedBox(height: 16),
                          Text('No hay viajes completados',
                              style:
                                  TextStyle(color: subColor, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: completedTrips.length,
                      itemBuilder: (context, i) {
                        final trip = completedTrips[i];
                        return ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
                          title: Text('${trip.origin} → ${trip.destination}',
                              style: TextStyle(color: textColor)),
                          subtitle: Text(trip.departureTime,
                              style: TextStyle(color: subColor)),
                          trailing: Text('\$${trip.price}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: getModalPrimaryColor(ref))),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFavorites(BuildContext context, WidgetRef ref) {
    final bgColor = getModalBackground(ref);
    final textColor = getModalTextColor(ref);
    final subColor = getModalTextSecondaryColor(ref);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ref.read(themeModeProvider) == ThemeMode.dark
                    ? Colors.white24
                    : Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Favoritos',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border,
                        size: 64, color: subColor),
                    const SizedBox(height: 16),
                    Text('No tienes favoritos aún',
                        style: TextStyle(color: subColor, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(bottomNavIndexProvider.notifier).state = 1;
                      },
                      child: Text('Buscar viajes',
                          style: TextStyle(color: getModalPrimaryColor(ref))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTripDetails(BuildContext context, WidgetRef ref, Trip trip) {
    final bgColor = getModalBackground(ref);
    final textColor = getModalTextColor(ref);
    final subColor = getModalTextSecondaryColor(ref);
    final primary = getModalPrimaryColor(ref);
    final user = ref.read(userProfileProvider);

    final isMyOffer = trip.driverId == user.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ref.read(themeModeProvider) == ThemeMode.dark
                      ? Colors.white24
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primary.withValues(alpha:  0.1),
                  child: Text(trip.driverAvatar,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.driverName,
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text('${trip.driverRating}',
                              style: TextStyle(color: subColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('${trip.origin} → ${trip.destination}',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: subColor),
                const SizedBox(width: 8),
                Text('${trip.departureTime} - ${trip.arrivalTime}',
                    style: TextStyle(color: subColor)),
                const Spacer(),
                Text('\$${trip.price}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.event_seat, size: 16, color: subColor),
                const SizedBox(width: 8),
                Text('${trip.seatsAvailable} asientos disponibles',
                    style: TextStyle(color: subColor)),
              ],
            ),
            const SizedBox(height: 20),
            if (isMyOffer)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(driverApiProvider).deleteOffer(trip.id);
                      await ref.read(tripsProvider.notifier).loadTrips();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Viaje eliminado 🗑️'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      final msg = e is ApiException ? e.message : 'Error al eliminar';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), backgroundColor: Colors.red),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar viaje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final WidgetRef ref;
  final Color primary;
  final Color border;

  const _NotificationIcon({
    required this.ref,
    required this.primary,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final hasUnread = notifications.any((n) => !n.isRead);

    return BouncingWidget(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
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
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                      begin: const Offset(1, 1),
                      end: const Offset(1.3, 1.3),
                    )
                    .then()
                    .scale(
                      duration: 800.ms,
                      begin: const Offset(1.3, 1.3),
                      end: const Offset(1, 1),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool isDark;

  _MapGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black12
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color card;
  final Color textPri;
  final Color border;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.card,
    required this.textPri,
    required this.border,
    this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 0.1,
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
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 24),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.textPri,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripPreviewCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  final Color card;
  final Color primary;
  final Color textPri;
  final Color textSec;
  final Color border;
  final WidgetRef ref;

  const _TripPreviewCard({
    required this.trip,
    required this.isDark,
    required this.card,
    required this.primary,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_car, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.origin} → ${trip.destination}',
                  style: TextStyle(
                    color: textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      trip.driverName,
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.star, color: const Color(0xFFFFB800), size: 12),
                    Text(
                      ' ${trip.driverRating}',
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      trip.departureTime,
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '\$${trip.price}',
                      style: TextStyle(
                        color: const Color(0xFF00D97E),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: textSec),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color card;
  final Color textPri;
  final Color textSec;
  final Color border;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.card,
    required this.textPri,
    required this.textSec,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textPri,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: textSec,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
