import 'aql.dart';

enum Severity { critical, major, minor }

const severityLabel = {
  Severity.critical: 'Critique',
  Severity.major: 'Majeur',
  Severity.minor: 'Mineur',
};

/// Common garment defects (French), with their usual severity.
const Map<String, Severity> defectCatalog = {
  'Aiguille / objet métallique': Severity.critical,
  'Trou / déchirure': Severity.major,
  'Couture ouverte / sautée': Severity.major,
  'Mesure hors tolérance': Severity.major,
  'Tache visible': Severity.major,
  'Nuance / différence de teinte': Severity.major,
  'Étiquette manquante ou erronée': Severity.major,
  'Accessoire défectueux (bouton, zip)': Severity.major,
  'Point irrégulier': Severity.minor,
  'Fil non coupé': Severity.minor,
  'Repassage / pli': Severity.minor,
  'Petite tache': Severity.minor,
  'Emballage / pliage non conforme': Severity.minor,
};

class DefectEntry {
  String name;
  Severity severity;
  int count;
  DefectEntry(this.name, this.severity, this.count);

  Map<String, dynamic> toJson() =>
      {'name': name, 'severity': severity.name, 'count': count};
  factory DefectEntry.fromJson(Map<String, dynamic> j) => DefectEntry(
      j['name'] as String,
      Severity.values.byName(j['severity'] as String),
      j['count'] as int);
}

class Inspection {
  final String id;
  DateTime date;
  String inspector;
  String client;
  String order;
  String style;
  int lotSize;
  InspectionLevel level;
  double aqlCritical;
  double aqlMajor;
  double aqlMinor;
  List<DefectEntry> defects;
  String notes;

  Inspection({
    required this.id,
    required this.date,
    this.inspector = '',
    this.client = '',
    this.order = '',
    this.style = '',
    this.lotSize = 500,
    this.level = InspectionLevel.II,
    this.aqlCritical = 0,
    this.aqlMajor = 2.5,
    this.aqlMinor = 4.0,
    List<DefectEntry>? defects,
    this.notes = '',
  }) : defects = defects ?? [];

  double aqlOf(Severity s) => switch (s) {
        Severity.critical => aqlCritical,
        Severity.major => aqlMajor,
        Severity.minor => aqlMinor,
      };

  SamplingPlan plan(Severity s) => planFor(lotSize, level, aqlOf(s));

  /// Pieces to pull: the largest sample among the three plans.
  int get sampleToInspect =>
      Severity.values.map((s) => plan(s).sampleSize).reduce((a, b) => a > b ? a : b);

  int found(Severity s) =>
      defects.where((d) => d.severity == s).fold(0, (t, d) => t + d.count);

  bool passed(Severity s) => found(s) <= plan(s).accept;

  bool get accepted => Severity.values.every(passed);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'inspector': inspector,
        'client': client,
        'order': order,
        'style': style,
        'lotSize': lotSize,
        'level': level.name,
        'aqlCritical': aqlCritical,
        'aqlMajor': aqlMajor,
        'aqlMinor': aqlMinor,
        'defects': defects.map((d) => d.toJson()).toList(),
        'notes': notes,
      };

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        inspector: j['inspector'] as String? ?? '',
        client: j['client'] as String? ?? '',
        order: j['order'] as String? ?? '',
        style: j['style'] as String? ?? '',
        lotSize: j['lotSize'] as int,
        level: InspectionLevel.values.byName(j['level'] as String),
        aqlCritical: (j['aqlCritical'] as num).toDouble(),
        aqlMajor: (j['aqlMajor'] as num).toDouble(),
        aqlMinor: (j['aqlMinor'] as num).toDouble(),
        defects: (j['defects'] as List)
            .map((e) => DefectEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        notes: j['notes'] as String? ?? '',
      );
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtAql(double a) => a == 0 ? '0 (zéro défaut)' : a.toString();
