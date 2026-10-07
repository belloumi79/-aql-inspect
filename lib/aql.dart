/// ISO 2859-1 single sampling plans, normal inspection (Tables I and II-A).
// ignore_for_file: constant_identifier_names
library;

enum InspectionLevel { I, II, III }

const List<String> codeLetters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'R'
];

const List<int> sampleSizes = [
  2, 3, 5, 8, 13, 20, 32, 50, 80, 125, 200, 315, 500, 800, 1250, 2000
];

/// Standard AQL columns of Table II-A (up to 10).
const List<double> aqlColumns = [
  0.010, 0.015, 0.025, 0.040, 0.065, 0.10, 0.15, 0.25, 0.40,
  0.65, 1.0, 1.5, 2.5, 4.0, 6.5, 10.0
];

/// AQL values offered in the app. 0 means zero tolerance.
const List<double> selectableAql = [0, 0.65, 1.0, 1.5, 2.5, 4.0, 6.5];

// Table I: upper lot-size bound -> letter index for levels I, II, III.
const List<List<int>> _tableI = [
  [8, 0, 0, 1],
  [15, 0, 1, 2],
  [25, 1, 2, 3],
  [50, 2, 3, 4],
  [90, 2, 4, 5],
  [150, 3, 5, 6],
  [280, 4, 6, 7],
  [500, 5, 7, 8],
  [1200, 6, 8, 9],
  [3200, 7, 9, 10],
  [10000, 8, 10, 11],
  [35000, 9, 11, 12],
  [150000, 10, 12, 13],
  [500000, 11, 13, 14],
];
const List<int> _tableILast = [12, 14, 15];

int codeLetterIndex(int lotSize, InspectionLevel level) {
  if (lotSize < 2) throw ArgumentError('Lot size must be at least 2');
  for (final row in _tableI) {
    if (lotSize <= row[0]) return row[1 + level.index];
  }
  return _tableILast[level.index];
}

// Table II-A follows a diagonal: the cell depends on letterIndex + aqlIndex.
// null = arrow down, -1 = arrow up, otherwise acceptance number.
const int _up = -1;
int? _cell(int letter, int aqlIdx) {
  final k = letter + aqlIdx;
  if (k < 14) return null;
  const seq = <int?>[0, _up, null, 1, 2, 3, 5, 7, 10, 14, 21];
  if (k - 14 < seq.length) return seq[k - 14];
  return _up;
}

class SamplingPlan {
  final String codeLetter;
  final int sampleSize;
  final int accept;
  final int reject;
  final bool fullInspection;
  const SamplingPlan(this.codeLetter, this.sampleSize, this.accept, this.reject,
      {this.fullInspection = false});

  @override
  String toString() => '$codeLetter n=$sampleSize Ac=$accept Re=$reject';
}

/// Plan for one AQL. For aql == 0 (critical defects) it is zero tolerance on
/// the sample size of the lot's code letter.
SamplingPlan planFor(int lotSize, InspectionLevel level, double aql) {
  final start = codeLetterIndex(lotSize, level);
  if (aql == 0) {
    return _clip(lotSize, SamplingPlan(codeLetters[start], sampleSizes[start], 0, 1));
  }
  final aqlIdx = aqlColumns.indexWhere((a) => (a - aql).abs() < 1e-9);
  if (aqlIdx < 0) throw ArgumentError('Unsupported AQL $aql');
  var letter = start;
  for (var guard = 0; guard < 40; guard++) {
    final c = _cell(letter, aqlIdx);
    if (c == null) {
      if (letter == codeLetters.length - 1) break;
      letter++;
    } else if (c == _up) {
      if (letter == 0) break;
      letter--;
    } else {
      return _clip(lotSize,
          SamplingPlan(codeLetters[letter], sampleSizes[letter], c, c + 1));
    }
  }
  return _clip(lotSize, SamplingPlan(codeLetters[letter], sampleSizes[letter], 0, 1));
}

SamplingPlan _clip(int lotSize, SamplingPlan p) {
  if (p.sampleSize >= lotSize) {
    return SamplingPlan(p.codeLetter, lotSize, p.accept, p.reject,
        fullInspection: true);
  }
  return p;
}
