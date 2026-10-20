import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FirebaseInitGate());
}

/// Gerbang inisialisasi Firebase: kalau gagal (mis. google-services.json
/// tidak cocok / tidak diproses plugin), tampilkan layar error yang jelas
/// + tombol "Coba lagi". Jangan pernah biarkan layar hitam polos.
class FirebaseInitGate extends StatefulWidget {
  const FirebaseInitGate({super.key});

  @override
  State<FirebaseInitGate> createState() => _FirebaseInitGateState();
}

class _FirebaseInitGateState extends State<FirebaseInitGate> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      return;
    }
    if (!mounted) return;
    setState(() => _ready = true);
    // Expire booking pending yang basi (>30 menit) - fire and forget.
    FirestoreService().expireStalePendings().then((_) {}, onError: (_) {});
    // Notifikasi lokal (Fase A): init plugin + minta izin - fire and forget.
    NotificationService().mintaIzin().then((_) {}, onError: (_) {});
  }

  void _retry() {
    setState(() => _error = null);
    _initFirebase();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const DeofootApp();
    return MaterialApp(
      title: 'Deofoot',
      theme: DeofootTheme.light,
      debugShowCheckedModeBanner: false,
      home: _error == null
          ? const _FirebaseLoading()
          : _FirebaseError(error: _error.toString(), onRetry: _retry),
    );
  }
}

class _FirebaseLoading extends StatelessWidget {
  const _FirebaseLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FirebaseError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _FirebaseError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 72, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Gagal terhubung ke server',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplikasi tidak bisa tersambung ke Firebase. Periksa koneksi internet, lalu coba lagi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
/// Stream authState dibuat SEKALI di initState agar tidak resubscribe
/// setiap rebuild (bug: login tidak masuk dashboard tanpa buka-ulang app).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authState;

  @override
  void initState() {
    super.initState();
    _authState = AuthService().authState;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authState,
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

class _MainNavState extends State<MainNav> with WidgetsBindingObserver {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ketuk notifikasi → buka tab Booking Saya.
    NotificationService.onTap = (_) {
      if (mounted) setState(() => _idx = 1);
    };
    // Rekonsiliasi pengingat lokal setiap aplikasi dibuka (Fase A).
    _rekonsiliasi();
  }

  void _rekonsiliasi() {
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      NotificationService().rekonsiliasiUntukUser(uid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _rekonsiliasi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onTap = null;
    super.dispose();
  }

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
