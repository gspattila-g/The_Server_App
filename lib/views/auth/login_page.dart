import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart'; // Fontos: a RegisterPage pontos útvonala

/// A bejelentkező oldal widgetje.
///
/// Mostantól nem fogad paramétereket a téma vagy az értesítések állapotának
/// kezeléséhez, mivel ezeket a SettingsProvider kezeli.
class LoginPage extends StatefulWidget {
  // A téma és értesítések paraméterei már nem szükségesek itt,
  // mivel a SettingsProvider kezeli azokat globálisan.
  // final bool isDarkMode;
  // final Function(bool) onThemeChanged;
  // final bool notificationsEnabled;
  // final Function(bool) onNotificationsChanged;

  const LoginPage({
    super.key,
    // Ezeket a "required" paramétereket is eltávolítjuk a konstruktorból.
    // required this.isDarkMode,
    // required this.onThemeChanged,
    // required this.notificationsEnabled,
    // required this.onNotificationsChanged,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  /// Bejelentkezési kísérlet a Firebase Authentication segítségével.
  ///
  /// Sikeres bejelentkezés esetén a StreamBuilder a main.dart-ban
  /// automatikusan átirányítja a felhasználót a WelcomePage-re.
  /// Hiba esetén megjeleníti a hibaüzenetet.
  Future<void> _signIn() async {
    setState(() {
      _errorMessage = null; // Törli az előző hibaüzenetet
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Sikeres bejelentkezés esetén a StreamBuilder a main.dart-ban figyeli a FirebaseAuth.instance.authStateChanges() változását,
      // így automatikusan átirányítja a felhasználót a WelcomePage-re.
      // Nincs szükség explicit Navigator.pushReplacement hívásra itt.
    } on FirebaseAuthException catch (e) {
      setState(() {
        // Hibaüzenet beállítása a Firebase kivétel alapján.
        _errorMessage = "Hiba: ${e.message}";
      });
    } catch (e) {
      // Általános hiba kezelése.
      setState(() {
        _errorMessage = "Ismeretlen hiba történt: $e";
      });
    }
  }

  @override
  void dispose() {
    // Fontos, hogy a TextEditingController-eket felszabadítsuk,
    // amikor a widget elhagyja a widgetfát, hogy elkerüljük a memóriaszivárgást.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bejelentkezés")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "GamerKözösség",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Email beviteli mező
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Jelszó beviteli mező
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Jelszó",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Hibaüzenet megjelenítése, ha van
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            // Bejelentkezés gomb
            ElevatedButton(
              onPressed: _signIn,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text("Bejelentkezés"),
            ),
            // Regisztráció gomb
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // A RegisterPage-nek már nem adjuk át a téma/értesítés paramétereket.
                    // Feltehetően a RegisterPage is frissítésre kerül, hogy ne várja ezeket.
                    builder: (_) => const RegisterPage(),
                  ),
                );
              },
              child: const Text("Nincs fiókod? Regisztrálj itt."),
            ),
          ],
        ),
      ),
    );
  }
}
