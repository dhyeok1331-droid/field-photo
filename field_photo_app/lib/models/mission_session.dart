import 'dart:convert';

class MissionSession {
  final int? id;
  final String date;
  final String mode;
  final String purpose;
  final List<String> fields;
  final List<String> statusButtons;
  final DateTime createdAt;

  const MissionSession({
    this.id,
    required this.date,
    required this.mode,
    required this.purpose,
    required this.fields,
    required this.statusButtons,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'mode': mode,
      'purpose': purpose,
      'fields': jsonEncode(fields),
      'statusButtons': jsonEncode(statusButtons),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MissionSession.fromMap(Map<String, dynamic> map) {
    return MissionSession(
      id: map['id'] as int?,
      date: map['date'] as String,
      mode: map['mode'] as String,
      purpose: map['purpose'] as String,
      fields: List<String>.from(jsonDecode(map['fields'] as String)),
      statusButtons: List<String>.from(jsonDecode(map['statusButtons'] as String)),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  MissionSession copyWith({
    int? id,
    String? date,
    String? mode,
    String? purpose,
    List<String>? fields,
    List<String>? statusButtons,
    DateTime? createdAt,
  }) {
    return MissionSession(
      id: id ?? this.id,
      date: date ?? this.date,
      mode: mode ?? this.mode,
      purpose: purpose ?? this.purpose,
      fields: fields ?? this.fields,
      statusButtons: statusButtons ?? this.statusButtons,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isActive {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return date == today;
  }
}
