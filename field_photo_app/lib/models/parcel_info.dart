class ParcelInfo {
  final String address;
  final String jimok;
  final double? lat;
  final double? lng;

  const ParcelInfo({
    required this.address,
    required this.jimok,
    this.lat,
    this.lng,
  });

  ParcelInfo copyWith({
    String? address,
    String? jimok,
    double? lat,
    double? lng,
  }) {
    return ParcelInfo(
      address: address ?? this.address,
      jimok: jimok ?? this.jimok,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  String get displayText =>
      address + (jimok.isNotEmpty ? ' | $jimok' : '');

  bool get isEmpty => address.isEmpty;
}
