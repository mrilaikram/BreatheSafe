import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AirPurityRing extends StatefulWidget {
  final double dustDensity;
  final double size;

  const AirPurityRing({
    super.key,
    required this.dustDensity,
    this.size = 240,
  });

  @override
  State<AirPurityRing> createState() => _AirPurityRingState();
}

class _AirPurityRingState extends State<AirPurityRing>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _previousValue = widget.dustDensity;
    _ringAnimation = Tween<double>(
      begin: 0,
      end: widget.dustDensity,
    ).animate(CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeInOut,
    ));

    _ringController.forward();
  }

  @override
  void didUpdateWidget(AirPurityRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dustDensity != widget.dustDensity) {
      _previousValue = oldWidget.dustDensity;
      _ringAnimation = Tween<double>(
        begin: _previousValue,
        end: widget.dustDensity,
      ).animate(CurvedAnimation(
        parent: _ringController,
        curve: Curves.easeInOut,
      ));
      _ringController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Color _getStatusColor(double dust) {
    if (dust <= 35.0) return AppColors.primaryGreen;
    if (dust <= 55.0) return AppColors.moderateYellow;
    return AppColors.dangerRed;
  }

  List<Color> _getRingGradient(double dust) {
    if (dust <= 35.0) {
      return [AppColors.primaryGreen, AppColors.accentGreen];
    } else if (dust <= 55.0) {
      return [AppColors.moderateYellow, AppColors.accentGreen];
    } else {
      return [AppColors.dangerRed, AppColors.moderateYellow];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _ringController]),
      builder: (context, child) {
        final currentPct = _ringAnimation.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: widget.size + 30,
                height: widget.size + 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(currentPct).withValues(alpha: 0.25),
                      blurRadius: 50,
                      spreadRadius: 15,
                    ),
                    BoxShadow(
                      color: _getStatusColor(currentPct).withValues(alpha: 0.1),
                      blurRadius: 100,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
              // Ring arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  percentage: currentPct,
                  gradientColors: _getRingGradient(currentPct),
                ),
              ),
              // Solid background for the ring interior
              Container(
                width: widget.size - 28,
                height: widget.size - 28,
                decoration: const BoxDecoration(
                  color: AppColors.bgGray,
                  shape: BoxShape.circle,
                ),
              ),
              // Wave fill inside circle
              ClipOval(
                child: SizedBox(
                  width: widget.size - 28,
                  height: widget.size - 28,
                  child: CustomPaint(
                    size: Size(widget.size - 28, widget.size - 28),
                    painter: _WavePainter(
                      wavePhase: _waveController.value,
                      fillPercentage: min(1.0, currentPct / 150.0), // fill up to 150 ug/m3
                      color: _getStatusColor(currentPct),
                    ),
                  ),
                ),
              ),
              // Center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentPct.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'μg/m³ Dust',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percentage;
  final List<Color> gradientColors;

  _RingPainter({
    required this.percentage,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    // Background ring
    final bgPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Gradient ring arc (scale up to 150 ug/m3 for full circle)
    final sweepAngle = min(1.0, percentage / 150.0) * 2 * pi;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: gradientColors,
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -pi / 2,
      sweepAngle,
      false,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}

class _WavePainter extends CustomPainter {
  final double wavePhase;
  final double fillPercentage;
  final Color color;

  _WavePainter({
    required this.wavePhase,
    required this.fillPercentage,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillHeight = size.height * (1 - fillPercentage);

    // Draw background fill
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15);
    canvas.drawRect(
      Rect.fromLTWH(0, fillHeight, size.width, size.height - fillHeight),
      bgPaint,
    );

    // Wave 1 (front)
    final wave1Path = Path();
    wave1Path.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      final y = fillHeight +
          sin((x / size.width * 2 * pi) + (wavePhase * 2 * pi)) * 8 +
          sin((x / size.width * 4 * pi) + (wavePhase * 2 * pi * 1.5)) * 4;
      wave1Path.lineTo(x, y);
    }
    wave1Path.lineTo(size.width, size.height);
    wave1Path.lineTo(0, size.height);
    wave1Path.close();

    final wave1Paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave1Path, wave1Paint);

    // Wave 2 (back, slightly offset)
    final wave2Path = Path();
    wave2Path.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      final y = fillHeight +
          sin((x / size.width * 2 * pi) + (wavePhase * 2 * pi) + pi * 0.7) * 6 +
          sin((x / size.width * 3 * pi) + (wavePhase * 2 * pi * 0.8)) * 5;
      wave2Path.lineTo(x, y);
    }
    wave2Path.lineTo(size.width, size.height);
    wave2Path.lineTo(0, size.height);
    wave2Path.close();

    final wave2Paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave2Path, wave2Paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase ||
        oldDelegate.fillPercentage != fillPercentage;
  }
}
