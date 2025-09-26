/// Parses a line like:
/// "Supun - x=2 => y=3 => z=2,3,4,27,372,23,23"
/// or "x=2 y=3 z=2 3 4 27 372 23 23"
/// Returns (thickness, length, widths) or null on failure.
List<double>? _parseWidths(String z) {
  final parts = z.split(RegExp(r'[,\s]+')).where((e) => e.trim().isNotEmpty);
  final values = <double>[];
  for (final p in parts) {
    final v = double.tryParse(p);
    if (v != null) values.add(v);
  }
  return values;
}

(double, double, List<double>)? parseQuickEntry(String input) {
  final text = input.toLowerCase();
  // Extract x=, y=, z= sections
  final rx = RegExp(r'x\s*=\s*([0-9]+(?:\.[0-9]+)?)');
  final ry = RegExp(r'y\s*=\s*([0-9]+(?:\.[0-9]+)?)');
  final rz = RegExp(r'z\s*=\s*([0-9,\s\.]+)');
  final mx = rx.firstMatch(text);
  final my = ry.firstMatch(text);
  final mz = rz.firstMatch(text);
  if (mx == null || my == null || mz == null) return null;
  final x = double.tryParse(mx.group(1)!);
  final y = double.tryParse(my.group(1)!);
  final widths = _parseWidths(mz.group(1)!);
  if (x == null || y == null || widths == null || widths.isEmpty) return null;
  return (x, y, widths);
}
