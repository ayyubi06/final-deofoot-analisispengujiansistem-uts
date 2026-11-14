import 'package:deofoot/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  setUpAll(TestFixtures.registerFallbackValues);

  group('AuthService with MockFirebaseAuth', () {
    test('exposes current user and auth state', () async {
      final auth = TestFixtures.auth();
      final service = AuthService(auth: auth);
      expect(service.currentUser?.uid, 'user-1');
      await expectLater(service.authState, emits(isA<User>()));
    });

    test('signs in, registers, and signs out', () async {
      final auth = TestFixtures.auth();
      final service = AuthService(auth: auth);
      await service.signIn('user@example.test', 'password');
      expect(auth.currentUser?.email, 'user@example.test');

      await service.register('new@example.test', 'password');
      expect(auth.currentUser?.email, 'new@example.test');

      await service.signOut();
      expect(auth.currentUser, isNull);
    });
  });

  group('Firebase Auth error messages', () {
    const signInMessages = {
      'invalid-email': 'Format email tidak valid.',
      'user-not-found': 'Akun tidak ditemukan. Silakan daftar dulu.',
      'wrong-password': 'Email atau password salah.',
      'invalid-credential': 'Email atau password salah.',
      'network-request-failed': 'Tidak ada koneksi internet.',
      'too-many-requests': 'Terlalu banyak percobaan. Coba lagi nanti.',
    };

    for (final entry in signInMessages.entries) {
      test('maps sign-in error ${entry.key}', () async {
        final auth = TestFixtures.authThatFails(
          code: entry.key,
          register: false,
        );
        await expectLater(
          AuthService(auth: auth).signIn('user@example.test', 'password'),
          throwsA(entry.value),
        );
      });
    }

    test('maps registration-specific errors', () async {
      final existing = TestFixtures.authThatFails(
        code: 'email-already-in-use',
        register: true,
      );
      final weak = TestFixtures.authThatFails(
        code: 'weak-password',
        register: true,
      );
      await expectLater(
        AuthService(auth: existing).register('used@example.test', 'password'),
        throwsA('Email sudah terdaftar. Silakan masuk.'),
      );
      await expectLater(
        AuthService(auth: weak).register('user@example.test', '123'),
        throwsA('Password terlalu lemah (minimal 6 karakter).'),
      );
    });

    test('uses the server message for unrecognized errors', () async {
      final auth = TestFixtures.authThatFails(
        code: 'unexpected-code',
        message: 'Unexpected failure',
        register: false,
      );
      await expectLater(
        AuthService(auth: auth).signIn('user@example.test', 'password'),
        throwsA('Gagal: Unexpected failure'),
      );
    });

    test(
      'falls back to the error code when server message is absent',
      () async {
        final auth = TestFixtures.authThatFails(
          code: 'unexpected-code',
          register: true,
        );
        await expectLater(
          AuthService(auth: auth).register('user@example.test', 'password'),
          throwsA('Gagal: unexpected-code'),
        );
      },
    );

    test('returns null when the user cancels Google sign-in', () async {
      TestFixtures.installGoogleSignInMock(cancelled: true);
      addTearDown(TestFixtures.removeGoogleSignInMock);

      expect(
        await AuthService(auth: TestFixtures.auth()).signInWithGoogle(),
        isNull,
      );
    });

    test(
      'signs in with Google credentials and returns the Firebase user',
      () async {
        TestFixtures.installGoogleSignInMock();
        addTearDown(TestFixtures.removeGoogleSignInMock);
        final auth = TestFixtures.auth();

        final user = await AuthService(auth: auth).signInWithGoogle();

        expect(user?.uid, 'user-1');
        expect(auth.currentUser?.email, 'user@example.test');
      },
    );

    test(
      'maps Firebase errors returned by Google credential sign-in',
      () async {
        TestFixtures.installGoogleSignInMock();
        addTearDown(TestFixtures.removeGoogleSignInMock);
        final auth = TestFixtures.authThatFailsGoogle(
          code: 'invalid-credential',
        );

        await expectLater(
          AuthService(auth: auth).signInWithGoogle(),
          throwsA('Email atau password salah.'),
        );
      },
    );
  });
}
