import 'package:flutter/material.dart';
import '../theme.dart';
import 'auth_screen.dart';

/// Layar 1 — Splash/Welcome. Sekali jalan, tidak bisa back.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: DeofootTheme.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(Icons.sports_soccer,
                    size: 96, color: DeofootTheme.accent),
                const SizedBox(height: 24),
                const Text(
                  'Deofoot',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Booking futsal semudah itu.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _go(context, isLogin: true),
                  child: const Text('Masuk'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _go(context, isLogin: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Daftar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, {required bool isLogin}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthScreen(initialIsLogin: isLogin),
      ),
    );
  }
}
