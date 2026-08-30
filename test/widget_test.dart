import 'package:flutter_test/flutter_test.dart';
import 'package:despro/main.dart';

void main() {
  testWidgets('PortaStat App renders successfully and displays main navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const PortaStatApp());

    // Verify app title is displayed
    expect(find.text('PortaStat'), findsOneWidget);
    expect(find.text('Deteksi Kualitas Air Bencana'), findsOneWidget);

    // Verify bottom navigation bar destinations
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Uji & Grafik'), findsOneWidget);
    expect(find.text('Catatan Air'), findsOneWidget);
    expect(find.text('Perakitan'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);

    // Navigate to 'Uji & Grafik' tab
    await tester.tap(find.text('Uji & Grafik'));
    await tester.pumpAndSettle();

    expect(find.text('Uji Elektrokimia PortaStat'), findsOneWidget);
  });
}
