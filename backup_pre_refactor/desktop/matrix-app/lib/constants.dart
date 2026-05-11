const String serviceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';
const String charUuid = '19b10001-e8f2-537e-4f6c-d104768a1214';
const String deviceName = 'Matrix 8x8';

const List<AnimationDef> animations = [
  AnimationDef('Arcoiris', 'A', [0xFF00D97E, 0xFF0066FF]),
  AnimationDef('Ola de colores', 'B', [0xFF29B6F6, 0xFF006994]),
  AnimationDef('Lluvia', 'C', [0xFF42A5F5, 0xFF1E88E5]),
  AnimationDef('Corazon', 'D', [0xFFFF3B5C, 0xFFD50000]),
  AnimationDef('Snake', 'E', [0xFF66BB6A, 0xFF388E3C]),
  AnimationDef('Explosion', 'F', [0xFFFF7043, 0xFFFFB74D]),
  AnimationDef('Espiral', 'G', [0xFF9C6FFF, 0xFF00BCD4]),
  AnimationDef('Fuego / Plasma', 'H', [0xFFFF5722, 0xFFFF9800]),
  AnimationDef('VU Meter', 'I', [0xFF00E676, 0xFF00C853]),
  AnimationDef('Cubo 3D', 'J', [0xFF448AFF, 0xFF304FFE]),
  AnimationDef('Estrella fugaz', 'K', [0xFFFFD740, 0xFFFFAB00]),
  AnimationDef('Torbellino', 'L', [0xFFE040FB, 0xFFAA00FF]),
  AnimationDef('Ondas', 'M', [0xFF00BCD4, 0xFF0097A7]),
  AnimationDef('Ajedrez', 'N', [0xFF78909C, 0xFF607D8B]),
  AnimationDef('Escalera', 'O', [0xFF8D6E63, 0xFF6D4C41]),
  AnimationDef('Pacman', 'P', [0xFFFFEB3B, 0xFFFBC02D]),
  AnimationDef('Game of Life', 'Q', [0xFF00E676, 0xFF69F0AE]),
  AnimationDef('Navidad', 'R', [0xFFF44336, 0xFF2E7D32]),
  AnimationDef('Pixel x Pixel', 'S', [0xFFFF80AB, 0xFFF50057]),
  AnimationDef('Sweep H', 'T', [0xFFB0BEC5, 0xFF90A4AE]),
  AnimationDef('Sweep V', 'U', [0xFFCFD8DC, 0xFFB0BEC5]),
  AnimationDef('Morse', 'V', [0xFFFFD740, 0xFFFFC107]),
  AnimationDef('Caos', 'W', [0xFFFF5252, 0xFFFF1744]),
  AnimationDef('Rebote', 'X', [0xFF00E5FF, 0xFF00B8D4]),
  AnimationDef('Ruleta', 'Y', [0xFFFF6E40, 0xFFFF3D00]),
];

class AnimationDef {
  final String name;
  final String short;
  final List<int> colors;
  const AnimationDef(this.name, this.short, this.colors);
}
