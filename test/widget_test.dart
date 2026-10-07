import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aql_inspect/main.dart';
import 'package:aql_inspect/aql.dart';
import 'package:aql_inspect/models.dart';
import 'package:aql_inspect/pdf_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Table I code letters', () {
    expect(codeLetters[codeLetterIndex(500, InspectionLevel.II)], 'H');
    expect(codeLetters[codeLetterIndex(1000, InspectionLevel.II)], 'J');
    expect(codeLetters[codeLetterIndex(3000, InspectionLevel.II)], 'K');
    expect(codeLetters[codeLetterIndex(5000, InspectionLevel.I)], 'J');
  });

  test('Known plans, level II', () {
    // Lot 1000 -> J, n=80
    var p = planFor(1000, InspectionLevel.II, 2.5);
    expect([p.sampleSize, p.accept, p.reject], [80, 5, 6]);
    p = planFor(1000, InspectionLevel.II, 4.0);
    expect([p.sampleSize, p.accept, p.reject], [80, 7, 8]);
    p = planFor(1000, InspectionLevel.II, 1.5);
    expect([p.sampleSize, p.accept, p.reject], [80, 3, 4]);
    // Lot 500 -> H, n=50
    p = planFor(500, InspectionLevel.II, 2.5);
    expect([p.sampleSize, p.accept, p.reject], [50, 3, 4]);
    p = planFor(500, InspectionLevel.II, 4.0);
    expect([p.sampleSize, p.accept, p.reject], [50, 5, 6]);
    // Lot 3000 -> K, n=125
    p = planFor(3000, InspectionLevel.II, 2.5);
    expect([p.sampleSize, p.accept, p.reject], [125, 7, 8]);
    // Arrow down: J + 0.65 -> 1/2 with n=80 ; H + 0.65 -> arrow -> J n=80 Ac1
    p = planFor(500, InspectionLevel.II, 0.65);
    expect([p.codeLetter, p.sampleSize, p.accept], ['J', 80, 1]);
    // Arrow up: G (32) + 1.0 -> k=16 down -> H 50 Ac1
    p = planFor(400, InspectionLevel.I, 1.0); // F -> k=15 up -> E n=13 Ac0
    expect([p.codeLetter, p.sampleSize, p.accept], ['E', 13, 0]);
    // Small lot fully inspected
    p = planFor(10, InspectionLevel.II, 0.65);
    expect(p.fullInspection, true);
    expect(p.sampleSize, 10);
  });

  test('Verdict and PDF', () async {
    final i = Inspection(id: '1', date: DateTime(2026, 10, 7), lotSize: 1000, client: 'Société Générale Textile');
    i.defects = [DefectEntry('Couture ouverte', Severity.major, 5), DefectEntry('Fil non coupé', Severity.minor, 8)];
    expect(i.sampleToInspect, 80);
    expect(i.passed(Severity.major), true);
    expect(i.passed(Severity.minor), false);
    expect(i.accepted, false);
    final bytes = await buildReport(i);
    expect(bytes.length, greaterThan(1000));
    File('/tmp/sample_report.pdf').writeAsBytesSync(bytes);
  });

  testWidgets('App opens and creates inspection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AqlApp());
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle inspection'), findsOneWidget);
    await tester.tap(find.text('Nouvelle inspection'));
    await tester.pumpAndSettle();
    expect(find.text('Prélever 50 pièces'), findsOneWidget);
    expect(find.text('LOT ACCEPTÉ'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
