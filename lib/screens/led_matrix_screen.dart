import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/matrix_ble_provider.dart';
import '../services/matrix_ble_service.dart';
import '../theme.dart';

class LedMatrixScreen extends ConsumerStatefulWidget {
  const LedMatrixScreen({super.key});

  @override
  ConsumerState<LedMatrixScreen> createState() => _LedMatrixScreenState();
}

class _LedMatrixScreenState extends ConsumerState<LedMatrixScreen> {
  List<ScanResult> _scanResults = [];
  bool _scanning = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() => _scanning = true);

    try {
      final service = ref.read(matrixBleServiceProvider);
      final results = await service.scan(timeout: const Duration(seconds: 8));
      setState(() {
        _scanResults = results
            .where((r) => r.device.advName.isNotEmpty)
            .toList();
        _scanning = false;
      });
    } catch (e) {
      setState(() => _scanning = false);
      if (mounted) {
        showErrorSnackBar(context, 'Error al escanear: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(matrixConnectionProvider);
    final brightness = ref.watch(matrixBrightnessProvider);
    final speed = ref.watch(matrixSpeedProvider);
    final currentAnim = ref.watch(matrixCurrentAnimProvider);
    final animations = ref.watch(matrixAnimationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = getModalPrimaryColor(ref);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Matrix LED 8x8'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final service = ref.read(matrixBleServiceProvider);
            if (service.isConnected) {
              service.stop();
              service.clear();
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (connState == MatrixConnectionState.connected)
            IconButton(
              icon: const Icon(Icons.bluetooth_connected, color: Colors.green),
              tooltip: 'Desconectar',
              onPressed: () {
                ref.read(matrixConnectionProvider.notifier).disconnect();
                ref.read(matrixCurrentAnimProvider.notifier).state = null;
              },
            ),
        ],
      ),
      body: connState == MatrixConnectionState.connected
          ? _buildControlPanel(
              animations, currentAnim, brightness, speed, primary, isDark)
          : connState == MatrixConnectionState.connecting
              ? _buildConnecting()
              : _buildScanView(context, primary, isDark),
    );
  }

  Widget _buildConnecting() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Conectando...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildScanView(BuildContext context, Color primary, bool isDark) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.bluetooth_searching,
                size: 64,
                color: primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Buscar Matrix LED',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0D1E30),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enciende tu ESP32 con la matriz conectada',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _startScan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth),
                  label: Text(_scanning ? 'Escaneando...' : 'Escanear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _scanResults.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _scanning
                          ? 'Buscando dispositivos BLE...'
                          : 'Presiona "Escanear" para buscar\nel ESP32 "Matrix 8x8"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _scanResults.length,
                  itemBuilder: (context, i) {
                    final r = _scanResults[i];
                    final name = r.device.advName;
                    final isMatrix = name == 'Matrix 8x8';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isMatrix ? primary.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                        child: Icon(
                          isMatrix ? Icons.grid_on : Icons.bluetooth,
                          color: isMatrix ? primary : Colors.grey,
                        ),
                      ),
                      title: Text(
                        name.isEmpty ? 'Desconocido' : name,
                        style: TextStyle(
                          fontWeight: isMatrix ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(r.device.remoteId.toString()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        ref.read(matrixConnectionProvider.notifier).connect(r.device);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildControlPanel(
    List<String> animations,
    String? currentAnim,
    int brightness,
    int speed,
    Color primary,
    bool isDark,
  ) {
    final service = ref.read(matrixBleServiceProvider);
    final bg = Theme.of(context).cardColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(primary),
          const SizedBox(height: 20),

          Text('Brillo: $brightness%',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF546E7A))),
          Slider(
            value: brightness.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            activeColor: primary,
            onChanged: (v) {
              ref.read(matrixBrightnessProvider.notifier).state = v.round();
              service.setBrightness(v.round());
            },
          ),
          const SizedBox(height: 4),

          Text('Velocidad: $speed%',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF546E7A))),
          Slider(
            value: speed.toDouble(),
            min: 10,
            max: 300,
            divisions: 29,
            activeColor: primary,
            onChanged: (v) {
              ref.read(matrixSpeedProvider.notifier).state = v.round();
              service.setSpeed(v.round());
            },
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.stop_circle_outlined,
                  label: 'STOP',
                  color: const Color(0xFFFF3B5C),
                  onTap: () {
                    service.stop();
                    ref.read(matrixCurrentAnimProvider.notifier).state = null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.layers_clear,
                  label: 'CLEAR',
                  color: Colors.orange,
                  onTap: () {
                    service.clear();
                    ref.read(matrixCurrentAnimProvider.notifier).state = null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text('Animaciones',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0D1E30))),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: animations.map((name) {
              final isActive = currentAnim == name;
              return GestureDetector(
                onTap: () {
                  service.setAnimation(name);
                  ref.read(matrixCurrentAnimProvider.notifier).state = name;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? primary.withValues(alpha: 0.2)
                        : bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? primary : Colors.grey.withValues(alpha: 0.3),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? primary : (isDark ? Colors.white70 : const Color(0xFF546E7A)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatusBar(Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_connected, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Conectado a Matrix 8x8',
              style: TextStyle(
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled, size: 20),
            color: Colors.green,
            onPressed: () async {
              final service = ref.read(matrixBleServiceProvider);
              service.stop();
              service.clear();
              ref.read(matrixCurrentAnimProvider.notifier).state = null;
              await ref.read(matrixConnectionProvider.notifier).disconnect();
            },
            tooltip: 'Desconectar',
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
