import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

const _menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
const _x = 'M18 6L6 18M6 6L18 18';

void main() {
  testWidgets('mask preserves child layout, semantics, and hit testing',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: MorphMask.controlled(
            from: _menu,
            icon: _x,
            progress: 1.25,
            child: GestureDetector(
              onTap: () => tapped = true,
              child: SizedBox(
                width: 80,
                height: 40,
                child: Semantics(
                    label: 'Masked child',
                    child: ColoredBox(color: Colors.red)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MorphMask)), const Size(80, 40));
    expect(find.bySemanticsLabel('Masked child'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(MorphMask)));
    expect(tapped, isTrue);
  });

  testWidgets('mask wraps gradient decorated children and updates progress',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: MorphMask.controlled(
            from: _menu,
            icon: _x,
            progress: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
              ),
              child: SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DecoratedBox)), const Size(48, 48));
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: MorphMask.controlled(
            from: _menu,
            icon: _x,
            progress: 1.25,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
              ),
              child: SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uncontrolled mask unregisters on disposal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MorphMask(icon: _menu, child: SizedBox.square(dimension: 24)),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MorphMask(icon: _x, child: SizedBox.square(dimension: 24)),
      ),
    );
    expect(MorphScheduler.instance.activeCount, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(MorphScheduler.instance.activeCount, 0);
  });
}
