import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/matrix_ble_service.dart';

final matrixBleServiceProvider = Provider<MatrixBleService>((ref) {
  return MatrixBleService();
});

final matrixConnectionProvider = StateNotifierProvider<MatrixConnectionNotifier, MatrixConnectionState>((ref) {
  final service = ref.read(matrixBleServiceProvider);
  return MatrixConnectionNotifier(service);
});

class MatrixConnectionNotifier extends StateNotifier<MatrixConnectionState> {
  final MatrixBleService _service;

  MatrixConnectionNotifier(this._service) : super(MatrixConnectionState.disconnected) {
    _service.connectionStream.listen((state) {
      this.state = state;
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    await _service.connectToDevice(device);
  }

  Future<void> disconnect() async {
    await _service.disconnect();
  }
}

final matrixBrightnessProvider = StateProvider<int>((ref) => 50);

final matrixSpeedProvider = StateProvider<int>((ref) => 100);

final matrixCurrentAnimProvider = StateProvider<String?>((ref) => null);

final matrixAnimationsProvider = Provider<List<String>>((ref) {
  return [
    'Arcoiris',
    'Ola de colores',
    'Lluvia',
    'Corazon',
    'Snake',
    'Explosion',
    'Espiral',
    'Fuego / Plasma',
    'VU Meter',
    'Cubo 3D',
    'Estrella fugaz',
    'Torbellino',
    'Ondas',
    'Ajedrez',
    'Escalera',
    'Pacman',
    'Game of Life',
    'Navidad',
    'Pixel x Pixel',
    'Sweep H',
    'Sweep V',
    'Morse',
    'Caos',
    'Rebote',
    'Ruleta',
  ];
});
