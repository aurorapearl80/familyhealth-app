/// A single bookable time window returned by the available-slots endpoint.
class AppointmentTimeSlot {
  final DateTime startsAt;
  final DateTime endsAt;

  AppointmentTimeSlot({
    required this.startsAt,
    required this.endsAt,
  });

  factory AppointmentTimeSlot.fromJson(Map<String, dynamic> json) => AppointmentTimeSlot(
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
      );
}
