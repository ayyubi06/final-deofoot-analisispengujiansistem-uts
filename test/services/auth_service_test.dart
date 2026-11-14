import 'package:deofoot/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fase2_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('register / signIn / signOut (MockFirebaseAuth)', () {
    test('register membuat user dan currentUser terisi', () async {
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth);
      await service.register('baru@test.com', 'password123');
      expect(service.currentUser, isNotNull);
      expect(service.currentUser!.email, 'baru@test.com');
    });

    test('signIn berhasil dan currentUser terisi', () async {
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth);
      await service.signIn('siapa@test.com', 'apa-saja');
      expect(service.currentUser, isNotNull);
    });

    test('signOut mengosongkan currentUser', () async {
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth);
      await service.register('a@test.com', 'password123');
      expect(service.currentUser, isNotNull);
      await service.signOut();
      expect(service.currentUser, isNull);
    });

    test('authState mengalirkan user sesudah register', () async {
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth);
      final futureUser = service.authState.firstWhere((user) => user != null);
      await service.register('a@test.com', 'password123');
      final user = await futureUser;
      expect(user, isNotNull);
      expect(user!.email, 'a@test.com');
    });
  });

  group('pesan error Indonesia (mocktail)', () {
    for (final entry in pesanAuthExpected.entries) {
      test('signIn ${entry.key} -> "${entry.value}"', () async {
        final mockAuth = MockAuth();
        when(
          () => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: entry.key));
        final service = AuthService(auth: mockAuth);
        await expectLater(
          () => service.signIn('a@b.com', 'x'),
          throwsA(entry.value),
        );
      });

      test('register ${entry.key} -> "${entry.value}"', () async {
        final mockAuth = MockAuth();
        when(
          () => mockAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: entry.key));
        final service = AuthService(auth: mockAuth);
        await expectLater(
          () => service.register('a@b.com', 'x'),
          throwsA(entry.value),
        );
      });
    }

    test('kode tidak dikenal memakai pesan mentah, lalu kode', () async {
      final mockAuth = MockAuth();
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        FirebaseAuthException(code: 'kode-aneh', message: 'pesan mentah'),
      );
      final service = AuthService(auth: mockAuth);
      await expectLater(
        () => service.signIn('a@b.com', 'x'),
        throwsA('Gagal: pesan mentah'),
      );

      final mockAuth2 = MockAuth();
      when(
        () => mockAuth2.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'kode-aneh'));
      final service2 = AuthService(auth: mockAuth2);
      await expectLater(
        () => service2.signIn('a@b.com', 'x'),
        throwsA('Gagal: kode-aneh'),
      );
    });
  });

  group('signInWithGoogle (mock channel)', () {
    const channel = MethodChannel('plugins.flutter.io/google_sign_in');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('dibatalkan user -> null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      final service = AuthService(auth: MockFirebaseAuth());
      final user = await service.signInWithGoogle();
      expect(user, isNull);
    });

    test('sukses -> user dari credential', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'signIn') {
              return <String, dynamic>{
                'email': 'g@test.com',
                'id': 'google-id-1',
                'displayName': 'Google User',
                'photoUrl': null,
                'serverAuthCode': null,
                'idToken': 'fake-id-token',
              };
            }
            if (call.method == 'getTokens') {
              return <String, dynamic>{
                'accessToken': 'fake-access-token',
                'idToken': 'fake-id-token',
              };
            }
            return null;
          });
      final mockAuth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'google-uid-1', email: 'g@test.com'),
      );
      final service = AuthService(auth: mockAuth);
      final user = await service.signInWithGoogle();
      expect(user, isNotNull);
      expect(user!.uid, 'google-uid-1');
    });
  });
}
