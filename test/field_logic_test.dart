import 'package:flutter_test/flutter_test.dart';
import 'package:deofoot/models.dart';
import 'package:deofoot/booking_logic.dart';
import 'package:deofoot/field_logic.dart';

void main() {
  group('Field.fromMap — isActive (Fase C)', () {
    test('dokumen lama tanpa isActive → dianggap aktif', () {
      final f = Field.fromMap('l1', {'name': 'Lapangan 1'});
      expect(f.isActive, isTrue);
    });

    test('dokumen baru → nilai isActive dari dokumen', () {
      final f = Field.fromMap('p1', {'name': 'Padel 1', 'isActive': false});
      expect(f.isActive, isFalse);
    });

    test('toMap ↔ fromMap konsisten; tidak ada scheduleGrid (rework T5)',
        () {
      final f = Field(
        id: 't1',
        name: 'Tenis 1',
        pricePerHour: 150000,
        category: 'Tenis',
        isActive: false,
      );
      final map = f.toMap();
      expect(map.containsKey('scheduleGrid'), isFalse);
      final g = Field.fromMap('t1', map);
      expect(g.name, 'Tenis 1');
      expect(g.pricePerHour, 150000);
      expect(g.category, 'Tenis');
      expect(g.isActive, isFalse);
    });

    test('dokumen lama yang masih punya scheduleGrid → diabaikan (T5)', () {
      final f = Field.fromMap('p1', {
        'name': 'Padel 1',
        'scheduleGrid': {'openHour': 9, 'closeHour': 21},
      });
      expect(f.name, 'Padel 1');
      // Grid selalu global 08–22 apa pun isi dokumen.
      final m = slotStatuses(const [], 'p1', '2026-10-21');
      expect(m.length, 14);
    });
  });

  group('slotStatuses — grid global (rework T5)', () {
    test('selalu 14 slot 08–22', () {
      final m = slotStatuses(const [], 'l1', '2026-10-21');
      expect(m.length, 14);
      expect(m.keys.first, 8);
      expect(m.keys.last, 21);
      expect(openHour, 8);
      expect(closeHour, 22);
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
      expect(validasiField(nama: '  ', hargaTeks: '120000'), isNotNull);
    });

    test('harga 0 / bukan angka → error', () {
      expect(validasiField(nama: 'A', hargaTeks: '0'), isNotNull);
      expect(validasiField(nama: 'A', hargaTeks: 'abc'), isNotNull);
    });

    test('semua valid → null', () {
      expect(validasiField(nama: 'Padel 1', hargaTeks: '250.000'), isNull);
    });
  });

  group('inisialNama (placeholder foto C2)', () {
    test('dua kata → dua huruf pertama', () {
      expect(inisialNama('Futsal L1'), 'FL');
      expect(inisialNama('Padel Court A'), 'PC');
      expect(inisialNama('mini soccer'), 'MS');
    });

    test('satu kata → satu huruf; kosong → ?', () {
      expect(inisialNama('Padel'), 'P');
      expect(inisialNama('   '), '?');
    });
  });
}
