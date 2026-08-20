import 'package:flutter_test/flutter_test.dart';

import 'package:drivebiryani/app.dart';

void main() {
  testWidgets('Home screen shows the search field and wordmark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DriveBiryaniApp());

    expect(find.textContaining('DriveBiryani'), findsOneWidget);
    expect(find.text('Search everything you own…'), findsOneWidget);

    await tester.tap(find.text('Stacks'));
    await tester.pumpAndSettle();
    expect(find.text('The Stacks'), findsOneWidget);
    expect(find.text('Add a Google account'), findsOneWidget);
  });
}
