import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'booking.freezed.dart';
part 'booking.g.dart';

@freezed
class Booking with _$Booking {
  const factory Booking({
    required String id,
    @JsonKey(name: 'leg_id') required String legId,
    required String type,
    required String name,
    required String status,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'end_date') String? endDate,
    String? confirmation,
    @JsonKey(name: 'cost_cents') int? costCents,
    @Default('USD') String currency,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'location_lat') double? locationLat,
    @JsonKey(name: 'location_lon') double? locationLon,
    String? notes,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);
}

extension BookingX on Booking {
  DateTime? get startDateTime =>
      startDate == null ? null : DateTime.tryParse(startDate!);
  DateTime? get endDateTime =>
      endDate == null ? null : DateTime.tryParse(endDate!);

  String get formattedCost {
    if (costCents == null) return '';
    final dollars = costCents! / 100.0;
    final f = NumberFormat.currency(
      name: currency,
      symbol: _symbolFor(currency),
      decimalDigits: 2,
    );
    return f.format(dollars);
  }

  String _symbolFor(String code) {
    switch (code) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$code ';
    }
  }
}
