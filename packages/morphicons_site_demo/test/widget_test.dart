import 'package:flutter_test/flutter_test.dart';
import 'package:morphicons_site_demo/main.dart';

void main() {
  testWidgets('bridge app boots and shows telemetry panel', (tester) async {
    await tester.pumpWidget(const BridgeApp());
    await tester.pump();
    expect(find.textContaining('morphicons_flutter'), findsOneWidget);
    expect(find.textContaining('mode'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
