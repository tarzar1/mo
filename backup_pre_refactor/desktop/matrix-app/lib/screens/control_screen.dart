import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/matrix_provider.dart';
import '../widgets/connection_status.dart';
import '../widgets/sliders.dart';
import '../widgets/anim_grid.dart';

class ControlScreen extends ConsumerWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessProvider);
    final speed = ref.watch(speedProvider);
    final current = ref.watch(currentAnimProvider);
    final isDemo = ref.watch(isDemoModeProvider);
    final svc = ref.read(bleServiceProvider);
    final connNotifier = ref.read(connectionStateProvider.notifier);

    return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const ConnectionStatusWidget(),
              const SizedBox(height: 20),

              MatrixSlider(
                label: 'Brillo',
                suffix: '%',
                value: brightness,
                min: 1,
                max: 100,
                divisions: 99,
                colors: const [Color(0xFF00D97E), Color(0xFF0066FF)],
                onChanged: (v) {
                  ref.read(brightnessProvider.notifier).state = v;
                  svc.brightness(v);
                },
              ),
              const SizedBox(height: 8),

              MatrixSlider(
                label: 'Velocidad',
                suffix: '%',
                value: speed,
                min: 10,
                max: 300,
                divisions: 29,
                colors: const [Color(0xFFFFB800), Color(0xFFFF7043)],
                onChanged: (v) {
                  ref.read(speedProvider.notifier).state = v;
                  svc.speed(v);
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _Btn(
                      icon: Icons.stop_circle_outlined,
                      label: 'STOP',
                      color: const Color(0xFFFF3B5C),
                      onTap: () {
                        svc.stop();
                        ref.read(currentAnimProvider.notifier).state = null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Btn(
                      icon: Icons.layers_clear,
                      label: 'CLEAR',
                      color: const Color(0xFFFFB800),
                      onTap: () {
                        svc.clear();
                        ref.read(currentAnimProvider.notifier).state = null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const AnimationGrid(),
              const SizedBox(height: 16),

              if (current != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D97E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00D97E).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle,
                          color: Color(0xFF00D97E), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Reproduciendo: $current',
                            style: const TextStyle(
                                color: Color(0xFF00D97E),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (isDemo)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => connNotifier.exitDemoMode(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Cerrar Demo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF3B5C),
                      side: const BorderSide(color: Color(0xFFFF3B5C)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Btn({
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
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
