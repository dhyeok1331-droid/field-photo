import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:field_photo_app/utils/geo_utils.dart';

void main() {
  // 단순 사각형 필지 (위도 36.0~36.001, 경도 126.0~126.001)
  final square = [
    const LatLng(36.000, 126.000),
    const LatLng(36.000, 126.001),
    const LatLng(36.001, 126.001),
    const LatLng(36.001, 126.000),
  ];

  group('pointInPolygon', () {
    test('내부 점은 true', () {
      expect(pointInPolygon(const LatLng(36.0005, 126.0005), square), isTrue);
    });
    test('외부 점은 false', () {
      expect(pointInPolygon(const LatLng(36.002, 126.0005), square), isFalse);
    });
    test('좌표가 3개 미만이면 false', () {
      expect(pointInPolygon(const LatLng(36.0, 126.0), []), isFalse);
    });
  });

  group('bearing8Korean', () {
    test('0도는 북', () => expect(bearing8Korean(0), '북'));
    test('45도는 북동', () => expect(bearing8Korean(45), '북동'));
    test('90도는 동', () => expect(bearing8Korean(90), '동'));
    test('180도는 남', () => expect(bearing8Korean(180), '남'));
    test('350도는 북', () => expect(bearing8Korean(350), '북'));
    test('음수 정규화', () => expect(bearing8Korean(-90), '서'));
  });

  group('smoothHeading', () {
    test('prev가 null이면 next 반환', () {
      expect(smoothHeading(null, 90), 90);
    });
    test('동일값이면 그대로', () {
      expect(smoothHeading(100, 100), closeTo(100, 0.001));
    });
    test('359→1 경계를 최단경로로 보간 (증가 방향)', () {
      // 359에서 1로: +2도 변화, alpha 0.5면 360→0 근처
      final r = smoothHeading(359, 1, alpha: 0.5);
      expect(r, closeTo(0, 0.001));
    });
    test('결과는 항상 0~360', () {
      final r = smoothHeading(10, 350, alpha: 0.5);
      expect(r, inInclusiveRange(0, 360));
    });
  });

  group('angleDelta', () {
    test('같으면 0', () => expect(angleDelta(90, 90), 0));
    test('경계 넘는 차이 최소화', () => expect(angleDelta(359, 1), closeTo(2, 0.001)));
    test('최대 180', () => expect(angleDelta(0, 180), 180));
  });

  group('bearingBetween', () {
    test('정북 방향 ≈ 0도', () {
      final b = bearingBetween(
          const LatLng(36.0, 126.0), const LatLng(36.01, 126.0));
      expect(b, closeTo(0, 1));
    });
    test('정동 방향 ≈ 90도', () {
      final b = bearingBetween(
          const LatLng(36.0, 126.0), const LatLng(36.0, 126.01));
      expect(b, closeTo(90, 1));
    });
  });

  group('formatDistance', () {
    test('1000 미만은 m', () => expect(formatDistance(23.4), '23m'));
    test('1000 이상은 km', () => expect(formatDistance(1200), '1.2km'));
  });

  group('polygonCentroid', () {
    test('사각형 중심', () {
      final c = polygonCentroid(square);
      expect(c.latitude, closeTo(36.0005, 0.0001));
      expect(c.longitude, closeTo(126.0005, 0.0001));
    });
  });
}
