import 'package:flutter_test/flutter_test.dart';

import 'package:photo_sense/main.dart';

void main() {
  testWidgets('App launches and shows sign in screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoSenseApp());

    expect(find.text('PhotoSense'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
