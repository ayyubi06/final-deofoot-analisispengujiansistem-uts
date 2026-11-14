import 'package:flutter/material.dart';

import '../main.dart';
import '../motion.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';

/// Layar 2 — Login/Register via Firebase Auth.
/// (Fase G §3.9: wordmark Display pitch900 + aksen volt, tombol
/// primer PitchButton, animasi masuk SATU crossfade 250 ms —
/// stagger 900 ms lama dicabut. Transisi login sukses tetap
/// eksplisit seperti sebelumnya.)
class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;
  final AuthService authService;
  final FirestoreService firestoreService;

  AuthScreen({
    super.key,
    this.initialIsLogin = true,
    AuthService? authService,
    FirestoreService? firestoreService,
  }) : authService = authService ?? AuthService(),
       firestoreService = firestoreService ?? FirestoreService();

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late bool _isLogin;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  AuthService get _auth => widget.authService;
  FirestoreService get _fs => widget.firestoreService;
  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    _ctl = AnimationController(vsync: this, duration: PitchMotion.screen);
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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      if (_isLogin) {
        await _auth.signIn(email, pass);
      } else {
        await _auth.register(email, pass);
      }
      final u = _auth.currentUser;
      if (u != null) await _fs.ensureUserDoc(u.uid, u.email ?? email);
      // Navigasi eksplisit ke MainNav (AuthGate tidak lagi di stack).
      if (mounted) _goMain(u?.email ?? email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: DeofootTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _loading = true);
    try {
      final u = await _auth.signInWithGoogle();
      if (u == null) return; // dibatalkan user -> diam, bukan error
      await _fs.ensureUserDoc(u.uid, u.email ?? '');
      if (mounted) _goMain(u.email ?? '');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: DeofootTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goMain(String email) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainNav(userEmail: email)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Masuk' : 'Daftar'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _ctl, curve: PitchMotion.easeOut),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Column(
                  children: [
                    Image.asset(
                      'assets/deofoot-logo.png',
                      width: 84,
                      height: 84,
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Deofoot',
                            style: DeofootTheme.displayStyle.copyWith(
                              fontSize: 24,
                              color: DeofootTheme.pitch900,
                            ),
                          ),
                          TextSpan(
                            text: '.',
                            style: DeofootTheme.displayStyle.copyWith(
                              fontSize: 24,
                              color: DeofootTheme.volt,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Booking futsal semudah itu.',
                      style: TextStyle(
                        fontSize: 14,
                        color: DeofootTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email wajib diisi.';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                      return 'Format email tidak valid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password wajib diisi.';
                    }
                    if (v.length < 6) {
                      return 'Password minimal 6 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_loading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      color: DeofootTheme.pitch700,
                      backgroundColor: DeofootTheme.line,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                PitchButton(
                  label: _loading
                      ? 'Memproses…'
                      : (_isLogin ? 'Masuk' : 'Daftar'),
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? 'Belum punya akun? Daftar'
                        : 'Sudah punya akun? Masuk',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Masuk dengan Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DeofootTheme.pitch700,
                    side: const BorderSide(color: DeofootTheme.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DeofootTheme.radiusButton,
                      ),
                    ),
                    minimumSize: const Size(double.infinity, 52),
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
