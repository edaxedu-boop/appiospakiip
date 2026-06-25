import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth/welcome_screen.dart';
import 'services/cart_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await PushNotificationService.initialize();
  await PushNotificationService.requestPermissions();
  
  // Register FCM token on startup if already logged in
  PushNotificationService.registerFcmToken();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CartService())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pakiip',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA7516),
          primary: const Color(0xFFFA7516),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
