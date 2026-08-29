import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double vRotation;
  double opacity;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.vRotation,
    this.opacity = 1.0,
  });
}

class ConfettiOverlay {
  static void show(BuildContext context, {Duration duration = const Duration(seconds: 3)}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ConfettiWidget(
        duration: duration,
        onFinished: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ConfettiWidget extends StatefulWidget {
  final Duration duration;
  final VoidCallback onFinished;

  const _ConfettiWidget({
    required this.duration,
    required this.onFinished,
  });

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _rng = Random();

  final List<Color> _colors = const [
    Color(0xFFFFD700), // Gold
    Color(0xFF227AFF), // Blue
    Color(0xFFEC4899), // Pink
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF97316), // Orange
    Color(0xFF06B6D4), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(_updateParticles)
     ..addStatusListener((status) {
       if (status == AnimationStatus.completed) {
         widget.onFinished();
       }
     });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _initParticles(size);
      _controller.forward();
    });
  }

  void _initParticles(Size size) {
    _particles.clear();
    for (int i = 0; i < 70; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 4.0 + _rng.nextDouble() * 9.0;
      _particles.add(
        ConfettiParticle(
          x: size.width / 2 + (_rng.nextDouble() - 0.5) * 80,
          y: size.height * 0.4 + (_rng.nextDouble() - 0.5) * 60,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 6.0,
          size: 6.0 + _rng.nextDouble() * 8.0,
          color: _colors[_rng.nextInt(_colors.length)],
          rotation: _rng.nextDouble() * pi * 2,
          vRotation: (_rng.nextDouble() - 0.5) * 0.3,
        ),
      );
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.28; // Gravity
      p.vx *= 0.98; // Friction
      p.rotation += p.vRotation;
      if (_controller.value > 0.6) {
        p.opacity = max(0.0, 1.0 - (_controller.value - 0.6) / 0.4);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(particles: _particles),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      if (p.opacity <= 0) continue;
      paint.color = p.color.withOpacity(p.opacity);

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
