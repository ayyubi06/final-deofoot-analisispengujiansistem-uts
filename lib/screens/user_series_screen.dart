import 'package:flutter/material.dart';

import '../booking_logic.dart';
import '../calendar_logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/pitch_components.dart';

/// Rincian seri dari sisi PENGGUNA (Fase G §3.6): daftar pertemuan
/// satu seri langganan milik user — tanggal, jam, status. Hanya
/// baca: aksi batal tetap di kartu Booking Saya seperti biasa.
/// Stream diteruskan pemanggil (watchBookingsBySeries) supaya
/// layar ini murni presentasi.
class UserSeriesScreen extends StatelessWidget {
  final String fieldName;
  final Stream<List<Booking>> meetingsStream;
  const UserSeriesScreen({
    super.key,
    required this.fieldName,
    required this.meetingsStream,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rincian Langganan')),
      body: StreamBuilder<List<Booking>>(
        stream: meetingsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                PitchSkeletonCard(),
                SizedBox(height: 16),
                PitchSkeletonCard(),
              ],
            );
          }
          final meetings = [...(snap.data ?? [])]
            ..sort((a, b) {
              final byDate = a.date.compareTo(b.date);
              return byDate != 0
                  ? byDate
                  : a.startMinutes.compareTo(b.startMinutes);
            });
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      fieldName,
                      style: DeofootTheme.titleStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          DeofootTheme.volt.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.repeat,
                            size: 12, color: DeofootTheme.pitch700),
                        const SizedBox(width: 4),
                        Text(
                          'Langganan',
                          style: DeofootTheme.captionStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: DeofootTheme.pitch700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${meetings.length} pertemuan',
                style: DeofootTheme.captionStyle,
              ),
              const SizedBox(height: 16),
              if (meetings.isEmpty)
                Text(
                  'Belum ada pertemuan.',
                  style: DeofootTheme.bodyStyle
                      .copyWith(color: DeofootTheme.ink60),
                ),
              for (final b in meetings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PitchCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                indoFullDate(DateTime.parse(b.date)),
                                style: DeofootTheme.bodyStyle.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${b.startTime}–${b.endTime} • ${fmtRupiah(b.totalPrice)}',
                                style: DeofootTheme.captionStyle
                                    .copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        _statusChip(b.status),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Widget _statusChip(String status) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: DeofootTheme.statusColor(status).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      DeofootTheme.statusLabel(status),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: DeofootTheme.statusColor(status),
      ),
    ),
  );
}
