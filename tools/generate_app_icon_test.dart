// Renders the in-app RomdoulLogo into Android launcher icons.
// Run:  flutter test tools/generate_app_icon_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romdoul_bank/theme.dart';
import 'package:romdoul_bank/widgets/art.dart';

const _res = 'android/app/src/main/res';

// density -> (legacy icon px, adaptive foreground px)
const _densities = {
  'mdpi': (48, 108),
  'hdpi': (72, 162),
  'xhdpi': (96, 216),
  'xxhdpi': (144, 324),
  'xxxhdpi': (192, 432),
};

Future<void> _render(WidgetTester tester, Widget child, double size, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: key,
      child: SizedBox.square(dimension: size, child: child),
    ),
  ));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('generate launcher icons', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final MapEntry(key: d, value: (legacy, fg)) in _densities.entries) {
      // Legacy (pre-Android 8) icon: navy tile with the logo.
      await _render(
        tester,
        ColoredBox(
          color: RB.navy,
          child: Center(child: RomdoulLogo(size: legacy * 0.72)),
        ),
        legacy.toDouble(),
        '$_res/mipmap-$d/ic_launcher.png',
      );
      // Adaptive icon foreground: logo inside the 66% safe zone, transparent around it.
      await _render(
        tester,
        Center(child: RomdoulLogo(size: fg * 0.56)),
        fg.toDouble(),
        '$_res/mipmap-$d/ic_launcher_foreground.png',
      );
    }
    // Large preview (also usable for the Play Store listing).
    await _render(
      tester,
      const ColoredBox(color: RB.navy, child: Center(child: RomdoulLogo(size: 512 * 0.62))),
      512,
      'tools/app_icon_512.png',
    );
  });
}
