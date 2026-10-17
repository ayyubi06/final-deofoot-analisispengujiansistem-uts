import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../booking_logic.dart';
import '../services/firestore_service.dart';
import 'schedule_screen.dart';

/// Layar 3 — Beranda: sapaan + 3 kartu lapangan.
class HomeScreen extends StatelessWidget {
  final String userEmail;
  const HomeScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final today = fmtDate(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Deofoot')),
      body: StreamBuilder<List<Field>>(
        stream: fs.watchFields(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fields = snap.data ?? [];
          if (fields.isEmpty) {
            return const Center(
              child: Text('Data lapangan belum tersedia.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Halo, ${userEmail.split('@').first}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: DeofootTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih lapangan untuk booking.',
                style: TextStyle(color: DeofootTheme.textMuted),
              ),
              const SizedBox(height: 16),
              for (final f in fields)
                _FieldCard(field: f, date: today),
            ],
          );
        },
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final Field field;
  final String date;
  const _FieldCard({required this.field, required this.date});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScheduleScreen(field: field),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DeofootTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_soccer,
                    size: 40, color: DeofootTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DeofootTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtRupiah(field.pricePerHour)}/jam',
                      style: const TextStyle(
                        color: DeofootTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Booking>>(
                      stream: fs.watchBookings(field.id, date),
                      builder: (context, snap) {
                        final bookings = snap.data ?? [];
                        final statuses =
                            slotStatuses(bookings, field.id, date);
                        final free = statuses.values
                            .where((s) => s == SlotStatus.free)
                            .length;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: DeofootTheme.available.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$free slot bebas hari ini',
                            style: const TextStyle(
                              fontSize: 12,
                              color: DeofootTheme.available,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: DeofootTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
