import 'package:flutter/material.dart';

class MatrixSlider extends StatelessWidget {
  final String label;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final List<Color> colors;
  final ValueChanged<int> onChanged;

  const MatrixSlider({
    super.key,
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const Spacer(),
            Text('$value$suffix',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            activeTrackColor: colors[0],
            inactiveTrackColor: colors[0].withValues(alpha: 0.15),
            thumbColor: colors[1],
            overlayColor: colors[1].withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    ),
    );
  }
}
