/// A bookable clinic branch, as listed for the appointment-booking flow.
class ClinicSummary {
  final int id;
  final String name;
  final String? city;
  final String? logoUrl;

  ClinicSummary({
    required this.id,
    required this.name,
    this.city,
    this.logoUrl,
  });

  factory ClinicSummary.fromJson(Map<String, dynamic> json) => ClinicSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        city: json['city'] as String?,
        logoUrl: json['logo_url'] as String?,
      );
}
