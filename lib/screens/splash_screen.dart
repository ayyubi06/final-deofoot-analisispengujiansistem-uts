import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';
import 'auth_screen.dart';

/// Layar 1 — Splash/Welcome: logo + wordmark di atas pitch900.
/// Sekali jalan, tidak bisa back.
/// (Fase G §3.9 + §2: animasi masuk kini SATU crossfade lembut
/// 250 ms easeOut — stagger 900 ms & scale dari 0,7 lama dicabut
/// sesuai aturan gerak Pitch.)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: PitchMotion.screen,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PitchMotion.reducedMotion(context)) {
        _ctl.value = 1;
      } else {
        _ctl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: DeofootTheme.pitch900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _ctl,
                curve: PitchMotion.easeOut,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Image.asset(
                    'assets/deofoot-logo.png',
                    width: 160,
                    height: 160,
                  ),
                  const SizedBox(height: 24),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Deofoot',
                          style: DeofootTheme.displayStyle.copyWith(
                            fontSize: 40,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: '.',
                          style: DeofootTheme.displayStyle.copyWith(
                            fontSize: 40,
                            color: DeofootTheme.volt,
                          ),
                        ),
                      ],
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
                  PitchButton(
                    label: 'Masuk',
                    variant: PitchButtonVariant.volt,
                    onPressed: () => _go(context, isLogin: true),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _go(context, isLogin: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              DeofootTheme.radiusButton),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: const Text('Daftar'),
                    ),
                  ),
                ],
              ),
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
