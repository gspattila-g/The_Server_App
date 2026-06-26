import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'views/auth/login_page.dart';
import 'views/welcome/welcome_page.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    // Definiáljuk a színsémákat a világos és sötét módhoz
    // Kékes, gameres vibe - Primary: Vibráló kék, Secondary: Neon zöld/cián
    final ColorScheme lightColorScheme = ColorScheme.light(
      primary: Colors.blue[700]!, // Sötétebb, vibráló kék
      primaryContainer: Colors.blue[200], // Világosabb kék konténerhez
      secondary: Colors.cyan[400]!, // Neon zöldes-kékes másodlagos szín
      secondaryContainer: Colors.cyan[100], // Világosabb cián konténerhez
      background: Colors.grey[100]!, // Nagyon világos szürke háttér
      surface: Colors.white, // Kártyák, felületek
      onPrimary: Colors.white, // Szöveg a primary színen
      onSecondary: Colors.black, // Szöveg a secondary színen
      onBackground: Colors.black, // Szöveg a háttéren
      onSurface: Colors.black, // Szöveg a surface-en
      error: Colors.red[700]!,
      onError: Colors.white,
      brightness: Brightness.light,
    );

    final ColorScheme darkColorScheme = ColorScheme.dark(
      primary: Colors.blue[400]!, // Kicsit világosabb kék sötét módban
      primaryContainer: Colors.blue[700],
      secondary: Colors.cyan[200]!, // Világosabb neon zöldes-kékes
      secondaryContainer: Colors.cyan[500],
      background: Colors.grey[900]!, // Sötét szürke háttér
      surface: Colors.grey[850]!, // Kontrasztosabb surface szín a kártyákhoz
      onPrimary: Colors.black, // Szöveg a primary színen (pl. app bar cím)
      onSecondary: Colors.black, // Szöveg a secondary színen
      onBackground: Colors.white, // Szöveg a háttéren
      onSurface: Colors.white, // Szöveg a surface-en (kártyák)
      error: Colors.red[400]!,
      onError: Colors.black,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Gamer App',
      debugShowCheckedModeBanner: false,
      // Világos téma beállításai
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: lightColorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.3),
        ),
        cardTheme: CardThemeData(
          color: lightColorScheme.surface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightColorScheme.primary,
            foregroundColor: lightColorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: lightColorScheme.primary,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightColorScheme.surfaceVariant.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightColorScheme.outline.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          labelStyle: TextStyle(color: lightColorScheme.onSurface),
          hintStyle: TextStyle(color: lightColorScheme.onSurface.withOpacity(0.6)),
        ),
        // Tipográfia
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 96, fontWeight: FontWeight.w300),
          displayMedium: TextStyle(fontSize: 60, fontWeight: FontWeight.w400),
          displaySmall: TextStyle(fontSize: 48, fontWeight: FontWeight.w400),
          headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w400),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        ).apply(
          fontFamily: 'Inter',
        ),
      ),
      // Sötét téma beállításai
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: darkColorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.primary,
          foregroundColor: darkColorScheme.onPrimary,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.7),
        ),
        cardTheme: CardThemeData(
          color: darkColorScheme.surface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkColorScheme.primary,
            foregroundColor: darkColorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkColorScheme.primary,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkColorScheme.surfaceVariant.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkColorScheme.outline.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkColorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          labelStyle: TextStyle(color: darkColorScheme.onSurface),
          hintStyle: TextStyle(color: darkColorScheme.onSurface.withOpacity(0.6)),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 96, fontWeight: FontWeight.w300),
          displayMedium: TextStyle(fontSize: 60, fontWeight: FontWeight.w400),
          displaySmall: TextStyle(fontSize: 48, fontWeight: FontWeight.w400),
          headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w400),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        ).apply(
          fontFamily: 'Inter',
        ),
      ),
      themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData && snapshot.data != null) {
          return WelcomePage(
            email: snapshot.data!.email ?? '',
          );
        }
        return const LoginPage();
      },
    );
  }
}
