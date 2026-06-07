import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OpenAiService {
  final String apiKey;

  OpenAiService(this.apiKey);

  Future<String> analyzeFieldPhoto({
    required String imagePath,
    required double lat,
    required double lng,
    required String currentAddress,
    required String jimok,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final prompt = '''이 사진은 농업현장점검을 위해 GPS 좌표 (위도: $lat, 경도: $lng) 에서 촬영된 현장 사진입니다.
현재 역지오코딩으로 확인된 주소: $currentAddress${jimok.isNotEmpty ? ' ($jimok)' : ''}

사진을 분석하여 다음 정보를 한국어로 답변해 주세요:
1. 현재 GPS 주소가 정확한지 확인 (정확/부정확 여부)
2. 사진에 보이는 작물 또는 토지 이용 현황
3. 특이사항 또는 추가 확인이 필요한 내용

간결하게 2-3문장으로 답변해 주세요.''';

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'max_tokens': 500,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
                'detail': 'low',
              },
            },
            {
              'type': 'text',
              'text': prompt,
            },
          ],
        },
      ],
    });

    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'API 오류 ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'] as String;
  }
}
