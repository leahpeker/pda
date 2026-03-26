class JoinRequest {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String email;
  final String pronouns;
  final String howTheyHeard;
  final String whyJoin;
  final DateTime submittedAt;
  final String status; // pending, approved, rejected

  const JoinRequest({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.email,
    required this.pronouns,
    required this.howTheyHeard,
    required this.whyJoin,
    required this.submittedAt,
    required this.status,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String? ?? '',
      pronouns: json['pronouns'] as String,
      howTheyHeard: json['how_they_heard'] as String,
      whyJoin: json['why_join'] as String,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      status: json['status'] as String,
    );
  }
}
