import 'package:deofoot/screens/auth_screen.dart';
import 'package:deofoot/services/auth_service.dart';
import 'package:deofoot/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Matikan pengambilan font via jaringan di test.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('AuthScreen tampil dengan service palsu yang diinjeksikan', (
    tester,
  ) async {
    final mockAuth = MockFirebaseAuth();
    final fakeFirestore = FakeFirebaseFirestore();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          authService: AuthService(auth: mockAuth),
          firestoreService: FirestoreService(db: fakeFirestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
  });
}
