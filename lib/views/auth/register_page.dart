import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importáljuk a Firestore-t
import '../../models/user_profile.dart'; // Importáljuk a UserProfile modellt
import '../../services/profile_service.dart'; // Importáljuk a ProfileService-t

/// A regisztrációs oldal widgetje.
///
/// Mostantól nem fogad paramétereket a téma vagy az értesítések állapotának
/// kezeléséhez, mivel ezeket a SettingsProvider kezeli.
class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  final ProfileService _profileService = ProfileService(); // ProfileService példány

  /// Felhasználói fiók regisztrálása a Firebase Authentication segítségével.
  ///
  /// Sikeres regisztráció esetén visszanavigál az előző oldalra (feltételezhetően a LoginPage-re).
  /// Hiba esetén megjeleníti a hibaüzenetet.
  Future<void> _register() async {
    setState(() {
      _errorMessage = null; // Törli az előző hibaüzenetet
    });
    try {
      // Felhasználó létrehozása a Firebase Authentication-ben
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // A felhasználó létrejötte után inicializáljuk a profilját a Firestore-ban
      if (userCredential.user != null) {
        final newUserProfile = UserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email!,
          // Alapértelmezett értékekkel hozzuk létre az új profilt
          displayName: userCredential.user!.email!.split('@')[0], // Email előtti rész
          bio: 'Nincs bemutatkozás.',
          favoriteGame: 'Nincs kedvenc játék.',
          profileImageUrl: null, // Kezdetben nincs profilkép
        );
        await _profileService.createProfile(newUserProfile); // <<< Helyes metódushívás
      }

      // Győződjünk meg róla, hogy a widget még a widgetfában van, mielőtt navigálunk.
      if (mounted) {
        Navigator.pop(context); // Visszanavigál az előző oldalra (LoginPage)
      }
    } on FirebaseAuthException catch (e) {
      // Hiba kezelése a Firebase Authentication hibákra
      setState(() {
        if (e.code == 'weak-password') {
          _errorMessage = 'A megadott jelszó túl gyenge.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'Ez az e-mail cím már használatban van.';
        } else {
          _errorMessage = e.message; // Egyéb hibák üzenetének megjelenítése
        }
      });
    } catch (e) {
      // Általános hibák kezelése
      setState(() {
        _errorMessage = 'Hiba történt: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Regisztráció"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Új fiók létrehozása",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            // Email beviteli mező
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Jelszó beviteli mező
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Jelszó', border: OutlineInputBorder()),
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
            // Fiók létrehozása gomb
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text("Fiók létrehozása"),
            ),
          ],
        ),
      ),
    );
  }
}