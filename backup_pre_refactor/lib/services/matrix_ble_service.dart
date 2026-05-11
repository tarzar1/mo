import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MatrixBleService {
  static const String _serviceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String _charUuid = '19b10001-e8f2-537e-4f6c-d104768a1214';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final _connectionController = StreamController<MatrixConnectionState>.broadcast();
  Stream<MatrixConnectionState> get connectionStream => _connectionController.stream;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;

  Future<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 10)}) async {
    final results = <ScanResult>[];

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first;

    final completer = Completer<List<ScanResult>>();

    _scanSubscription = FlutterBluePlus.scanResults.listen((list) {
      results.clear();
      results.addAll(list);
    });

    await FlutterBluePlus.startScan(
      timeout: timeout,
    );

    await Future.delayed(timeout);
    await FlutterBluePlus.stopScan();

    completer.complete(results
        .where((r) => r.device.advName.isNotEmpty)
        .toList());

    return completer.future;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    await disconnect();

    _device = device;
    _connectionController.add(MatrixConnectionState.connecting);

    try {
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectionController.add(MatrixConnectionState.disconnected);
        }
      });

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == _serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == _charUuid) {
              _characteristic = char;
              _connectionController.add(MatrixConnectionState.connected);
              return true;
            }
          }
        }
      }

      await device.disconnect();
      _connectionController.add(MatrixConnectionState.disconnected);
      return false;
    } catch (e) {
      _connectionController.add(MatrixConnectionState.disconnected);
      return false;
    }
  }

  Future<void> disconnect() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (_device != null && _device!.isConnected) {
      await _device!.disconnect();
    }
    _device = null;
    _characteristic = null;
    _connectionController.add(MatrixConnectionState.disconnected);
  }

  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (_characteristic == null) return;

    final json = jsonEncode(command);
    final data = utf8.encode(json);

    if (data.length <= 20) {
      await _characteristic!.write(data, withoutResponse: true);
    } else {
      for (var i = 0; i < data.length; i += 20) {
        final chunk = data.sublist(i, i + 20 > data.length ? data.length : i + 20);
        await _characteristic!.write(chunk, withoutResponse: true);
      }
    }
  }

  void setAnimation(String name) => sendCommand({'t': 'anim', 'n': name});
  void setBrightness(int v) => sendCommand({'t': 'bri', 'v': v.clamp(1, 100)});
  void setSpeed(int v) => sendCommand({'t': 'spd', 'v': v.clamp(10, 300)});
  void stop() => sendCommand({'t': 'stop'});
  void clear() => sendCommand({'t': 'clear'});
  void customPattern(List<List<int>> pixels) => sendCommand({'t': 'custom', 'd': pixels});

  void dispose() {
    disconnect();
    _connectionController.close();
  }
}

enum MatrixConnectionState { disconnected, connecting, connected }
