import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'aql.dart';
import 'models.dart';
import 'pdf_report.dart';
import 'storage.dart';

void main() => runApp(const AqlApp());

class AqlApp extends StatelessWidget {
  const AqlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspection AQL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F5FA8), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final store = InspectionStore();
  List<Inspection> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await store.load();
    setState(() {
      items = list;
      loading = false;
    });
  }

  Future<void> _open(Inspection? existing) async {
    final insp = existing ??
        Inspection(id: DateTime.now().microsecondsSinceEpoch.toString(), date: DateTime.now());
    final saved = await Navigator.push<Inspection>(
        context, MaterialPageRoute(builder: (_) => InspectionPage(inspection: insp)));
    if (saved == null) return;
    final idx = items.indexWhere((e) => e.id == saved.id);
    if (idx >= 0) {
      items[idx] = saved;
    } else {
      items.insert(0, saved);
    }
    await store.saveAll(items);
    setState(() {});
  }

  Future<void> _delete(Inspection i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cette inspection ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    items.removeWhere((e) => e.id == i.id);
    await store.saveAll(items);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspections AQL')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(null),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle inspection'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('Aucune inspection.\nAppuyez sur « Nouvelle inspection ».', textAlign: TextAlign.center))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, n) {
                    final i = items[n];
                    return ListTile(
                      leading: Icon(i.accepted ? Icons.check_circle : Icons.cancel,
                          color: i.accepted ? Colors.green : Colors.red),
                      title: Text('${i.client.isEmpty ? 'Client ?' : i.client} · ${i.order.isEmpty ? 'Commande ?' : i.order}'),
                      subtitle: Text('${fmtDate(i.date)} · lot ${i.lotSize} · ${i.style}'),
                      onTap: () => _open(i),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(i)),
                    );
                  },
                ),
    );
  }
}

class InspectionPage extends StatefulWidget {
  final Inspection inspection;
  const InspectionPage({super.key, required this.inspection});
  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  late Inspection i;

  @override
  void initState() {
    super.initState();
    i = Inspection.fromJson(widget.inspection.toJson()); // edit a copy
    if (i.defects.isEmpty) {
      i.defects = defectCatalog.entries.map((e) => DefectEntry(e.key, e.value, 0)).toList();
    }
  }

  Widget _text(String label, String value, ValueChanged<String> onChanged,
      {bool number = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: value,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  Widget _aqlPicker(String label, double value, ValueChanged<double> onChanged) {
    return Expanded(
      child: DropdownButtonFormField<double>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: selectableAql
            .map((a) => DropdownMenuItem(value: a, child: Text(a == 0 ? '0' : a.toString())))
            .toList(),
        onChanged: (v) => setState(() => onChanged(v!)),
      ),
    );
  }

  Future<void> _addDefect() async {
    final ctrl = TextEditingController();
    var sev = Severity.major;
    final res = await showDialog<DefectEntry>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Autre défaut'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            SegmentedButton<Severity>(
              segments: Severity.values
                  .map((s) => ButtonSegment(value: s, label: Text(severityLabel[s]!)))
                  .toList(),
              selected: {sev},
              onSelectionChanged: (v) => set(() => sev = v.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
            FilledButton(
                onPressed: () => ctrl.text.trim().isEmpty
                    ? null
                    : Navigator.pop(c, DefectEntry(ctrl.text.trim(), sev, 1)),
                child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (res != null) setState(() => i.defects.add(res));
  }

  Future<void> _pdf() async {
    final bytes = await buildReport(i);
    final name = 'AQL_${i.order.isEmpty ? i.id : i.order}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  }

  @override
  Widget build(BuildContext context) {
    final valid = i.lotSize >= 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection'),
        actions: [
          IconButton(
              tooltip: 'Rapport PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: valid ? _pdf : null),
          TextButton(
              onPressed: valid ? () => Navigator.pop(context, i) : null,
              child: const Text('Enregistrer')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Commande'),
          _text('Client', i.client, (v) => i.client = v),
          _text('N° de commande', i.order, (v) => i.order = v),
          _text('Article / style', i.style, (v) => i.style = v),
          _text('Inspecteur', i.inspector, (v) => i.inspector = v),
          _section("Plan d'échantillonnage"),
          _text('Taille du lot (pièces)', '${i.lotSize}',
              (v) => setState(() => i.lotSize = int.tryParse(v) ?? 0),
              number: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SegmentedButton<InspectionLevel>(
              segments: InspectionLevel.values
                  .map((l) => ButtonSegment(value: l, label: Text('Niveau ${l.name}')))
                  .toList(),
              selected: {i.level},
              onSelectionChanged: (v) => setState(() => i.level = v.first),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            _aqlPicker('AQL critique', i.aqlCritical, (v) => i.aqlCritical = v),
            const SizedBox(width: 8),
            _aqlPicker('AQL majeur', i.aqlMajor, (v) => i.aqlMajor = v),
            const SizedBox(width: 8),
            _aqlPicker('AQL mineur', i.aqlMinor, (v) => i.aqlMinor = v),
          ]),
          const SizedBox(height: 12),
          if (valid) _planCard() else const Text('Saisissez une taille de lot (2 pièces minimum).'),
          _section('Défauts relevés'),
          for (final d in i.defects) _defectRow(d),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: _addDefect, icon: const Icon(Icons.add), label: const Text('Autre défaut')),
          ),
          _section('Observations'),
          _text('Notes', i.notes, (v) => i.notes = v, lines: 3),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _planCard() {
    final ok = i.accepted;
    return Card(
      color: ok ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Prélever ${i.sampleToInspect} pièces',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final s in Severity.values)
            Builder(builder: (_) {
              final p = i.plan(s);
              return Text(
                  '${severityLabel[s]} : lettre ${p.codeLetter}, n=${p.sampleSize}, '
                  'accepter ≤ ${p.accept}, refuser ≥ ${p.reject} · trouvés ${i.found(s)} '
                  '${i.passed(s) ? '✓' : '✗'}');
            }),
          const SizedBox(height: 8),
          Text(ok ? 'LOT ACCEPTÉ' : 'LOT REFUSÉ',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: ok ? Colors.green.shade800 : Colors.red.shade800)),
        ]),
      ),
    );
  }

  Widget _defectRow(DefectEntry d) {
    final color = switch (d.severity) {
      Severity.critical => Colors.red,
      Severity.major => Colors.orange,
      Severity.minor => Colors.blueGrey,
    };
    return Row(children: [
      Container(width: 6, height: 32, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text('${d.name}\n${severityLabel[d.severity]}', style: const TextStyle(fontSize: 13))),
      IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: d.count > 0 ? () => setState(() => d.count--) : null),
      SizedBox(width: 28, child: Text('${d.count}', textAlign: TextAlign.center)),
      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => d.count++)),
    ]);
  }
}
