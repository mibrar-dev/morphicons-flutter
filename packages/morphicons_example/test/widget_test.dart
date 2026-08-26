import 'package:flutter_test/flutter_test.dart';
import 'package:morphicons_example/main.dart';

void main() {
  testWidgets('playground boots and shows the morph stage', (tester) async {
    await tester.pumpWidget(const MorphiconsPlayground());
    await tester.pump();

    // The app shell and the morph stage render on the first frame.
    expect(find.textContaining('Morphicons'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
