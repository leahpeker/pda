import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_flag.freezed.dart';
part 'event_flag.g.dart';

@freezed
abstract class EventFlag with _$EventFlag {
  const factory EventFlag({
    required String id,
    required String eventId,
    required String eventTitle,
    required String flaggedById,
    required String flaggedByName,
    required String reason,
    required String status,
    required DateTime createdAt,
    DateTime? reviewedAt,
  }) = _EventFlag;

  factory EventFlag.fromJson(Map<String, dynamic> json) =>
      _$EventFlagFromJson(json);
}
