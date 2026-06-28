import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import '../welcome/welcome_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _subtitleFadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );
    _subtitleFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2600)),
      FirebaseAuth.instance.authStateChanges().first,
    ]);
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => user != null
            ? WelcomePage(email: user.email ?? '')
            : const LoginPage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D0D0D), Color(0xFF1a1a1a), Color(0xFF0D0D0D)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 160,
                      height: 160,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: const Text(
                    'The Server',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _subtitleFadeAnim,
                  child: Text(
                    'Játssz. Kapcsolódj. Oszd meg.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _subtitleFadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
