import 'package:flutter/material.dart';
import '../models/mitigation_guide.dart';
import '../models/water_sample.dart';

/// Interactive mitigation card presenting actionable disaster relief steps
class MitigationCard extends StatelessWidget {
  final MitigationGuidance guidance;
  final WaterSafetyStatus safetyStatus;

  const MitigationCard({
    super.key,
    required this.guidance,
    required this.safetyStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = safetyStatus == WaterSafetyStatus.danger;
    final isModerate = safetyStatus == WaterSafetyStatus.moderate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDanger
        ? const Color(0xFFE11D48)
        : (isModerate ? const Color(0xFFD97706) : const Color(0xFF059669));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.35), width: 1.5),
      ),
      color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDanger ? Icons.crisis_alert_rounded : Icons.health_and_safety_rounded,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    guidance.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    guidance.severity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Critical warning banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDanger
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                    : (isDark ? Colors.black26 : Colors.white70),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDanger ? const Color(0xFFEF4444).withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      guidance.criticalWarning,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isDanger ? FontWeight.w700 : FontWeight.w500,
                        color: isDanger ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)) : null,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tindakan Tanggap Darurat Lapangan:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...guidance.immediateActions.map(
              (action) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(fontSize: 12.5, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Solusi Filtrasi Murah (Teknologi Tepat Guna):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...guidance.lowCostTreatmentSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.filter_alt_outlined, size: 14, color: primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(fontSize: 12.5, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Rujukan Standar: ${guidance.whoStandardRef}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
