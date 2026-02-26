import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/meeting_provider.dart';
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
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)?.appTitle ?? 'Offhand',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              colorSchemeSeed: const Color(0xFF6C63FF),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorSchemeSeed: const Color(0xFF6C63FF),
              useMaterial3: true,
            ),
            locale: settings.locale,
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}
