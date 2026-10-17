import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Layar 2 — Login/Register via Firebase Auth.
/// Animasi masuk staggered (logo/tagline → form → tombol), animasi bawaan
/// Flutter saja. Transisi login sukses tetap eksplisit (tidak diubah).
class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;
  const AuthScreen({super.key, this.initialIsLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late bool _isLogin;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  final _fs = FirestoreService();
  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _ctl;
  late final Animation<double> _headAnim; // logo + tagline
  late final Animation<double> _formAnim; // form
  late final Animation<double> _btnAnim; // tombol

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctl,
          curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
    );
    _formAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctl,
          curve: const Interval(0.25, 0.65, curve: Curves.easeOut)),
    );
    _btnAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctl,
          curve: const Interval(0.55, 1.0, curve: Curves.easeOut)),
    );
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Bungkus widget dengan fade + slide up mengikuti [anim].
  Widget _staggered(Animation<double> anim, Widget child) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(anim);
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(position: slide, child: child),
    );
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
          SnackBar(content: Text(e.toString()), backgroundColor: DeofootTheme.danger),
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
              backgroundColor: DeofootTheme.danger),
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _staggered(
                _headAnim,
                Column(
                  children: [
                    Image.asset(
                      'assets/deofoot-logo.png',
                      width: 84,
                      height: 84,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Booking futsal semudah itu.',
                      style: TextStyle(
                        fontSize: 14,
                        color: DeofootTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _staggered(
                _formAnim,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                            .hasMatch(v.trim())) {
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
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _staggered(
                _btnAnim,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isLogin ? 'Masuk' : 'Daftar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin
                          ? 'Belum punya akun? Daftar'
                          : 'Sudah punya akun? Masuk'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _signInGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Masuk dengan Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
