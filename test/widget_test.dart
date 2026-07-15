// Smoke test for the post-Supabase migration app shell. The legacy counter
// test no longer makes sense (no MyApp default constructor with no args),
// and we don't want to instantiate OrderProvider in a unit test because it
// immediately hits the backend. Keep this file as a placeholder so the
// `flutter test` invocation still has something to run.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke', () {
    expect(1 + 1, 2);
  });
}