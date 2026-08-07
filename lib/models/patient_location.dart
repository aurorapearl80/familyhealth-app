/// A single GPS fix for a patient, from `GET /api/admin/patients/{patient}/locations/latest`.
class PatientLocation {
  final int id;
  final double latitude;
  final double longitude;
  final int? accuracyMeters;
  final double? altitude;
  final double? speed;
  final double? heading;
  final String source;
  final DateTime recordedAt;

  const PatientLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitude,
    this.speed,
    this.heading,
    required this.source,
    required this.recordedAt,
  });

  factory PatientLocation.fromJson(Map<String, dynamic> json) {
    return PatientLocation(
      id: json['id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: json['accuracy_meters'] as int?,
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      source: json['source'] as String? ?? 'foreground',
      recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
