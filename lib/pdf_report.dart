import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'aql.dart';
import 'models.dart';

Future<Uint8List> buildReport(Inspection i) async {
  final base = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  final doc = pw.Document(
      title: 'Rapport AQL ${i.order}',
      theme: pw.ThemeData.withFont(base: base, bold: bold));
  final ok = i.accepted;
  final levelName = 'Général ${i.level.name}';

  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.SizedBox(width: 130, child: pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(v.isEmpty ? '-' : v)),
        ]),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (ctx) => [
      pw.Text("Rapport d'inspection finale AQL",
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text('ISO 2859-1, échantillonnage simple, contrôle normal',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        color: ok ? PdfColors.green100 : PdfColors.red100,
        child: pw.Text(ok ? 'RÉSULTAT : LOT ACCEPTÉ' : 'RÉSULTAT : LOT REFUSÉ',
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: ok ? PdfColors.green900 : PdfColors.red900)),
      ),
      pw.SizedBox(height: 12),
      kv('Date', fmtDate(i.date)),
      kv('Client', i.client),
      kv('Commande', i.order),
      kv('Article / style', i.style),
      kv('Inspecteur', i.inspector),
      kv('Taille du lot', '${i.lotSize} pièces'),
      kv("Niveau d'inspection", levelName),
      kv('Pièces inspectées', '${i.sampleToInspect}'),
      pw.SizedBox(height: 14),
      pw.Text("Plan d'échantillonnage et résultats",
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Défauts', 'AQL', 'Lettre', 'n', 'Ac', 'Re', 'Trouvés', 'Verdict'],
        data: Severity.values.map((s) {
          final SamplingPlan p = i.plan(s);
          return [
            severityLabel[s]!,
            fmtAql(i.aqlOf(s)),
            p.codeLetter,
            '${p.sampleSize}${p.fullInspection ? ' (100%)' : ''}',
            '${p.accept}',
            '${p.reject}',
            '${i.found(s)}',
            i.passed(s) ? 'Conforme' : 'Non conforme',
          ];
        }).toList(),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 14),
      pw.Text('Détail des défauts',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      if (i.defects.where((d) => d.count > 0).isEmpty)
        pw.Text('Aucun défaut relevé.')
      else
        pw.TableHelper.fromTextArray(
          headers: ['Défaut', 'Gravité', 'Quantité'],
          data: i.defects
              .where((d) => d.count > 0)
              .map((d) => [d.name, severityLabel[d.severity]!, '${d.count}'])
              .toList(),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      if (i.notes.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text('Observations', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Text(i.notes),
      ],
      pw.SizedBox(height: 40),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Signature inspecteur : ____________'),
        pw.Text('Signature client : ____________'),
      ]),
    ],
  ));
  return doc.save();
}
