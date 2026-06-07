import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/mission_session.dart';
import 'record_service.dart';

class MissionService {
  final String apiKey;
  final RecordService _recordService;

  MissionService(this.apiKey) : _recordService = RecordService();

  /// 사용자 설명을 GPT에 보내 세션 생성 후 DB 저장
  Future<MissionSession> createSessionFromDescription(String description) async {
    String mode = 'fast';
    List<String> statusButtons = ['양호', '보통', '불량'];
    List<String> fields = [];

    try {
      final response = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'max_tokens': 200,
              'messages': [
                {
                  'role': 'system',
                  'content': '''당신은 농업현장점검 앱의 작업 설정 도우미입니다.
사용자가 오늘 작업을 설명하면 JSON으로 응답하세요.

응답 형식:
{
  "mode": "precise" 또는 "fast",
  "statusButtons": ["버튼1", "버튼2", "버튼3"],
  "fields": ["필드1", "필드2", "필드3"]
}

규칙:
- 스팟이 적고 상세 기록이 필요하면 mode="precise", fields를 채우고 statusButtons=[]
- 스팟이 많고 빠른 기록이 필요하면 mode="fast", statusButtons를 채우고 fields=[]
- precise: fields는 2~5개, 현장에서 기록해야 할 항목 이름
- fast: statusButtons는 3~4개, 빠르게 선택할 수 있는 상태 레이블
- 응답은 반드시 유효한 JSON만, 마크다운 없이''',
                },
                {
                  'role': 'user',
                  'content': description,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        final parsed = jsonDecode(content) as Map<String, dynamic>;

        mode = (parsed['mode'] as String?) ?? 'fast';
        statusButtons = List<String>.from(parsed['statusButtons'] as List? ?? []);
        fields = List<String>.from(parsed['fields'] as List? ?? []);
      }
    } catch (_) {
      // 파싱 실패 또는 네트워크 오류 시 기본값 유지
    }

    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final session = MissionSession(
      date: today,
      mode: mode,
      purpose: description,
      fields: fields,
      statusButtons: statusButtons,
      createdAt: now,
    );

    return _recordService.insertSession(session);
  }

  /// 오늘 활성 세션 조회 (없으면 null)
  Future<MissionSession?> getActiveSession() async {
    return _recordService.getTodaySession();
  }

  /// 최근 세션 3개를 템플릿으로 조회
  Future<List<MissionSession>> getRecentTemplates() async {
    return _recordService.getRecentSessions(3);
  }

  /// 기존 세션을 오늘 날짜로 복제해서 새 세션 저장 (템플릿 재사용)
  Future<MissionSession> reuseSession(MissionSession template) async {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final newSession = template.copyWith(
      id: null,
      date: today,
      createdAt: now,
    );

    return _recordService.insertSession(newSession);
  }
}
