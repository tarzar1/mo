import 'package:commute_share/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _filterPriceProvider = StateProvider<double>((ref) => 100.0);
final _filterSeatsProvider = StateProvider<int>((ref) => 1);
final _showFiltersProvider = StateProvider<bool>((ref) => false);

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

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

    final query = ref.watch(_searchQueryProvider);
    final maxPrice = ref.watch(_filterPriceProvider);
    final minSeats = ref.watch(_filterSeatsProvider);
    final showFilters = ref.watch(_showFiltersProvider);
    final allTrips = ref.watch(tripsProvider);

    final filtered = allTrips.where((t) {
      final matchQuery = query.isEmpty ||
          t.origin.toLowerCase().contains(query.toLowerCase()) ||
          t.destination.toLowerCase().contains(query.toLowerCase()) ||
          t.driverName.toLowerCase().contains(query.toLowerCase());
      final matchPrice = t.price <= maxPrice;
      final matchSeats = t.seatsAvailable >= minSeats;
      return matchQuery && matchPrice && matchSeats;
    }).toList();

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buscar viaje',
                      style: TextStyle(
                          color: textPri,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  // Search bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: textSec, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => ref
                                .read(_searchQueryProvider.notifier)
                                .state = v,
                            style: TextStyle(color: textPri),
                            decoration: InputDecoration(
                              hintText: 'Origen, destino o conductor...',
                              hintStyle:
                                  TextStyle(color: textSec, fontSize: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ref
                              .read(_showFiltersProvider.notifier)
                              .state = !showFilters,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.tune_rounded,
                                color: primary, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filters panel
          if (showFilters)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filtros',
                        style: TextStyle(
                            color: textPri,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 16),
                    Text('Precio máximo: \$${maxPrice.toInt()}',
                        style: TextStyle(color: textSec, fontSize: 13)),
                    Slider(
                      value: maxPrice,
                      min: 20,
                      max: 200,
                      divisions: 18,
                      activeColor: primary,
                      inactiveColor: primary.withValues(alpha: 0.2),
                      onChanged: (v) =>
                          ref.read(_filterPriceProvider.notifier).state = v,
                    ),
                    const SizedBox(height: 8),
                    Text('Asientos mínimos: $minSeats',
                        style: TextStyle(color: textSec, fontSize: 13)),
                    Row(
                      children: [1, 2, 3, 4].map((n) {
                        final active = n == minSeats;
                        return GestureDetector(
                          onTap: () =>
                              ref.read(_filterSeatsProvider.notifier).state = n,
                          child: Container(
                            margin: const EdgeInsets.only(right: 10, top: 8),
                            width: 44,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  active ? primary : primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: active ? primary : border),
                            ),
                            child: Center(
                              child: Text('$n',
                                  style: TextStyle(
                                      color: active ? Colors.white : textSec,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, curve: Curves.easeOut),
            ),

          // Results count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} viajes encontrados',
                    style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8),
                  ),
                  const Spacer(),
                  if (filtered.any((t) => t.isJoined))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Mis viajes activos',
                          style: TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, curve: Curves.easeOut),
            ),
          ),
          // Trip cards
          filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded,
                            color: textSec, size: 56),
                        const SizedBox(height: 16),
                        Text('Sin resultados',
                            style: TextStyle(
                                color: textPri,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Intenta con otra búsqueda o ajusta los filtros',
                            style: TextStyle(color: textSec, fontSize: 13)),
                      ],
                    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOut),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _TripCard(
                      trip: filtered[i],
                      isDark: isDark,
                      card: card,
                      primary: primary,
                      textPri: textPri,
                      textSec: textSec,
                      border: border,
                      onJoin: () => ref
                          .read(tripsProvider.notifier)
                          .joinTrip(filtered[i].id),
                      onLeave: () => ref
                          .read(tripsProvider.notifier)
                          .leaveTrip(filtered[i].id),
                    ).animate().fadeIn(
                        delay: Duration(milliseconds: 50 * i),
                        duration: 400.ms).slideY(begin: 0.15, curve: Curves.easeOut),
                    childCount: filtered.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  final Color card, primary, textPri, textSec, border;
  final VoidCallback onJoin, onLeave;

  const _TripCard({
    required this.trip,
    required this.isDark,
    required this.card,
    required this.primary,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.onJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = trip.status == TripStatus.full;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: trip.isJoined
              ? primary.withValues(alpha: 0.4)
              : isFull
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : border,
          width: trip.isJoined ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Driver header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  child: Text(trip.driverAvatar,
                      style: TextStyle(
                          color: primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(trip.driverName,
                              style: TextStyle(
                                  color: textPri,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(width: 6),
                          if (trip.driverRating >= 4.9)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('TOP',
                                  style: TextStyle(
                                      color: Color(0xFFFFB800),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFB800), size: 13),
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
                        style: TextStyle(
                            color: primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text('por persona',
                        style: TextStyle(color: textSec, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          // Route
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Icon(Icons.circle, size: 10, color: primary),
                    Container(
                        width: 2,
                        height: 24,
                        color: isDark ? Colors.white24 : Colors.black26),
                    Icon(Icons.location_on, size: 14, color: primary),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.origin,
                          style: TextStyle(
                              color: textPri,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(trip.destination,
                          style: TextStyle(
                              color: textPri,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(trip.departureTime,
                        style: TextStyle(
                            color: textSec,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(trip.arrivalTime,
                        style: TextStyle(
                            color: textSec,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),

          // Amenities + seats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                ...trip.amenities.take(3).map((a) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(a,
                          style: TextStyle(color: primary, fontSize: 10)),
                    )),
                const Spacer(),
                Icon(Icons.event_seat_outlined,
                    color: isFull ? const Color(0xFFFF3B5C) : primary,
                    size: 14),
                const SizedBox(width: 4),
                Text(
                  isFull ? 'Lleno' : '${trip.seatsAvailable} disponibles',
                  style: TextStyle(
                      color: isFull ? const Color(0xFFFF3B5C) : primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Divider + action
          Divider(color: border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showTripDetail(
                        context, trip, isDark, primary, textPri, textSec, card),
                    icon: Icon(Icons.info_outline_rounded,
                        size: 16, color: textSec),
                    label: Text('Detalles',
                        style: TextStyle(color: textSec, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: trip.isJoined
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary.withValues(alpha: 0.15),
                            foregroundColor: primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onLeave,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Cancelar',
                              style: TextStyle(fontSize: 13)),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFull
                                ? const Color(0xFFFF3B5C).withValues(alpha: 0.15)
                                : primary,
                            foregroundColor:
                                isFull ? const Color(0xFFFF3B5C) : isDark ? Colors.black : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isFull ? null : onJoin,
                          icon: Icon(
                              isFull ? Icons.block : Icons.add_circle_outline,
                              size: 16),
                          label: Text(isFull ? 'Lleno' : 'Unirse',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTripDetail(BuildContext context, Trip trip, bool isDark,
      Color primary, Color textPri, Color textSec, Color cardBg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
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
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Detalles del viaje',
                style: TextStyle(
                    color: textPri, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _DetailRow(
                icon: Icons.person_outline,
                label: 'Conductor',
                value: trip.driverName,
                textSec: textSec,
                textPri: textPri),
            _DetailRow(
                icon: Icons.star_rounded,
                label: 'Calificación',
                value: '${trip.driverRating} ⭐',
                textSec: textSec,
                textPri: textPri),
            _DetailRow(
                icon: Icons.my_location_rounded,
                label: 'Origen',
                value: trip.origin,
                textSec: textSec,
                textPri: textPri),
            _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Destino',
                value: trip.destination,
                textSec: textSec,
                textPri: textPri),
            _DetailRow(
                icon: Icons.access_time_rounded,
                label: 'Salida',
                value: trip.departureTime,
                textSec: textSec,
                textPri: textPri),
            _DetailRow(
                icon: Icons.flag_outlined,
                label: 'Llegada',
                value: trip.arrivalTime,
                textSec: textSec,
                textPri: textPri),
            _DetailRow(
                icon: Icons.attach_money_rounded,
                label: 'Precio',
                value: '\$${trip.price.toInt()} por persona',
                textSec: textSec,
                textPri: textPri),
            _DetailRow(
                icon: Icons.event_seat_outlined,
                label: 'Asientos',
                value: '${trip.seatsAvailable} de ${trip.seats} disponibles',
                textSec: textSec,
                textPri: textPri),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: trip.amenities
                  .map((a) => Chip(
                        label: Text(a,
                            style: TextStyle(color: primary, fontSize: 12)),
                        backgroundColor: primary.withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color textSec, textPri;

  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.textSec,
      required this.textPri});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: textSec, size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: textSec, fontSize: 13)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
