import 'dart:math';
import 'package:flutter/material.dart';
import '../models/water_sample.dart';

/// Animated circular gauge displaying Water Quality Index (0-100) & Safety Status
class WaterQualityGauge extends StatelessWidget {
  final double score; // 0 to 100
  final WaterSafetyStatus status;
  final double size;

  const WaterQualityGauge({
    super.key,
    required this.score,
    required this.status,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (status) {
      case WaterSafetyStatus.safe:
        statusColor = const Color(0xFF10B981);
        statusTitle = 'LAYAK MINUM';
        statusIcon = Icons.check_circle_rounded;
        break;
      case WaterSafetyStatus.moderate:
        statusColor = const Color(0xFFF59E0B);
        statusTitle = 'PERLU FILTER';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case WaterSafetyStatus.danger:
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'BAHAYA TERCEMAR';
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * 0.85,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size * 0.85),
                painter: _GaugePainter(
                  score: score,
                  color: statusColor,
                  isDark: isDark,
                ),
              ),
              Positioned(
                top: size * 0.28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'WQI SCORE (0-100)',
                      style: TextStyle(
                        fontSize: size * 0.055,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 6),
              Text(
                statusTitle,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final bool isDark;

  _GaugePainter({required this.score, required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = size.width * 0.38;

    const startAngle = pi * 0.80; // 144 degrees
    const sweepAngle = pi * 1.40; // 252 degrees span

    // Background track arc
    final trackPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Active progress arc
    final progressSweep = sweepAngle * (score.clamp(0.0, 100.0) / 100.0);
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: const [
          Color(0xFFEF4444),
          Color(0xFFF59E0B),
          Color(0xFF10B981),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressSweep,
      false,
      progressPaint,
    );

    // Current needle / marker dot at progress tip
    final currentAngle = startAngle + progressSweep;
    final dotX = center.dx + radius * cos(currentAngle);
    final dotY = center.dy + radius * sin(currentAngle);

    final dotOuter = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(dotX, dotY), 7.0, dotOuter);

    final dotInner = Paint()..color = color;
    canvas.drawCircle(Offset(dotX, dotY), 4.5, dotInner);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
