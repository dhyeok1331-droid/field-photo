import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
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
}
