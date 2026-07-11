import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// 점이 다각형(필지 경계) 내부에 있는지 판정 (ray-casting).
/// poly는 외곽 링의 위경도 좌표 목록.
bool pointInPolygon(LatLng p, List<LatLng> poly) {
  if (poly.length < 3) return false;
  bool inside = false;
  for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i].longitude, yi = poly[i].latitude;
    final xj = poly[j].longitude, yj = poly[j].latitude;
    final intersect = ((yi > p.latitude) != (yj > p.latitude)) &&
        (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

/// 방위각(0~360°, 북=0)을 8방위 한글로 변환.
String bearing8Korean(double bearingDeg) {
  const labels = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
  final normalized = (bearingDeg % 360 + 360) % 360;
  final idx = ((normalized + 22.5) / 45).floor() % 8;
  return labels[idx];
}

/// 나침반 저주파 필터. 359°→0° 경계를 최단경로로 보간한다.
/// prev가 null이면 next를 그대로 반환. alpha는 0~1 (클수록 민감).
double smoothHeading(double? prev, double next, {double alpha = 0.2}) {
  if (prev == null) return (next % 360 + 360) % 360;
  var delta = next - prev;
  while (delta > 180) {
    delta -= 360;
  }
  while (delta < -180) {
    delta += 360;
  }
  final result = prev + delta * alpha;
  return (result % 360 + 360) % 360;
}

/// 두 방위각 사이의 최소 각도차(0~180°). 회전 임계값 판정에 사용.
double angleDelta(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

/// 다각형의 무게중심(근사: 좌표 평균).
LatLng polygonCentroid(List<LatLng> poly) {
  double lat = 0, lng = 0;
  for (final p in poly) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / poly.length, lng / poly.length);
}

/// 거리를 사람이 읽기 쉬운 한글 문자열로 ("23m", "1.2km").
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

/// p1에서 p2를 바라보는 방위각(0~360°, 북=0, 시계방향).
double bearingBetween(LatLng p1, LatLng p2) {
  final lat1 = p1.latitude * math.pi / 180;
  final lat2 = p2.latitude * math.pi / 180;
  final dLng = (p2.longitude - p1.longitude) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final brng = math.atan2(y, x) * 180 / math.pi;
  return (brng % 360 + 360) % 360;
}
