import 'package:pda/config/constants.dart';

class SurveyQuestion {
  final String id;
  final String label;
  final String fieldType;
  final List<String> options;
  final bool required;
  final int displayOrder;

  const SurveyQuestion({
    required this.id,
    required this.label,
    required this.fieldType,
    this.options = const [],
    required this.required,
    required this.displayOrder,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id'] as String,
      label: json['label'] as String,
      fieldType: json['field_type'] as String,
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      required: json['required'] as bool,
      displayOrder: json['display_order'] as int,
    );
  }
}

class Survey {
  final String id;
  final String title;
  final String description;
  final String slug;
  final String visibility;
  final bool isActive;
  final String? linkedEventId;
  final String? createdById;
  final DateTime createdAt;
  final List<SurveyQuestion> questions;
  final int responseCount;

  const Survey({
    required this.id,
    required this.title,
    this.description = '',
    required this.slug,
    this.visibility = PageVisibility.public_,
    this.isActive = true,
    this.linkedEventId,
    this.createdById,
    required this.createdAt,
    this.questions = const [],
    this.responseCount = 0,
  });

  factory Survey.fromJson(Map<String, dynamic> json) {
    return Survey(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      slug: json['slug'] as String,
      visibility: json['visibility'] as String? ?? PageVisibility.public_,
      isActive: json['is_active'] as bool? ?? true,
      linkedEventId: json['linked_event_id'] as String?,
      createdById: json['created_by_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      questions:
          (json['questions'] as List<dynamic>?)
              ?.map((e) => SurveyQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      responseCount: json['response_count'] as int? ?? 0,
    );
  }
}

class SurveyResponse {
  final String id;
  final String? userId;
  final String? userName;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;

  const SurveyResponse({
    required this.id,
    this.userId,
    this.userName,
    required this.answers,
    required this.submittedAt,
  });

  factory SurveyResponse.fromJson(Map<String, dynamic> json) {
    return SurveyResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      answers: json['answers'] as Map<String, dynamic>? ?? {},
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }
}
