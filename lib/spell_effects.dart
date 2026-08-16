import 'dart:math' as math;
import 'package:flutter/material.dart';

/// سبک‌های مختلف افکت بصری که برای طلسم‌ها استفاده می‌شود
enum EffectStyle {
  burstUp, // ذرات رو به بالا (آتش، جرقه)
  burstRadial, // انفجار به همه‌ی جهات
  rings, // حلقه‌های در حال بزرگ شدن (سپر، قفل، شفا)
  beam, // پرتوهای نورانی از مرکز (نور)
  overlayFade, // پوشش رنگی محو شونده روی کل صفحه (تاریکی، سکوت)
  spiral, // چرخش مارپیچی (گیجی، ردیابی)
  fallDown, // سقوط یا صعود ذرات (آب، حباب، ردپا)
  wrapLines, // خطوط پیچنده دور مرکز (طناب، بانداژ)
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double phase;
  _Particle(this.angle, this.speed, this.size, this.phase);
}

/// ویجت افکت طلسم؛ حدود ۱.۴ ثانیه پخش می‌شود و بعد onDone را صدا می‌زند
class SpellEffectOverlay extends StatefulWidget {
  final Color color;
  final Color secondaryColor;
  final IconData icon;
  final EffectStyle style;
  final bool reverse;
  final VoidCallback onDone;

  const SpellEffectOverlay({
    super.key,
    required this.color,
    required this.icon,
    required this.style,
    this.secondaryColor = Colors.white,
    this.reverse = false,
    required this.onDone,
  });

  @override
  State<SpellEffectOverlay> createState() => _SpellEffectOverlayState();
}

class _SpellEffectOverlayState extends State<SpellEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _particles = List.generate(28, (i) {
      final angle = rnd.nextDouble() * 2 * math.pi;
      final speed = 0.6 + rnd.nextDouble() * 0.6;
      final size = 3.0 + rnd.nextDouble() * 5.0;
      final phase = rnd.nextDouble() * 0.3;
      return _Particle(angle, speed, size, phase);
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_done) {
          _done = true;
          widget.onDone();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _SpellEffectPainter(
              progress: _controller.value,
              color: widget.color,
              secondaryColor: widget.secondaryColor,
              style: widget.style,
              reverse: widget.reverse,
              particles: _particles,
            ),
            child: Center(
              child: Opacity(
                opacity: (math.sin(_controller.value * math.pi)).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + _controller.value * 0.8,
                  child: Icon(widget.icon, size: 70, color: widget.color),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpellEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color secondaryColor;
  final EffectStyle style;
  final bool reverse;
  final List<_Particle> particles;

  _SpellEffectPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.style,
    required this.reverse,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    switch (style) {
      case EffectStyle.burstUp:
        _paintBurstUp(canvas, size);
        break;
      case EffectStyle.burstRadial:
        _paintBurstRadial(canvas, center);
        break;
      case EffectStyle.rings:
        _paintRings(canvas, center);
        break;
      case EffectStyle.beam:
        _paintBeam(canvas, center);
        break;
      case EffectStyle.overlayFade:
        _paintOverlay(canvas, size);
        break;
      case EffectStyle.spiral:
        _paintSpiral(canvas, center);
        break;
      case EffectStyle.fallDown:
        _paintFallDown(canvas, size);
        break;
      case EffectStyle.wrapLines:
        _paintWrapLines(canvas, center);
        break;
    }
  }

  void _paintBurstUp(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.78);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final denom = (1 - p.phase).clamp(0.001, 1.0);
      final t = ((progress - p.phase).clamp(0.0, 1.0)) / denom;
      if (t <= 0) continue;
      final dx = math.sin(p.angle) * 40 * t;
      final dy = -220 * p.speed * t;
      final pos = origin + Offset(dx, dy);
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = Color.lerp(color, secondaryColor, t)!.withOpacity(opacity);
      canvas.drawCircle(pos, p.size * (1 - t * 0.5), paint);
    }
  }

  void _paintBurstRadial(Canvas canvas, Offset center) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final dist = p.speed * 260 * progress;
      final pos = center + Offset(math.cos(p.angle) * dist, math.sin(p.angle) * dist);
      final opacity = (1 - progress).clamp(0.0, 1.0);
      paint.color = Color.lerp(color, secondaryColor, progress)!.withOpacity(opacity);
      canvas.drawCircle(pos, p.size * (1 - progress * 0.4), paint);
    }
  }

  void _paintRings(Canvas canvas, Offset center) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (int i = 0; i < 3; i++) {
      final t = (progress - i * 0.15).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final radius = t * 160;
      paint.color = color.withOpacity((1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintBeam(Canvas canvas, Offset center) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const rayCount = 12;
    final length = 40 + progress * 160;
    for (int i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi / rayCount) * i;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * 20;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * length;
      paint.color = color.withOpacity((1 - progress).clamp(0.0, 1.0));
      canvas.drawLine(start, end, paint);
    }
    final glowPaint = Paint()
      ..color = color.withOpacity((1 - progress) * 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 30 + progress * 20, glowPaint);
  }

  void _paintOverlay(Canvas canvas, Size size) {
    final opacity = (math.sin(progress * math.pi) * 0.55).clamp(0.0, 1.0);
    final paint = Paint()..color = color.withOpacity(opacity);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintSpiral(Canvas canvas, Offset center) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withOpacity((1 - progress * 0.7).clamp(0.0, 1.0));
    final path = Path();
    const turns = 3;
    const steps = 80;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = t * turns * 2 * math.pi + progress * 4 * math.pi;
      final radius = t * 140 * progress;
      final pt = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _paintFallDown(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final t = (progress - p.phase).clamp(0.0, 1.0);
      final startY = reverse ? size.height * 0.85 : -20.0;
      final endY = reverse ? -20.0 : size.height * 0.85;
      final x = (p.angle / (2 * math.pi)) * size.width;
      final y = startY + (endY - startY) * t;
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  void _paintWrapLines(Canvas canvas, Offset center) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity((1 - progress * 0.6).clamp(0.0, 1.0));
    const loops = 4;
    for (int i = 0; i < loops; i++) {
      final startAngle = (i / loops) * 2 * math.pi;
      final sweep = progress * 2 * math.pi;
      final radius = 90 - i * 12.0;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpellEffectPainter oldDelegate) => true;
}
