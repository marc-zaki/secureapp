import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. Import your providers
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/p2p_provider.dart';

// 2. Import your screens
import 'screens/login_screen.dart'; // Or wherever your LoginScreen is
import 'screens/chat_screen.dart';  // Or wherever your ChatScreen is

// 3. CRITICAL IMPORT: Import the Notification Service
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Initialize the Notification Service
  // (This caused the error before because the import was missing)
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => P2PProvider()),
      ],
      child: MaterialApp(
        title: 'Secure Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        // If your auth provider has a variable 'isLoggedIn', you can switch screens here
        // For now, we usually start at LoginScreen
        home: const LoginScreen(),
      ),
    );
  }
}