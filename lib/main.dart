import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/server_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ServerCommanderApp());
}

class ServerCommanderApp extends StatelessWidget {
  const ServerCommanderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ServerProvider()..init(),
        ),
      ],
      child: MaterialApp(
        title: 'Server Commander SSH',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}
