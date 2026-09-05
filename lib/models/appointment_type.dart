/// A selectable appointment type from the clinic's booking wizard (e.g. "Consultation"),
/// carrying the default duration used to compute available time slots.
class AppointmentType {
  final String key;
  final String label;
  final int durationMinutes;

  AppointmentType({
    required this.key,
    required this.label,
    required this.durationMinutes,
  });

  factory AppointmentType.fromJson(Map<String, dynamic> json) => AppointmentType(
        key: json['key'] as String,
        label: json['label'] as String,
        durationMinutes: json['duration_minutes'] as int,
      );
}
