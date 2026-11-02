import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui/main.dart';
import '../archive/legacy_monolithic_lib/core/constants/app_strings.dart';
import '../archive/legacy_monolithic_lib/main.dart';

void main() {
  testWidgets('ApnaJamuiApp smoke test - splash renders and transitions', (WidgetTester tester) async {
    // App build करें
    await tester.pumpWidget(const ApnaJamuiApp());

    // Verify splash elements
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);

    // Timer और एनीमेशन को पूरा होने दें
    await tester.pumpAndSettle(const Duration(milliseconds: 3000));
  });
}
