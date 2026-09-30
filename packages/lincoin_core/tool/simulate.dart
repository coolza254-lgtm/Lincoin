// Prints expected daily review load for common settings.
// Usage: dart run tool/simulate.dart
import 'package:lincoin_core/lincoin_core.dart';

void main() {
  print(
      'retention  new/day  | avg reviews/day: d1-30  d31-90  d91-365  d366-730 | real retention');
  for (final dr in [0.85, 0.90, 0.95]) {
    for (final n in [10, 15, 20]) {
      final r = simulateWorkload(
          config: SrsConfig(desiredRetention: dr), days: 730, newPerDay: n);
      String f(double v) => v.toStringAsFixed(0).padLeft(6);
      print('${dr.toStringAsFixed(2)}       ${n.toString().padLeft(2)}      |'
          '                 ${f(r.averageReviews(0, 30))}  ${f(r.averageReviews(30, 90))}'
          '  ${f(r.averageReviews(90, 365))}  ${f(r.averageReviews(365, 730))}   | '
          '${(r.retention * 100).toStringAsFixed(1)}%');
    }
  }
}
