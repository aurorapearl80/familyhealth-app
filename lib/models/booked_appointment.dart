/// The appointment record returned after a successful booking submission.
class BookedAppointment {
  final int id;
  final int clinicId;
  final String location;
  final String type;
  final DateTime scheduledAt;
  final String status;

  BookedAppointment({
    required this.id,
    required this.clinicId,
    required this.location,
    required this.type,
    required this.scheduledAt,
    required this.status,
  });

  factory BookedAppointment.fromJson(Map<String, dynamic> json) => BookedAppointment(
        id: json['id'] as int,
        clinicId: json['clinic_id'] as int,
        location: json['location'] as String,
        type: json['type'] as String,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        status: json['status'] as String,
      );
}
