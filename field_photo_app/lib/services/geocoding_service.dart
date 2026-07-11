import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/parcel_info.dart';

class GeocodingService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<ParcelInfo> reverseGeocode(double lat, double lng) async {
    final key = await _storage.read(key: 'vworld_api_key') ?? '';
    if (key.isEmpty) {
      return const ParcelInfo(address: 'VWorld 키 미설정 (설정화면 확인)', jimok: '');
    }
    final uri = Uri.parse(
      'https://api.vworld.kr/req/address'
      '?service=address&request=getAddress&version=2.0'
      '&crs=epsg:4326&format=json&type=parcel&zipcode=false&simple=false'
      '&point=$lng,$lat&key=$key',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return const ParcelInfo(address: '주소 조회 실패', jimok: '');
      }

      final data = jsonDecode(response.body);
      final status = data['response']['status'];
      if (status != 'OK') {
        return const ParcelInfo(address: '주소 없음', jimok: '');
      }

      final results = data['response']['result'] as List?;
      if (results == null || results.isEmpty) {
        return const ParcelInfo(address: '주소 없음', jimok: '');
      }

      final r = results[0];
      final address = r['text'] as String? ?? '';
      final jimok = (r['structure'] != null)
          ? (r['structure']['level4L'] as String? ?? '')
          : '';

      return ParcelInfo(address: address, jimok: jimok, lat: lat, lng: lng);
    } catch (e) {
      return ParcelInfo(address: '조회 오류: $e', jimok: '');
    }
  }

  /// 탭한 지점이 속한 필지의 경계 폴리곤(외곽 링)을 반환.
  /// VWorld 데이터API(연속지적도) 권한이 없거나 실패하면 null → 경계선만 생략된다.
  Future<List<LatLng>?> fetchParcelBoundary(double lat, double lng) async {
    final key = await _storage.read(key: 'vworld_api_key') ?? '';
    if (key.isEmpty) return null;

    final uri = Uri.parse(
      'https://api.vworld.kr/req/data'
      '?service=data&version=2.0&request=GetFeature'
      '&data=LP_PA_CBND_BUBUN&key=$key&domain=com.fieldphoto.field_photo_app'
      '&geomFilter=POINT($lng $lat)&format=json&crs=EPSG:4326'
      '&geometry=true&attribute=false&size=1',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['response']?['status'] != 'OK') return null;

      final features =
          data['response']?['result']?['featureCollection']?['features']
              as List?;
      if (features == null || features.isEmpty) return null;

      final geometry = features[0]['geometry'];
      final type = geometry?['type'] as String?;
      final coords = geometry?['coordinates'] as List?;
      if (coords == null) return null;

      // Polygon: coords[0] = 외곽 링 / MultiPolygon: coords[0][0] = 외곽 링
      final List ring = type == 'MultiPolygon'
          ? (coords[0] as List)[0] as List
          : coords[0] as List;

      return ring
          .map<LatLng>((p) => LatLng(
                (p[1] as num).toDouble(),
                (p[0] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
