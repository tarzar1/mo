import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';

final bleServiceProvider = Provider<BleService>((ref) => BleService());

final connectionStateProvider = StateNotifierProvider<ConnectionNotifier, BleConnectionState>((ref) {
  final svc = ref.read(bleServiceProvider);
  return ConnectionNotifier(svc);
});

class ConnectionNotifier extends StateNotifier<BleConnectionState> {
  final BleService _svc;
  ConnectionNotifier(this._svc) : super(BleConnectionState.disconnected) {
    _svc.stateStream.listen((s) => state = s);
  }

  Future<void> connect(BluetoothDevice d) => _svc.connect(d);
  Future<void> disconnect() => _svc.disconnect();

  void enterDemoMode() { _demo = true; state = BleConnectionState.connected; }
  void exitDemoMode() {
    _demo = false;
    _svc.disconnect();
    state = BleConnectionState.disconnected;
  }

  bool _demo = false;
  bool get isDemo => _demo;
}

final isDemoModeProvider = Provider<bool>((ref) {
  return ref.read(connectionStateProvider.notifier).isDemo;
});

final brightnessProvider = StateProvider<int>((ref) => 50);
final speedProvider = StateProvider<int>((ref) => 100);
final currentAnimProvider = StateProvider<String?>((ref) => null);
final logProvider = StateProvider<List<String>>((ref) => []);

final logWriterProvider = Provider<void Function(String)>((ref) {
  return (msg) {
    final list = [...ref.read(logProvider), msg];
    if (list.length > 50) list.removeAt(0);
    ref.read(logProvider.notifier).state = list;
  };
});
