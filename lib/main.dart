import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const DeofootApp());
}

class DeofootApp extends StatelessWidget {
  const DeofootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deofoot',
      theme: DeofootTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

/// Mengarahkan ke Splash (belum login) atau MainNav (sudah login).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authState,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const SplashScreen();
        return MainNav(userEmail: user.email ?? '');
      },
    );
  }
}

/// Bottom navigation: Beranda | Booking Saya | Profil.
class MainNav extends StatefulWidget {
  final String userEmail;
  const MainNav({super.key, required this.userEmail});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(userEmail: widget.userEmail),
      const MyBookingsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        selectedItemColor: DeofootTheme.primary,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_outlined),
            activeIcon: Icon(Icons.receipt),
            label: 'Booking Saya',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
