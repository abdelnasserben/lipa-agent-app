import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Official Lipa mark — a solid dot followed by two echoing arcs.
/// Transcribed from the Customer design `tokens.jsx` LipaMark (viewBox 0 0 100 100).
class LipaMark extends StatelessWidget {
  const LipaMark({super.key, this.size = 36, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LipaMarkPainter(
          ink: dark ? Colors.white : const Color(0xFF0A0A0A),
        ),
      ),
    );
  }
}

class _LipaMarkPainter extends CustomPainter {
  _LipaMarkPainter({required this.ink});

  final Color ink;
  static const _accent = AppColors.brand;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final dot = Paint()..color = ink;
    canvas.drawCircle(Offset(26 * s, 50 * s), 9 * s, dot);

    final inner = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * s
      ..strokeCap = StrokeCap.round;
    final p1 = Path()
      ..moveTo(44 * s, 32 * s)
      ..quadraticBezierTo(60 * s, 50 * s, 44 * s, 68 * s);
    canvas.drawPath(p1, inner);

    final outer = Paint()
      ..color = _accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * s
      ..strokeCap = StrokeCap.round;
    final p2 = Path()
      ..moveTo(58 * s, 22 * s)
      ..quadraticBezierTo(80 * s, 50 * s, 58 * s, 78 * s);
    canvas.drawPath(p2, outer);
  }

  @override
  bool shouldRepaint(covariant _LipaMarkPainter old) => old.ink != ink;
}

/// Wordmark: mark + "Lipa" + an uppercase subtitle.
///
/// The Agent app surfaces the "AGENT" subtitle by default so the operator
/// always knows which Lipa surface they are in (vs the Customer app).
class LipaWordmark extends StatelessWidget {
  const LipaWordmark({
    super.key,
    this.subtitle = 'Agent',
    this.dark = false,
    this.size = 36,
  });

  final String? subtitle;
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LipaMark(size: size, dark: dark),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lipa',
              style: AppText.ui(
                size: size * 0.55,
                weight: FontWeight.w700,
                color: dark ? Colors.white : AppColors.inkHi,
                letterSpacing: -(size * 0.55) * 0.01,
                height: 1,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!.toUpperCase(),
                style: AppText.ui(
                  size: 10,
                  weight: FontWeight.w600,
                  color: dark ? Colors.white54 : AppColors.inkLow,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The faint grid + radial-fade overlay used on the dark hero panels.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key, this.cell = 64});

  final double cell;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => RadialGradient(
            center: const Alignment(0.9, -0.9),
            radius: 1.2,
            colors: const [Colors.black, Colors.transparent],
            stops: const [0.3, 0.75],
          ).createShader(rect),
          child: CustomPaint(painter: _GridPainter(cell: cell)),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.cell});
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.cell != cell;
}

/// A deterministic faux QR rendered from an `otpauth://` URI for the TOTP
/// enrollment screen. It is *not* a real scannable QR — it visualizes that a
/// secret exists; the agent enters the displayed Base32 secret into their
/// authenticator. (No QR-encoding dependency is pulled in for this build.)
class FakeQr extends StatelessWidget {
  const FakeQr({super.key, this.size = 160, this.seedText = ''});
  final double size;
  final String seedText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FakeQrPainter(seedText.hashCode)),
    );
  }
}

class _FakeQrPainter extends CustomPainter {
  _FakeQrPainter(this.seed);
  final int seed;
  static const _n = 25;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _n;
    final dark = Paint()..color = const Color(0xFF0A0A0A);
    final white = Paint()..color = Colors.white;
    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final corner = (x < 7 && y < 7) ||
            (x >= _n - 7 && y < 7) ||
            (x < 7 && y >= _n - 7);
        final s = (x * 31 + y * 17 + x * y * 3 + seed) % 7;
        if (corner || s < 3) {
          canvas.drawRect(
              Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
        }
      }
    }
    // Finder patterns.
    for (final c in const [
      [0, 0],
      [_n - 7, 0],
      [0, _n - 7]
    ]) {
      final ox = c[0] * cell, oy = c[1] * cell, w = 7 * cell;
      canvas.drawRect(Rect.fromLTWH(ox, oy, w, w), white);
      canvas.drawRect(
        Rect.fromLTWH(ox, oy, w, w),
        Paint()
          ..color = const Color(0xFF0A0A0A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell,
      );
      canvas.drawRect(
          Rect.fromLTWH(ox + 2 * cell, oy + 2 * cell, 3 * cell, 3 * cell),
          dark);
    }
  }

  @override
  bool shouldRepaint(covariant _FakeQrPainter old) => old.seed != seed;
}
