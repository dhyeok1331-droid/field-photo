import 'dart:convert';

class FieldRecord {
  final int? id;
  final int sessionId;
  final DateTime timestamp;
  final String address;
  final String jimok;
  final double? lat;
  final double? lng;
  final String imagePath;
  final Map<String, String> memoData;
  final String? aiAnalysis;

  const FieldRecord({
    this.id,
    required this.sessionId,
    required this.timestamp,
    required this.address,
    required this.jimok,
    this.lat,
    this.lng,
    required this.imagePath,
    required this.memoData,
    this.aiAnalysis,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
      'jimok': jimok,
      'lat': lat,
      'lng': lng,
      'imagePath': imagePath,
      'memoData': jsonEncode(memoData),
      'aiAnalysis': aiAnalysis,
    };
  }

  factory FieldRecord.fromMap(Map<String, dynamic> map) {
    return FieldRecord(
      id: map['id'] as int?,
      sessionId: map['sessionId'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      address: map['address'] as String,
      jimok: map['jimok'] as String,
      lat: map['lat'] as double?,
      lng: map['lng'] as double?,
      imagePath: map['imagePath'] as String,
      memoData: Map<String, String>.from(
        jsonDecode(map['memoData'] as String) as Map,
      ),
      aiAnalysis: map['aiAnalysis'] as String?,
    );
  }

  FieldRecord copyWith({
    int? id,
    int? sessionId,
    DateTime? timestamp,
    String? address,
    String? jimok,
    double? lat,
    double? lng,
    String? imagePath,
    Map<String, String>? memoData,
    String? aiAnalysis,
  }) {
    return FieldRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      jimok: jimok ?? this.jimok,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      imagePath: imagePath ?? this.imagePath,
      memoData: memoData ?? this.memoData,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
    );
  }

  String get statusLabel => memoData['상태'] ?? '';

  String get memoSummary => memoData.values.join(', ');
}
