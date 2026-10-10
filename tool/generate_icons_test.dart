import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/theme/app_theme.dart';

// Generates the launcher icon images into assets/icon/.
// Run with: flutter test tool/generate_icons_test.dart
//
// The "A" geometry below mirrors lib/widgets/app_logo.dart (same points,
// same stroke width ratio, same teal -> blue gradient). If the logo changes,
// update _paintMark() and run this again.

const int _px = 1024;

Future<void> _save(
  String name,
  void Function(Canvas canvas, Size size) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas, const Size(1024, 1024));
  final picture = recorder.endRecording();
  final image = await picture.toImage(_px, _px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('assets/icon/$name');
  await file.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

// Same gradient as the splash screen background.
void _paintBackground(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.darkBackgroundGradientTop,
        AppColors.surfaceDarkAlt,
        Color(0xFF3A2E4F),
      ],
    ).createShader(rect);
  canvas.drawRect(rect, paint);
}

// The "A" mark, centered. [fraction] is the logo square's size relative to
// the canvas (same idea as AppLogo(size: ...)).
void _paintMark(
  Canvas canvas,
  Size size,
  double fraction, {
  Color? flatColor,
}) {
  final logo = size.width * fraction;
  final ox = (size.width - logo) / 2;
  final oy = (size.height - logo) / 2;
  final rect = Rect.fromLTWH(ox, oy, logo, logo);

  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = logo * 0.13
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  if (flatColor != null) {
    paint.color = flatColor;
  } else {
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.teal, AppColors.accentBlueStrong],
    ).createShader(rect);
  }

  Offset pt(double x, double y) => Offset(ox + logo * x, oy + logo * y);

  final a = pt(0.14, 0.86);
  final b = pt(0.5, 0.14);
  final c = pt(0.86, 0.86);
  final d = pt(0.30, 0.62);
  final e = pt(0.70, 0.62);

  final path = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..moveTo(d.dx, d.dy)
    ..lineTo(e.dx, e.dy);
  canvas.drawPath(path, paint);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate launcher icon images', () async {
    // Standard full-bleed icon (iOS, Windows, legacy Android).
    await _save('app_icon.png', (c, s) {
      _paintBackground(c, s);
      _paintMark(c, s, 0.66);
    });

    // Android adaptive icon layers (mark kept inside the safe zone).
    await _save('app_icon_background.png', (c, s) => _paintBackground(c, s));
    await _save('app_icon_foreground.png', (c, s) => _paintMark(c, s, 0.58));

    // Android 13+ themed icon (flat shape, the launcher tints it).
    await _save(
      'app_icon_monochrome.png',
      (c, s) => _paintMark(c, s, 0.58, flatColor: Colors.white),
    );
  });
}
