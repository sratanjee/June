import 'package:flutter_test/flutter_test.dart';

import 'package:june_mobile/main.dart';

void main() {
  testWidgets('App boots to the entry screen', (tester) async {
    await tester.pumpWidget(const JuneApp());
    expect(find.text('Tell me what you have.'), findsOneWidget);
  });
}
