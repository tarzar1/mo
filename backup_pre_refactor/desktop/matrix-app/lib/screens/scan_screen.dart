import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/matrix_provider.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  List<ScanResult> _results = [];
  bool _scanning = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    try {
      await FlutterBluePlus.turnOn(timeout: 5);
    } catch (_) {}

    setState(() => _scanning = true);
    _results = [];
    try {
      final svc = ref.read(bleServiceProvider);
      _results = await svc.scan(seconds: 8);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e\nVerifica permisos de Bluetooth'),
            backgroundColor: const Color(0xFFFF3B5C),
          ),
        );
      }
    }
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1628), Color(0xFF061220)],
        ),
      ),
      child: Column(
          children: [
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00D97E).withValues(
                      alpha: 0.05 + _pulseCtrl.value * 0.1),
                  border: Border.all(
                    color: const Color(0xFF00D97E)
                        .withValues(alpha: 0.2 + _pulseCtrl.value * 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.bluetooth_rounded,
                    color: Color(0xFF00D97E), size: 48),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Matrix LED 8x8',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              'Enciende tu ESP32 con la matrix conectada\ny presiona escanear',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_scanning ? 'Escaneando...' : 'Escanear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D97E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF00D97E).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(connectionStateProvider.notifier).enterDemoMode();
                },
                icon: const Icon(Icons.preview, size: 18),
                label: const Text('Probar UI sin conectar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00D97E),
                  side: const BorderSide(color: Color(0xFF00D97E), width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFF1A2A3A), height: 1),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _scanning
                            ? 'Buscando dispositivos...'
                            : 'No se ha encontrado "Matrix 8x8"',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        return _DeviceTile(
                          result: r,
                          onTap: () {
                            ref
                                .read(connectionStateProvider.notifier)
                                .connect(r.device);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;

  const _DeviceTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: const Color(0xFF0D1E30),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D97E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.grid_on,
                      color: Color(0xFF00D97E), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.device.advName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(result.device.remoteId.toString(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF00D97E)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
