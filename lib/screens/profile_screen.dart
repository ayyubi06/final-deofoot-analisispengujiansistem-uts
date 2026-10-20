import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'verify_screen.dart';
import 'report_screen.dart';
import 'field_admin_screen.dart';

/// Layar 7 — Profil: email, keluar, menu Verifikasi (admin).
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: DeofootTheme.primary,
                    child: Icon(Icons.person,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email ?? '-',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: DeofootTheme.primary,
                          ),
                        ),
                        FutureBuilder<bool>(
                          future: fs.isAdmin(user.uid),
                          builder: (context, snap) {
                            final admin = snap.data ?? false;
                            return Text(
                              admin ? 'Admin' : 'Pengguna',
                              style: const TextStyle(
                                  color:
                                      DeofootTheme.textMuted),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  Card(
                    child: ListTile(
                      leading: const Icon(
                          Icons.verified_outlined,
                          color: DeofootTheme.accent),
                      title: const Text('Verifikasi Pembayaran'),
                      subtitle: const Text(
                          'Setujui / tolak booking menunggu'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const VerifyScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                          Icons.stadium_outlined,
                          color: DeofootTheme.accent),
                      title: const Text('Kelola Lapangan'),
                      subtitle: const Text(
                          'Tambah / ubah / nonaktifkan lapangan'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const FieldAdminScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                          Icons.bar_chart_outlined,
                          color: DeofootTheme.accent),
                      title: const Text('Laporan'),
                      subtitle: const Text(
                          'Pendapatan dari booking Disetujui + export PDF'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const ReportScreen()),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout,
                  color: DeofootTheme.danger),
              title: const Text('Keluar',
                  style:
                      TextStyle(color: DeofootTheme.danger)),
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
        ],
      ),
    );
  }
}
