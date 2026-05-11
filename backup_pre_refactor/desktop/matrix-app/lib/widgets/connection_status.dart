import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';
import '../providers/matrix_provider.dart';

class ConnectionStatusWidget extends ConsumerWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionStateProvider);
    final isDemo = ref.watch(isDemoModeProvider);

    final icon = isDemo
        ? Icons.preview
        : switch (state) {
            BleConnectionState.connected => Icons.bluetooth_connected,
            BleConnectionState.connecting => Icons.bluetooth_searching,
            BleConnectionState.disconnected => Icons.bluetooth_disabled,
          };

    final label = isDemo
        ? 'Modo Demo'
        : switch (state) {
            BleConnectionState.connected => 'Conectado',
            BleConnectionState.connecting => 'Conectando...',
            BleConnectionState.disconnected => 'Desconectado',
          };

    final color = isDemo
        ? const Color(0xFF00BCD4)
        : switch (state) {
            BleConnectionState.connected => const Color(0xFF00E676),
            BleConnectionState.connecting => const Color(0xFFFFB800),
            BleConnectionState.disconnected => const Color(0xFFFF3B5C),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (state == BleConnectionState.connecting) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          ],
        ],
      ),
    );
  }
}
