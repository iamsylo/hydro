import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home/home_screen.dart';
import 'onboarding/onboarding_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _brandBlue = Color(0xFF087FEA);
  static const _aqua = Color(0xFF12BFE6);
  static const _background = Color(0xFFF0FAFF);
  static const _ink = Color(0xFF123B63);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydro',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'app',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: _brandBlue,
          secondary: _aqua,
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFDDF5FF),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: _background,
        canvasColor: _background,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        typography: Typography.material2021(
          platform: TargetPlatform.android,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _brandBlue,
            brightness: Brightness.light,
          ),
        ),
        splashFactory: InkSparkle.splashFactory,
        splashColor: _brandBlue.withOpacity(0.12),
        highlightColor: _brandBlue.withOpacity(0.06),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          labelStyle: const TextStyle(color: _ink),
          hintStyle: const TextStyle(color: Color(0xFF6689A8)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFC9EBF8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFC9EBF8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _brandBlue, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: _brandBlue,
            side: const BorderSide(color: Color(0xFF93DDF3)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFD2EDF7)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          actionTextColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _brandBlue,
          linearTrackColor: Color(0xFFCDEFF9),
          circularTrackColor: Color(0xFFCDEFF9),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFD8EFF6),
          thickness: 1,
          space: 1,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _LaunchScreen(),
    );
  }
}

class _LaunchScreen extends StatefulWidget {
  const _LaunchScreen();

  @override
  State<_LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<_LaunchScreen> {
  late final Future<Widget> _launchPage = _getLaunchPage();

  Future<Widget> _getLaunchPage() async {
    final preferences = await SharedPreferences.getInstance();
    final completed = preferences.getBool('onboarding_completed') ?? false;
    if (!completed) return const OnboardingScreen();

    return HomeScreen(
      dailyGoal: preferences.getInt('daily_goal') ?? 2000,
      unit: preferences.getString('water_unit') ?? 'mL',
      remindersEnabled: preferences.getBool('reminders_enabled') ?? true,
      wakeTime: _readTime(preferences.getString('reminder_start'), 7, 0),
      bedTime: _readTime(preferences.getString('reminder_end'), 23, 0),
      reminderInterval: preferences.getDouble('reminder_hours') ?? 2,
    );
  }

  TimeOfDay _readTime(String? value, int fallbackHour, int fallbackMinute) {
    if (value == null) {
      return TimeOfDay(hour: fallbackHour, minute: fallbackMinute);
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return TimeOfDay(
      hour: hour ?? fallbackHour,
      minute: minute ?? fallbackMinute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _launchPage,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
