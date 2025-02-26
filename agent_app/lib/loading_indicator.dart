import 'dart:math' as math;
import 'package:flutter/material.dart';

class CustomLoadingAnimation extends StatefulWidget {
  final double size;
  final List<Color> colors;
  final Duration duration;
  final String? loadingText;
  final TextStyle? textStyle;

  const CustomLoadingAnimation({
    super.key,
    this.size = 80.0,
    this.colors = const [
      Color(0xFF4285F4), // Google Blue
      Color(0xFF34A853), // Google Green
      Color(0xFFFBBC05), // Google Yellow
      Color(0xFFEA4335), // Google Red
    ],
    this.duration = const Duration(milliseconds: 2500),
    this.loadingText,
    this.textStyle,
  });

  @override
  State<CustomLoadingAnimation> createState() => _CustomLoadingAnimationState();
}

class _CustomLoadingAnimationState extends State<CustomLoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    // Rotation animation
    _rotationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOutCubic,
    );

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge(
              [_rotationController, _pulseController, _waveController]),
          builder: (context, child) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  Container(
                    width: widget.size * 1.1 * _pulseAnimation.value,
                    height: widget.size * 1.1 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.colors.first.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),

                  // Inner circle with reverse rotation
                  Transform.rotate(
                    angle: -_rotationAnimation.value * 2 * math.pi,
                    child: Container(
                      width: widget.size * 0.7 * _pulseAnimation.value,
                      height: widget.size * 0.7 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            widget.colors[0].withValues(alpha: 0.8),
                            widget.colors[widget.colors.length > 2 ? 2 : 0]
                                .withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center dot
                  Container(
                    width: widget.size * 0.2,
                    height: widget.size * 0.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),

                  // Orbiting dots
                  ...List.generate(widget.colors.length, (index) {
                    final angle = _rotationAnimation.value * 2 * math.pi +
                        (index * 2 * math.pi / widget.colors.length);
                    final distance = widget.size * 0.35;

                    return Positioned(
                      left: widget.size / 2 + math.cos(angle) * distance - 5,
                      top: widget.size / 2 + math.sin(angle) * distance - 5,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.colors[index % widget.colors.length],
                          boxShadow: [
                            BoxShadow(
                              color: widget.colors[index % widget.colors.length]
                                  .withValues(alpha: 0.5),
                              blurRadius: 7,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Custom painter for wave effect
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: WaveRingPainter(
                      progress: _waveAnimation.value,
                      color: widget.colors.length > 1
                          ? widget.colors[1].withValues(alpha: 0.5)
                          : widget.colors[0].withValues(alpha: 0.5),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.loadingText != null) ...[
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.6 + 0.4 * _pulseController.value,
                child: Text(
                  widget.loadingText!,
                  style: widget.textStyle ??
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class WaveRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  WaveRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();

    for (double i = 0; i < 360; i += 1) {
      final radians = i * math.pi / 180;
      final waveHeight = math.sin((i * 8 + progress * 360) * math.pi / 180) * 5;
      final x = center.dx + (radius + waveHeight) * math.cos(radians);
      final y = center.dy + (radius + waveHeight) * math.sin(radians);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
