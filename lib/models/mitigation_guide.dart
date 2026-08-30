import 'electrochemical_test.dart';

/// Mitigation and emergency water treatment guidance for disaster relief
class MitigationGuidance {
  final String title;
  final String severity; // Bahaya, Peringatan, Panduan
  final String criticalWarning;
  final List<String> immediateActions;
  final List<String> lowCostTreatmentSteps;
  final String whoStandardRef;

  const MitigationGuidance({
    required this.title,
    required this.severity,
    required this.criticalWarning,
    required this.immediateActions,
    required this.lowCostTreatmentSteps,
    required this.whoStandardRef,
  });

  /// Generate field guidance for specific detected contaminant
  static MitigationGuidance forAnalyte(TargetAnalyte analyte, bool isExceeded) {
    switch (analyte) {
      case TargetAnalyte.lead:
        return MitigationGuidance(
          title: isExceeded ? 'Kontaminasi Timbal (Pb) Terdeteksi!' : 'Kadar Timbal (Pb) Terkendali',
          severity: isExceeded ? 'BAHAYA TINGGI' : 'AMAN',
          criticalWarning: isExceeded
              ? '⚠️ JANGAN REBUS AIR INI! Merebus air TIDAK menghilangkan timbal, tetapi justru menguapkan air dan memekatkan kadar racun timbal.'
              : 'Kadar timbal berada di bawah batas maksimum WHO (0.010 mg/L).',
          immediateActions: isExceeded
              ? [
                  'Tutup akses sumber air ini untuk konsumsi dan memasak bagi pengungsi.',
                  'Pasang tanda peringatan "AIR TIDAK LAYAK MINUM - MENGANDUNG TIMBAL".',
                  'Prioritaskan pasokan air tangki bantuan untuk balita & ibu hamil.',
                  'Laporkan koordinat titik ke Satgas Posko Kesehatan & Dinas Kesehatan.'
                ]
              : [
                  'Sumber air aman dari cemaran timbal.',
                  'Lakukan pengujian ulang secara berkala tiap 48-72 jam pasca bencana.'
                ],
          lowCostTreatmentSteps: isExceeded
              ? [
                  '1. Gunakan media filtrasi arang aktif (Active Carbon) + Pasir Zeolit lokal untuk adsorpsi kation logam.',
                  '2. Terapkan koagulasi darurat menggunakan Tawas (Alum) atau bubuk biji Kelor (Moringa oleifera) untuk mengendapkan partikel terikat.',
                  '3. Jika tersedia, gunakan unit membran Reverse Osmosis (RO) darurat.'
                ]
              : [
                  'Lakukan filtrasi mekanis pasir lambat & disinfeksi klorinasi standar posko.'
                ],
          whoStandardRef: 'WHO Guidelines for Drinking-water Quality (4th ed) & Permenkes No. 2/2023 (Maks. 0.01 mg/L)',
        );

      case TargetAnalyte.arsenic:
        return MitigationGuidance(
          title: isExceeded ? 'Kontaminasi Arsenik (As) Tinggi!' : 'Kadar Arsenik (As) Aman',
          severity: isExceeded ? 'BAHAYA EKSTREM' : 'AMAN',
          criticalWarning: isExceeded
              ? '⚠️ Arsenik adalah karsinogenik kuat tanpa bau dan rasa. Merebus air tidak dapat menetralkannya!'
              : 'Kadar arsenik dalam rentang aman standar baku mutu.',
          immediateActions: isExceeded
              ? [
                  'Hentikan segera konsumsi air dari titik ini.',
                  'Distribusikan filter serbuk besi / pasir besi (Iron-enhanced sand filter).',
                  'Evakuasi sumber pasokan air ke sumber alternatif di elevasi lebih tinggi.'
                ]
              : [
                  'Kadar aman (<0.010 mg/L). Cocok untuk diproses ke tahap disinfeksi kuman.'
                ],
          lowCostTreatmentSteps: isExceeded
              ? [
                  '1. Sistem Filtrasi 3 Ember Sederhana (3-Kolom): Ember 1 (Paku besi/pasir besi karat untuk mengikat Arsenik), Ember 2 (Arang aktif & pasir kuarsa), Ember 3 (Penampung bersih).',
                  '2. Oksidasi aerasi: Kocok air di udara terbuka agar Fe terlarut mengoksidasi As(III) menjadi As(V) sebelum disaring pasir.',
                  '3. Filtrasi membran ultrafiltrasi portable.'
                ]
              : [
                  'Filtrasi pasir standar & pemanasan/klorinasi untuk membunuh bakteri.'
                ],
          whoStandardRef: 'Standar WHO: 0.01 mg/L (10 ppb) | Permenkes No. 2/2023',
        );

      case TargetAnalyte.cadmium:
        return MitigationGuidance(
          title: isExceeded ? 'Kandungan Kadmium (Cd) Melebihi Batas!' : 'Kadar Kadmium (Cd) Normal',
          severity: isExceeded ? 'BAHAYA TINGGI' : 'AMAN',
          criticalWarning: isExceeded
              ? '⚠️ Toksisitas ginjal & tulang. Sumber kontaminasi potensial: endapan baterai, limbah industri tergenang banjir.'
              : 'Kadar kadmium di bawah ambang batas aman 0.003 mg/L.',
          immediateActions: isExceeded
              ? [
                  'Larang penggunaan untuk minum, masak, maupun mandi.',
                  'Cari kemungkinan sumber sampah baterai/elektronik di hulu sumur.',
                  'Salurkan air tangki darurat dari luar zona krisis.'
                ]
              : [
                  'Air memenuhi syarat mutu kadmium.'
                ],
          lowCostTreatmentSteps: isExceeded
              ? [
                  '1. Adsorpsi menggunakan bio-char / arang batok kelapa lokal berdensitas tinggi.',
                  '2. Pengendapan dengan kapur (Lime precipitation) untuk menaikkan pH dan mengendapkan ion hidroksida logam.',
                  '3. Penyaringan lanjutan dengan membran keramik posko.'
                ]
              : [
                  'Pengolahan standar desinfeksi kuman (klorin 0.2-0.5 mg/L).'
                ],
          whoStandardRef: 'Standar WHO & Permenkes: 0.003 mg/L',
        );

      case TargetAnalyte.mercury:
        return MitigationGuidance(
          title: isExceeded ? 'Cemaran Merkuri (Hg) Terdeteksi!' : 'Kadar Merkuri (Hg) Aman',
          severity: isExceeded ? 'BAHAYA TINGGI' : 'AMAN',
          criticalWarning: isExceeded
              ? '⚠️ Merkuri bersifat neurotoksik permanen. Segera isolasi sumber air ini!'
              : 'Kadar merkuri tidak terdeteksi / di bawah batas baku 0.001 mg/L.',
          immediateActions: isExceeded
              ? [
                  'Segel sumber air dan beri garis pembatas.',
                  'Laporkan ke BNPB / Dinas Lingkungan Hidup & Kesehatan.',
                  'Gunakan hanya sumber air kemasan atau tangki steril terverifikasi.'
                ]
              : [
                  'Sumber air terverifikasi bebas merkuri.'
                ],
          lowCostTreatmentSteps: isExceeded
              ? [
                  '1. Filtrasi Resin Penukar Ion (Ion Exchange) atau Arang Aktif yang diimpregnasi belerang/sulfur.',
                  '2. Jangan gunakan metode pemanasan atau filtrasi kain konvensional!',
                  '3. Pengolahan kimiawi terpusat diperlukan untuk merkuri.'
                ]
              : [
                  'Penyaringan fisik dan klorinasi rutin posko pengungsian.'
                ],
          whoStandardRef: 'Standar WHO: 0.001 mg/L (1 ppb) | Permenkes No. 2/2023',
        );

      default:
        return MitigationGuidance(
          title: isExceeded ? 'Peringatan Mutu Air Terdeteksi' : 'Kualitas Air Terpantau Baik',
          severity: isExceeded ? 'PERINGATAN' : 'NORMAL',
          criticalWarning: isExceeded
              ? '⚠️ Parameter air berada di luar rentang optimal. Lakukan tahapan penjernihan sebelum dikonsumsi.'
              : 'Seluruh parameter pengujian awal berada dalam batas aman.',
          immediateActions: [
            'Pastikan wadah penampung air tertutup rapat dan terhindar dari lalat/debu.',
            'Lakukan disinfeksi rutin menggunakan tablet klorin / Aquatabs sesuai takaran posko.',
            'Jaga jarak sumber air minimal 10 meter dari septic tank / jamban darurat.'
          ],
          lowCostTreatmentSteps: [
            '1. Filtrasi fisik berjenjang: Kerikil -> Pasir Kuarsa -> Arang Batok Kelapa -> Spons/Kain Bersih.',
            '2. Aerasi / Pengudaraan untuk menghilangkan bau besi dan gas terlarut.',
            '3. Disinfeksi surya SODIS (botol PET dijemur terik 6 jam) atau perebusan hingga mendidih 1-3 menit (hanya jika bebas logam berat).'
          ],
          whoStandardRef: 'Panduan Sanitasi Air Darurat WHO & Permenkes RI',
        );
    }
  }
}
