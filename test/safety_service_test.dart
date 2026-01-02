import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kinnect/data/services/safety_service.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late SafetyService safetyService;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    // Auth client'ı bağla
    when(() => mockSupabaseClient.auth).thenReturn(mockAuth);

    // SafetyService'i mock client ile başlat
    safetyService = SafetyService(client: mockSupabaseClient);
  });

  group('SafetyService Crash Tests (Null Auth - Crash Verification)', () {
    test(
        'getIdsThatBlockedMe returns empty list instead of crashing when user is null',
        () async {
      // Arrange: currentUser is null (Logged out or Session expired)
      when(() => mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await safetyService.getIdsThatBlockedMe();

      // Assert
      expect(result, isEmpty);
      // Başarılı olması CRASH OLMADIĞINI kanıtlar
    });

    test(
        'getIdsIBlocked returns empty list instead of crashing when user is null',
        () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      final result = await safetyService.getIdsIBlocked();
      expect(result, isEmpty);
    });

    test('blockUser should safely return without crash when user is null',
        () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      // Exception atmamalı
      await safetyService.blockUser('some-target-id');
    });

    test('isUserBlocked returns false instead of crashing when user is null',
        () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      final result = await safetyService.isUserBlocked('some-target-id');
      expect(result, isFalse);
    });
  });
}
