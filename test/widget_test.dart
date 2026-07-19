import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_app/main.dart';

void main() {
  testWidgets('Store app home screen renders login actions', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StoreManagementApp()));

    expect(find.text('National University'), findsOneWidget);
    expect(find.text('Store & Inventory Management'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create new account'), findsOneWidget);
  });
}
