import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/ble_service.dart';
import 'providers/matrix_provider.dart';
import 'screens/scan_screen.dart';
import 'screens/control_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF061220),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: MatrixApp()));
}

class MatrixApp extends StatefulWidget {
  const MatrixApp({super.key});

  @override
  State<MatrixApp> createState() => _MatrixAppState();
}

class _MatrixAppState extends State<MatrixApp> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matrix LED 8x8',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D97E),
          secondary: Color(0xFF0066FF),
          surface: Color(0xFF0D1E30),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1E30),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MatrixShell(),
    );
  }
}

class MatrixShell extends ConsumerWidget {
  const MatrixShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionStateProvider);
    final svc = ref.read(bleServiceProvider);

    return PopScope(
      canPop: state != BleConnectionState.connected,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state == BleConnectionState.connected) {
          svc.stop();
          svc.clear();
          svc.disconnect();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: state == BleConnectionState.connected
              ? const ControlScreen(key: ValueKey('control'))
              : const ScanScreen(key: ValueKey('scan')),
        ),
      ),
    );
  }
}
