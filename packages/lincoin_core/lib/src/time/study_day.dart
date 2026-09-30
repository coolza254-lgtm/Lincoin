/// A study day starts at [dayStartHour] local time instead of midnight, so a
/// session at 01:00 still counts toward the previous day.
library;

/// Days since 1970-01-01 of the study day containing [utc].
///
/// [tzOffsetMinutes] is the local offset from UTC at the time of the event
/// (stored with every log row so travel does not reshuffle history).
int studyDayNumber(
  DateTime utc, {
  required int tzOffsetMinutes,
  int dayStartHour = 4,
}) {
  if (!utc.isUtc) {
    throw ArgumentError.value(utc, 'utc', 'must be a UTC DateTime');
  }
  final shifted =
      utc.add(Duration(minutes: tzOffsetMinutes - dayStartHour * 60));
  final date = DateTime.utc(shifted.year, shifted.month, shifted.day);
  return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

/// ISO date (YYYY-MM-DD) for a day number from [studyDayNumber].
String studyDayIso(int dayNumber) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    dayNumber * Duration.millisecondsPerDay,
    isUtc: true,
  );
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}
