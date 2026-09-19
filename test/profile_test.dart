import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_app/screens/profile_overview_screen.dart';

void main() {
  testWidgets('ProfileOverviewScreen renders with Provider', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileData>(
        create: (_) => ProfileData(),
        child: const MaterialApp(home: ProfileOverviewScreen()),
      ),
    );

    expect(find.text('Andrei Esporlas'), findsOneWidget);
    expect(find.text('Account Profile'), findsOneWidget);
    expect(find.text('AE'), findsOneWidget);
  });

  testWidgets('ProfileOverviewScreen renders without Provider (fallback)', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileOverviewScreen()));

    expect(find.text('Andrei Esporlas'), findsOneWidget);
  });

  testWidgets('Handles names with multiple spaces safely in initials', (
    tester,
  ) async {
    final profile = ProfileData()..name = 'John   Doe';
    await tester.pumpWidget(
      MaterialApp(home: ProfileOverviewScreen(profile: profile)),
    );

    expect(find.text('JD'), findsOneWidget);
  });
}
