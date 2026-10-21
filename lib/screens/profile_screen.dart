import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';
import 'field_admin_screen.dart';
import 'report_screen.dart';
import 'verify_screen.dart';

/// Versi aplikasi yang tampil di Profil (§3.9) — cermin persis
/// versi di pubspec.yaml (1.5.0+7); tidak ada plugin package-info
/// di aplikasi ini, jadi labelnya konstanta yang dijaga selaras
/// setiap rilis.
const appVersionLabel = '1.5.0+7';

/// Layar 7 — Profil: email, keluar, menu Verifikasi (admin).
/// (Fase G §3.9: kartu Pitch, versi aplikasi tampil di bawah.)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final fs = FirestoreService();
    final user = auth.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PitchCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: DeofootTheme.pitch700,
                  child: Icon(Icons.person,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email ?? '-',
                        style: DeofootTheme.bodyStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: DeofootTheme.pitch900,
                        ),
                      ),
                      FutureBuilder<bool>(
                        future: fs.isAdmin(user.uid),
                        builder: (context, snap) {
                          final admin = snap.data ?? false;
                          return Text(
                            admin ? 'Admin' : 'Pengguna',
                            style: const TextStyle(
                                color: DeofootTheme.textMuted),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Menu admin — hanya untuk admin.
          FutureBuilder<bool>(
            future: fs.isAdmin(user.uid),
            builder: (context, snap) {
              if (!(snap.data ?? false)) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  _menuCard(
                    context,
                    icon: Icons.verified_outlined,
                    title: 'Verifikasi Pembayaran',
                    subtitle: 'Setujui / tolak booking menunggu',
                    screen: const VerifyScreen(),
                  ),
                  const SizedBox(height: 12),
                  _menuCard(
                    context,
                    icon: Icons.stadium_outlined,
                    title: 'Kelola Lapangan',
                    subtitle: 'Tambah / ubah / nonaktifkan lapangan',
                    screen: const FieldAdminScreen(),
                  ),
                  const SizedBox(height: 12),
                  _menuCard(
                    context,
                    icon: Icons.bar_chart_outlined,
                    title: 'Laporan',
                    subtitle:
                        'Pendapatan dari booking Disetujui + export PDF',
                    screen: const ReportScreen(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          PitchCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout,
                  color: DeofootTheme.danger),
              title: const Text('Keluar',
                  style: TextStyle(color: DeofootTheme.danger)),
              onTap: () async {
                await auth.signOut();
                // Navigasi eksplisit ke AuthGate (-> Splash), karena
                // AuthGate tidak lagi di stack pasca-fix login.
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (_) => false,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Deofoot versi $appVersionLabel',
            textAlign: TextAlign.center,
            style: DeofootTheme.captionStyle,
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return PitchCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: DeofootTheme.pitch700),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right,
            color: DeofootTheme.ink60),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => screen),
        ),
      ),
    );
  }
}
