import 'package:freezed_annotation/freezed_annotation.dart';

part 'grounding.freezed.dart';
part 'grounding.g.dart';

/// Grounding payload sent with every chat query.
/// Mirrors §4 of the spec: GPS + clock + Trip HQ state + calendar.
@freezed
class Grounding with _$Grounding {
  const factory Grounding({
    @JsonKey(name: 'gps_lat') double? gpsLat,
    @JsonKey(name: 'gps_lon') double? gpsLon,
    @JsonKey(name: 'gps_accuracy_m') double? gpsAccuracyM,
    @JsonKey(name: 'local_time_iso') required String localTimeIso,
    String? timezone,
    @JsonKey(name: 'current_leg_id') String? currentLegId,
    @JsonKey(name: 'current_leg_slug') String? currentLegSlug,
    @JsonKey(name: 'current_trip_id') String? currentTripId,
    @JsonKey(name: 'next_booking_id') String? nextBookingId,
  }) = _Grounding;

  factory Grounding.fromJson(Map<String, dynamic> json) =>
      _$GroundingFromJson(json);
}
