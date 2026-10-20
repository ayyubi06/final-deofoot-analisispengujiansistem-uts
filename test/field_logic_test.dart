import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/field_logic.dart';

void main() {
  group('Field.fromMap — isActive & scheduleGrid (Fase C)', () {
    test('dokumen lama tanpa field baru → aktif, grid 08–22', () {
      final f = Field.fromMap('l1', {'name': 'Lapangan 1'});
      expect(f.isActive, isTrue);
      expect(f.openHour, 8);
      expect(f.closeHour, 22);
    });

    test('dokumen baru → nilai dari dokumen', () {
      final f = Field.fromMap('p1', {
        'name': 'Padel 1',
        'isActive': false,
        'scheduleGrid': {'openHour': 9, 'closeHour': 21},
      });
      expect(f.isActive, isFalse);
      expect(f.openHour, 9);
      expect(f.closeHour, 21);
    });

    test('toMap ↔ fromMap konsisten', () {
      final f = Field(
        id: 't1',
        name: 'Tenis 1',
        pricePerHour: 150000,
        category: 'Tenis',
        isActive: false,
        openHour: 7,
        closeHour: 23,
      );
      final g = Field.fromMap('t1', f.toMap());
      expect(g.name, 'Tenis 1');
      expect(g.pricePerHour, 150000);
      expect(g.category, 'Tenis');
      expect(g.isActive, isFalse);
      expect(g.openHour, 7);
      expect(g.closeHour, 23);
    });
  });

  group('slotStatuses dengan grid lapangan', () {
    test('grid 09–21 → kunci hanya 9..20', () {
      final m = slotStatuses(const [], 'l1', '2026-10-21',
          openHour: 9, closeHour: 21);
      expect(m.length, 12);
      expect(m.keys.first, 9);
      expect(m.keys.last, 20);
    });

    test('tanpa grid → bawaan 08–22 (14 slot, perilaku lama)', () {
      final m = slotStatuses(const [], 'l1', '2026-10-21');
      expect(m.length, 14);
      expect(m.keys.first, 8);
      expect(m.keys.last, 21);
    });
  });

  group('slug & id unik', () {
    test('slugFieldId menormalkan nama', () {
      expect(slugFieldId('Lapangan Futsal 2!'), 'lapangan-futsal-2');
      expect(slugFieldId('  Mini Soccer — A  '), 'mini-soccer-a');
      expect(slugFieldId('!!!'), 'lapangan');
      expect(slugFieldId(''), 'lapangan');
    });

    test('fieldIdUnik menambah akhiran bila bentrok', () {
      expect(fieldIdUnik('Lapangan 1', {'lain'}), 'lapangan-1');
      expect(fieldIdUnik('Lapangan 1', {'lapangan-1'}), 'lapangan-1-2');
      expect(
        fieldIdUnik('Lapangan 1', {'lapangan-1', 'lapangan-1-2'}),
        'lapangan-1-3',
      );
    });
  });

  group('validasiField & parseHarga', () {
    test('parseHarga membuang pemisah ribuan', () {
      expect(parseHarga('150.000'), 150000);
      expect(parseHarga('Rp250000'), 250000);
      expect(parseHarga('abc'), 0);
    });

    test('nama kosong → error', () {
      expect(
        validasiField(nama: '  ', hargaTeks: '120000', openHour: 8, closeHour: 22),
        isNotNull,
      );
    });

    test('harga 0 / bukan angka → error', () {
      expect(
        validasiField(nama: 'A', hargaTeks: '0', openHour: 8, closeHour: 22),
        isNotNull,
      );
      expect(
        validasiField(nama: 'A', hargaTeks: 'abc', openHour: 8, closeHour: 22),
        isNotNull,
      );
    });

    test('jam buka >= jam tutup → error', () {
      expect(
        validasiField(nama: 'A', hargaTeks: '120000', openHour: 22, closeHour: 8),
        isNotNull,
      );
      expect(
        validasiField(nama: 'A', hargaTeks: '120000', openHour: 8, closeHour: 8),
        isNotNull,
      );
    });

    test('semua valid → null', () {
      expect(
        validasiField(nama: 'Padel 1', hargaTeks: '250.000', openHour: 8, closeHour: 22),
        isNull,
      );
    });
  });
}
