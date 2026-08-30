import 'dart:math';
import 'package:flutter/material.dart';
import '../models/electrochemical_test.dart';

/// Real-time high performance voltammogram painter
class LiveVoltammogramChart extends StatefulWidget {
  final List<VoltammogramPoint> points;
  final List<DetectedPeak> detectedPeaks;
  final ElectrochemicalTechnique technique;
  final bool showBaseline;
  final bool isScanning;
  final double? activePotentialV;

  const LiveVoltammogramChart({
    super.key,
    required this.points,
    this.detectedPeaks = const [],
    this.technique = ElectrochemicalTechnique.differentialPulse,
    this.showBaseline = true,
    this.isScanning = false,
    this.activePotentialV,
  });

  @override
  State<LiveVoltammogramChart> createState() => _LiveVoltammogramChartState();
}

class _LiveVoltammogramChartState extends State<LiveVoltammogramChart> {
  VoltammogramPoint? _selectedPoint;
  Offset? _touchPosition;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) => _handleTouch(details.localPosition, constraints.biggest),
          onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.biggest),
          onPanEnd: (_) => setState(() {
            _selectedPoint = null;
            _touchPosition = null;
          }),
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _VoltammogramPainter(
              points: widget.points,
              detectedPeaks: widget.detectedPeaks,
              technique: widget.technique,
              showBaseline: widget.showBaseline,
              isScanning: widget.isScanning,
              selectedPoint: _selectedPoint,
              touchPosition: _touchPosition,
              theme: Theme.of(context),
            ),
          ),
        );
      },
    );
  }

  void _handleTouch(Offset touchPos, Size size) {
    if (widget.points.isEmpty) return;

    // Bounds calculation
    double minX = widget.points.map((p) => p.potentialV).reduce(min);
    double maxX = widget.points.map((p) => p.potentialV).reduce(max);
    if (minX == maxX) {
      minX -= 0.5;
      maxX += 0.5;
    }

    const double paddingLeft = 52.0;
    const double paddingRight = 20.0;
    final chartWidth = size.width - paddingLeft - paddingRight;

    final touchRatio = ((touchPos.dx - paddingLeft) / chartWidth).clamp(0.0, 1.0);
    final targetPotential = minX + (touchRatio * (maxX - minX));

    // Find nearest point
    VoltammogramPoint nearest = widget.points.first;
    double minDiff = (nearest.potentialV - targetPotential).abs();

    for (final p in widget.points) {
      final diff = (p.potentialV - targetPotential).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = p;
      }
    }

    setState(() {
      _selectedPoint = nearest;
      _touchPosition = touchPos;
    });
  }
}

class _VoltammogramPainter extends CustomPainter {
  final List<VoltammogramPoint> points;
  final List<DetectedPeak> detectedPeaks;
  final ElectrochemicalTechnique technique;
  final bool showBaseline;
  final bool isScanning;
  final VoltammogramPoint? selectedPoint;
  final Offset? touchPosition;
  final ThemeData theme;

  _VoltammogramPainter({
    required this.points,
    required this.detectedPeaks,
    required this.technique,
    required this.showBaseline,
    required this.isScanning,
    this.selectedPoint,
    this.touchPosition,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 54.0;
    const double paddingRight = 24.0;
    const double paddingTop = 28.0;
    const double paddingBottom = 40.0;

    final chartRect = Rect.fromLTRB(
      paddingLeft,
      paddingTop,
      size.width - paddingRight,
      size.height - paddingBottom,
    );

    final isDark = theme.brightness == Brightness.dark;
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(8)),
      bgPaint,
    );

    // Coordinate ranges
    double minX = -1.0;
    double maxX = 1.0;
    double minY = -2.0;
    double maxY = 15.0;

    if (points.isNotEmpty) {
      final xVals = points.map((p) => p.potentialV).toList();
      final yVals = points.map((p) => p.currentMicroA).toList();

      minX = xVals.reduce(min);
      maxX = xVals.reduce(max);
      minY = yVals.reduce(min);
      maxY = yVals.reduce(max);

      // Margin expansions
      final spanX = (maxX - minX).abs();
      if (spanX < 0.1) {
        minX -= 0.5;
        maxX += 0.5;
      } else {
        minX -= spanX * 0.05;
        maxX += spanX * 0.05;
      }

      final spanY = (maxY - minY).abs();
      if (spanY < 0.2) {
        minY -= 1.0;
        maxY += 1.0;
      } else {
        minY -= spanY * 0.12;
        maxY += spanY * 0.18;
      }
    }

    Offset toCanvas(double x, double y) {
      final normX = (x - minX) / (maxX - minX);
      final normY = (y - minY) / (maxY - minY);
      final canvasX = chartRect.left + (normX * chartRect.width);
      final canvasY = chartRect.bottom - (normY * chartRect.height);
      return Offset(canvasX, canvasY);
    }

    _drawGridAndAxes(canvas, chartRect, minX, maxX, minY, maxY, toCanvas, isDark);

    if (points.isEmpty) {
      _drawEmptyState(canvas, chartRect, isDark);
      return;
    }

    // Draw baseline if requested
    if (showBaseline && detectedPeaks.isNotEmpty) {
      final baselinePaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final baselinePath = Path();
      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final baselineY = 0.5 + (0.2 * p.potentialV);
        final pt = toCanvas(p.potentialV, baselineY);
        if (i == 0) {
          baselinePath.moveTo(pt.dx, pt.dy);
        } else {
          baselinePath.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(baselinePath, baselinePaint);
    }

    // Draw main Voltammogram curve
    final curvePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.25),
          const Color(0xFF0284C7).withValues(alpha: 0.0),
        ],
      ).createShader(chartRect);

    final path = Path();
    final fillPath = Path();

    final firstPt = toCanvas(points.first.potentialV, points.first.currentMicroA);
    path.moveTo(firstPt.dx, firstPt.dy);
    fillPath.moveTo(firstPt.dx, chartRect.bottom);
    fillPath.lineTo(firstPt.dx, firstPt.dy);

    for (int i = 1; i < points.length; i++) {
      final pt = toCanvas(points[i].potentialV, points[i].currentMicroA);
      path.lineTo(pt.dx, pt.dy);
      fillPath.lineTo(pt.dx, pt.dy);
    }

    final lastPt = toCanvas(points.last.potentialV, points.last.currentMicroA);
    fillPath.lineTo(lastPt.dx, chartRect.bottom);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, curvePaint);

    // Draw Peak Highlights & Annotations
    for (final peak in detectedPeaks) {
      final peakPos = toCanvas(peak.potentialV, peak.peakCurrentMicroA);
      
      // Peak ring
      final ringPaint = Paint()
        ..color = const Color(0xFFE11D48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(peakPos, 6.0, ringPaint);

      final centerDot = Paint()..color = Colors.white;
      canvas.drawCircle(peakPos, 3.0, centerDot);

      // Peak label annotation
      _drawPeakAnnotation(canvas, peakPos, peak, isDark);
    }

    // Draw Scanning Active Dot
    if (isScanning && points.isNotEmpty) {
      final scanPos = toCanvas(points.last.potentialV, points.last.currentMicroA);
      final pulsePaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(scanPos, 10.0, pulsePaint);

      final laserPaint = Paint()..color = const Color(0xFF10B981);
      canvas.drawCircle(scanPos, 4.5, laserPaint);
    }

    // Draw touch inspection marker
    if (selectedPoint != null && touchPosition != null) {
      final inspectPos = toCanvas(selectedPoint!.potentialV, selectedPoint!.currentMicroA);
      
      final linePaint = Paint()
        ..color = isDark ? Colors.white38 : Colors.black26
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(Offset(inspectPos.dx, chartRect.top), Offset(inspectPos.dx, chartRect.bottom), linePaint);
      canvas.drawLine(Offset(chartRect.left, inspectPos.dy), Offset(chartRect.right, inspectPos.dy), linePaint);

      final touchDot = Paint()..color = Colors.deepOrange;
      canvas.drawCircle(inspectPos, 5.0, touchDot);

      _drawInspectTooltip(canvas, inspectPos, selectedPoint!, chartRect, isDark);
    }
  }

  void _drawGridAndAxes(
    Canvas canvas,
    Rect rect,
    double minX,
    double maxX,
    double minY,
    double maxY,
    Offset Function(double, double) toCanvas,
    bool isDark,
  ) {
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    final borderPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black26
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, borderPaint);

    final textStyle = TextStyle(
      color: isDark ? Colors.white70 : const Color(0xFF475569),
      fontSize: 10,
      fontFamily: 'monospace',
    );

    // X Axis Ticks (Potential V)
    const int numXTicks = 5;
    for (int i = 0; i <= numXTicks; i++) {
      final valX = minX + (i * (maxX - minX) / numXTicks);
      final pt = toCanvas(valX, minY);

      canvas.drawLine(Offset(pt.dx, rect.top), Offset(pt.dx, rect.bottom), gridPaint);

      final textSpan = TextSpan(text: '${valX >= 0 ? "+" : ""}${valX.toStringAsFixed(2)}', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(pt.dx - (textPainter.width / 2), rect.bottom + 6));
    }

    // Y Axis Ticks (Current μA)
    const int numYTicks = 5;
    for (int i = 0; i <= numYTicks; i++) {
      final valY = minY + (i * (maxY - minY) / numYTicks);
      final pt = toCanvas(minX, valY);

      canvas.drawLine(Offset(rect.left, pt.dy), Offset(rect.right, pt.dy), gridPaint);

      final textSpan = TextSpan(text: valY.toStringAsFixed(1), style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(rect.left - textPainter.width - 6, pt.dy - 6));
    }

    // Axis Labels
    final xLabel = TextSpan(
      text: 'Potensial E (V vs RE)',
      style: TextStyle(
        color: isDark ? Colors.white60 : const Color(0xFF64748B),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    final xPainter = TextPainter(text: xLabel, textDirection: TextDirection.ltr)..layout();
    xPainter.paint(canvas, Offset(rect.center.dx - (xPainter.width / 2), rect.bottom + 22));

    // Y Axis Title (Arus μA)
    final yLabel = TextSpan(
      text: 'Arus I (μA)',
      style: TextStyle(
        color: isDark ? Colors.white60 : const Color(0xFF64748B),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    final yPainter = TextPainter(text: yLabel, textDirection: TextDirection.ltr)..layout();
    
    canvas.save();
    canvas.translate(14, rect.center.dy + (yPainter.width / 2));
    canvas.rotate(-pi / 2);
    yPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawPeakAnnotation(Canvas canvas, Offset pos, DetectedPeak peak, bool isDark) {
    final name = peak.matchedAnalyte?.symbol ?? 'Peak';
    final text = '$name (${peak.potentialV.toStringAsFixed(2)}V, ${peak.peakCurrentMicroA.toStringAsFixed(1)}μA)';

    final bgPaint = Paint()..color = const Color(0xFFE11D48);
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final bubbleRect = Rect.fromCenter(
      center: Offset(pos.dx, pos.dy - 16),
      width: tp.width + 10,
      height: tp.height + 6,
    );

    canvas.drawRRect(RRect.fromRectAndRadius(bubbleRect, const Radius.circular(4)), bgPaint);
    tp.paint(canvas, Offset(bubbleRect.left + 5, bubbleRect.top + 3));
  }

  void _drawInspectTooltip(Canvas canvas, Offset pos, VoltammogramPoint p, Rect chartRect, bool isDark) {
    final text = 'E: ${p.potentialV.toStringAsFixed(3)} V | I: ${p.currentMicroA.toStringAsFixed(2)} μA';
    final bgPaint = Paint()..color = isDark ? Colors.grey[850]! : const Color(0xFF1E293B);
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final tooltipX = (pos.dx - (tp.width / 2)).clamp(chartRect.left + 4, chartRect.right - tp.width - 4);
    final tooltipY = (pos.dy - 28 < chartRect.top) ? pos.dy + 12 : pos.dy - 28;

    final rect = Rect.fromLTWH(tooltipX, tooltipY, tp.width + 12, tp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), bgPaint);
    tp.paint(canvas, Offset(rect.left + 6, rect.top + 3));
  }

  void _drawEmptyState(Canvas canvas, Rect rect, bool isDark) {
    final textSpan = TextSpan(
      text: 'Siap Melakukan Pengukuran\nTekan tombol "Mulai Uji Elektrokimia"',
      style: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 13,
        height: 1.4,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 40);

    tp.paint(canvas, Offset(rect.center.dx - (tp.width / 2), rect.center.dy - (tp.height / 2)));
  }

  @override
  bool shouldRepaint(covariant _VoltammogramPainter oldDelegate) => true;
}
