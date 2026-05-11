import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../providers/matrix_provider.dart';

class AnimationGrid extends ConsumerWidget {
  const AnimationGrid({super.key});

  static const _columns = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentAnimProvider);
    final svc = ref.read(bleServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Animaciones (25)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            childAspectRatio: 2.4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: animations.length,
          itemBuilder: (context, i) {
            final a = animations[i];
            final active = current == a.name;
            return _AnimCell(
              name: a.name,
              color: Color(a.colors[0]),
              active: active,
              onTap: () {
                svc.anim(a.name);
                ref.read(currentAnimProvider.notifier).state = a.name;
              },
            );
          },
        ),
      ],
    );
  }
}

class _AnimCell extends StatelessWidget {
  final String name;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _AnimCell({
    required this.name,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color : const Color(0xFF1A2A3A),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : const Color(0xFF2A3A4A),
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? Icons.play_circle_filled : Icons.play_circle_outline,
                color: active ? Colors.white : color.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.white : const Color(0xFF8A9AAA),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
