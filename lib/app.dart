import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/recording_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';

class VoiceTypeApp extends StatelessWidget {
  const VoiceTypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => RecordingProvider()),
      ],
      child: MaterialApp(
        title: 'VoiceType',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF6C63FF),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}
