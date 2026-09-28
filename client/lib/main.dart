import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/call_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/call_service.dart';
import 'services/signaling_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final signaling = SignalingService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(api)..bootstrap()),
        ChangeNotifierProvider.value(value: signaling),
        ChangeNotifierProvider(create: (_) => CallService(signaling)),
      ],
      child: const WifiCallingApp(),
    ),
  );
}

class WifiCallingApp extends StatelessWidget {
  const WifiCallingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiFi Calling',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E6BE6),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _connectedToken;

  @override
  void initState() {
    super.initState();
    context.read<CallService>().onIncomingCall = (_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const CallScreen()),
      );
    };
  }

  void _syncSocket(AuthService auth) {
    final signaling = context.read<SignalingService>();
    final token = auth.status == AuthStatus.authenticated ? auth.accessToken : null;
    if (token == _connectedToken) return;

    _connectedToken = token;
    if (token == null) {
      signaling.disconnect();
    } else {
      context.read<CallService>().myName = auth.user?.name ?? '';
      signaling.connect(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSocket(auth);
    });

    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.authenticated => const HomeScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }
}
