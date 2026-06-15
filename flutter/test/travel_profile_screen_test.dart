import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/settings/travel_profile_screen.dart';
import 'package:wayfarer/models/traveler_profile.dart';
import 'package:wayfarer/providers/profile_provider.dart';
import 'package:wayfarer/services/api_client.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');
  Map<String, dynamic>? lastPatch;

  @override
  Future<TravelerProfile> patchProfile(Map<String, dynamic> patch) async {
    lastPatch = patch;
    return const TravelerProfile(id: '1', userId: 'paul');
  }
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: TravelProfileScreen()),
    );

/// Tall surface so the whole ListView (incl. the bottom Save button) builds —
/// the form is longer than the default 800×600 test viewport.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('renders form seeded from the profile', (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_app([
      profileProvider.overrideWith((ref) async => const TravelerProfile(
            id: '1',
            userId: 'paul',
            lodgingStyle: 'boutique',
            profileSummary: 'Likes slow travel.',
            preferencesBlob: {
              'interests': ['history'],
            },
          )),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Travel Profile'), findsOneWidget);
    expect(find.text('Lodging style'), findsOneWidget);
    expect(find.text('Likes slow travel.'), findsOneWidget); // summary card
    expect(find.text('Save profile'), findsOneWidget);
  });

  testWidgets('offline (null) profile shows a notice, no form', (tester) async {
    await tester.pumpWidget(_app([
      profileProvider.overrideWith((ref) async => null),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Backend unreachable'), findsOneWidget);
    expect(find.text('Save profile'), findsNothing);
  });

  testWidgets('selecting an interest and saving sends the merged patch',
      (tester) async {
    _tallSurface(tester);
    final api = _FakeApi();
    await tester.pumpWidget(_app([
      apiClientProvider.overrideWithValue(api),
      profileProvider.overrideWith((ref) async => const TravelerProfile(
            id: '1',
            userId: 'paul',
            preferencesBlob: {
              'interests': ['history'],
            },
          )),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food'));
    await tester.pump();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(api.lastPatch, isNotNull);
    final blob = api.lastPatch!['preferences_blob'] as Map<String, dynamic>;
    expect(blob['interests'], containsAll(<String>['history', 'food']));
    expect(find.text('Travel profile saved'), findsOneWidget); // SnackBar
  });
}
