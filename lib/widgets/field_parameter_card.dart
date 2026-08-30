import 'package:flutter/material.dart';
import '../models/electrochemical_test.dart';

/// Interactive parameter editor and technique selector card
class FieldParameterCard extends StatelessWidget {
  final ScanParameters parameters;
  final ValueChanged<ScanParameters> onParametersChanged;
  final bool isScanning;

  const FieldParameterCard({
    super.key,
    required this.parameters,
    required this.onParametersChanged,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text(
                      'Parameter Elektrokimia',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: isScanning ? null : () => _showFullParamDialog(context),
                  icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                  label: const Text('Ubah Detail', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Technique Selection Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ElectrochemicalTechnique.values.map((tech) {
                  final isSelected = parameters.technique == tech;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(tech.shortName),
                      selected: isSelected,
                      onSelected: isScanning
                          ? null
                          : (selected) {
                              if (selected) {
                                onParametersChanged(parameters.copyWith(technique: tech));
                              }
                            },
                      selectedColor: const Color(0xFF0284C7),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Grid of Key Parameters
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _paramItem('E_start', '${parameters.startPotentialV.toStringAsFixed(2)} V'),
                  _divider(isDark),
                  _paramItem('E_end', '${parameters.endPotentialV.toStringAsFixed(2)} V'),
                  _divider(isDark),
                  _paramItem('Scan Rate', '${parameters.scanRateMvPerSec.toStringAsFixed(0)} mV/s'),
                  _divider(isDark),
                  _paramItem('Deposition', '${parameters.depositionTimeSec.toStringAsFixed(0)} s'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? Colors.white24 : Colors.black12,
    );
  }

  Widget _paramItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  void _showFullParamDialog(BuildContext context) {
    double estart = parameters.startPotentialV;
    double eend = parameters.endPotentialV;
    double scanRate = parameters.scanRateMvPerSec;
    double depTime = parameters.depositionTimeSec;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Sesuaikan Parameter Scan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sliderTile('Potensial Awal (E_start)', estart, -1.5, 1.5, 'V', (v) {
                      setModalState(() => estart = double.parse(v.toStringAsFixed(2)));
                    }),
                    _sliderTile('Potensial Akhir (E_end)', eend, -1.5, 1.5, 'V', (v) {
                      setModalState(() => eend = double.parse(v.toStringAsFixed(2)));
                    }),
                    _sliderTile('Scan Rate (Kecepatan)', scanRate, 10, 500, 'mV/s', (v) {
                      setModalState(() => scanRate = double.parse(v.toStringAsFixed(0)));
                    }),
                    _sliderTile('Waktu Deposisi / Stripping', depTime, 0, 60, 'detik', (v) {
                      setModalState(() => depTime = double.parse(v.toStringAsFixed(0)));
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    onParametersChanged(parameters.copyWith(
                      startPotentialV: estart,
                      endPotentialV: eend,
                      scanRateMvPerSec: scanRate,
                      depositionTimeSec: depTime,
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sliderTile(String title, double value, double min, double max, String unit, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('$value $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFF0284C7),
          ),
        ],
      ),
    );
  }
}
