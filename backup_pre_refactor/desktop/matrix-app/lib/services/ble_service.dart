import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants.dart';

class BleService {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  final _stateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  StreamSubscription? _connSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  void _setState(BleConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void _log(String msg) => _logController.add(msg);

  Future<List<ScanResult>> scan({int seconds = 10}) async {
    final all = <ScanResult>[];

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first;

    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      all.clear();
      all.addAll(list);
    });

    await FlutterBluePlus.startScan(timeout: Duration(seconds: seconds));
    await Future.delayed(Duration(seconds: seconds));
    await FlutterBluePlus.stopScan();

    return all.where((r) => r.device.advName == deviceName).toList();
  }

  Future<bool> connect(BluetoothDevice d) async {
    await disconnect();

    _log('Conectando a ${d.advName}...');
    _setState(BleConnectionState.connecting);
    device = d;

    try {
      _connSub = d.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _log('Desconectado');
          _setState(BleConnectionState.disconnected);
        }
      });

      await d.connect(timeout: const Duration(seconds: 15), autoConnect: false);

      final services = await d.discoverServices();
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == serviceUuid) {
          for (final ch in svc.characteristics) {
            if (ch.uuid.toString().toLowerCase() == charUuid) {
              characteristic = ch;
              _log('Conectado! Listo para controllar.');
              _setState(BleConnectionState.connected);
              return true;
            }
          }
        }
      }

      _log('No se encontro el servicio Matrix 8x8');
      await d.disconnect();
      _setState(BleConnectionState.disconnected);
      return false;
    } catch (e) {
      _log('Error: $e');
      _setState(BleConnectionState.disconnected);
      return false;
    }
  }

  Future<void> disconnect() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await _connSub?.cancel();
    _connSub = null;
    if (device != null && device!.isConnected) {
      await device!.disconnect();
    }
    device = null;
    characteristic = null;
    _setState(BleConnectionState.disconnected);
  }

  Future<void> _send(Map<String, dynamic> cmd) async {
    if (characteristic == null) return;
    final json = jsonEncode(cmd);
    final data = utf8.encode(json);
    const mtu = 20;
    for (var i = 0; i < data.length; i += mtu) {
      final end = i + mtu > data.length ? data.length : i + mtu;
      await characteristic!.write(data.sublist(i, end), withoutResponse: true);
    }
  }

  void anim(String name) {
    _log('Anim: $name');
    _send({'t': 'anim', 'n': name});
  }

  void brightness(int v) {
    _log('Brillo: $v%');
    _send({'t': 'bri', 'v': v.clamp(1, 100)});
  }

  void speed(int v) {
    _log('Velocidad: $v%');
    _send({'t': 'spd', 'v': v.clamp(10, 300)});
  }

  void stop() {
    _log('STOP');
    _send({'t': 'stop'});
  }

  void clear() {
    _log('CLEAR');
    _send({'t': 'clear'});
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _logController.close();
  }
}

enum BleConnectionState { disconnected, connecting, connected }
