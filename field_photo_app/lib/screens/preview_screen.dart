import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/field_record.dart';
import '../models/mission_session.dart';
import '../models/parcel_info.dart';
import '../services/openai_service.dart';
import '../services/photo_service.dart';
import '../services/record_service.dart';
import '../services/voice_service.dart';
import '../widgets/voice_memo_widget.dart';
import 'settings_screen.dart';

class PreviewScreen extends StatefulWidget {
  final String imagePath;
  final ParcelInfo parcel;
  final MissionSession? session;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.parcel,
    this.session,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  static const _navy = Color(0xFF1B2D45);
  static const _accent = Color(0xFF4EA8DE);
  static const _surface = Color(0xFF162234);
  static const _border = Color(0x264EA8DE);

  final _photoService = PhotoService();
  final _recordService = RecordService();

  Uint8List? _watermarkedBytes;
  bool _buildingPreview = true;
  bool _saving = false;
  bool _analyzing = false;
  String? _aiResult;
  String? _saveError;

  // 정밀 모드 동적 필드
  final Map<String, String> _memoData = {};
  final Map<String, TextEditingController> _memoControllers = {};

  // 음성 메모
  VoiceService? _voiceService;

  @override
  void initState() {
    super.initState();
    _buildPreview();
    _initMemoFields();
    _initVoiceService();
  }

  void _initMemoFields() {
    final session = widget.session;
    if (session == null || session.mode != 'precise') return;
    for (final field in session.fields) {
      _memoControllers[field] = TextEditingController();
    }
  }

  Future<void> _initVoiceService() async {
    final apiKey = await SettingsScreen.getOpenAiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      _voiceService = VoiceService(apiKey);
    }
  }

  @override
  void dispose() {
    for (final c in _memoControllers.values) {
      c.dispose();
    }
    _voiceService?.dispose();
    super.dispose();
  }

  Future<void> _buildPreview() async {
    try {
      final bytes = await _photoService.buildWatermarkedJpeg(
        imagePath: widget.imagePath,
        address: widget.parcel.address,
        jimok: widget.parcel.jimok,
      );
      if (mounted) {
        setState(() {
          _watermarkedBytes = bytes;
          _buildingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _buildingPreview = false);
    }
  }

  Future<void> _save() async {
    if (_watermarkedBytes == null) return;
    setState(() => _saving = true);

    // 현재 메모 컨트롤러 값 수집
    for (final entry in _memoControllers.entries) {
      _memoData[entry.key] = entry.value.text.trim();
    }

    try {
      final savedPath = await _photoService.saveJpegToGallery(_watermarkedBytes!);

      // 세션이 있으면 RecordService에 기록
      final session = widget.session;
      if (session != null && session.id != null) {
        final record = FieldRecord(
          sessionId: session.id!,
          timestamp: DateTime.now(),
          address: widget.parcel.address,
          jimok: widget.parcel.jimok,
          lat: widget.parcel.lat,
          lng: widget.parcel.lng,
          imagePath: savedPath,
          memoData: Map<String, String>.from(_memoData),
        );
        await _recordService.insertRecord(record);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.toString();
        });
      }
    }
  }

  Future<void> _analyzeWithAi() async {
    final apiKey = await SettingsScreen.getOpenAiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _showNoKeyDialog();
      return;
    }

    setState(() {
      _analyzing = true;
      _aiResult = null;
    });

    try {
      final service = OpenAiService(apiKey);
      final result = await service.analyzeFieldPhoto(
        imagePath: widget.imagePath,
        lat: widget.parcel.lat ?? 0,
        lng: widget.parcel.lng ?? 0,
        currentAddress: widget.parcel.address,
        jimok: widget.parcel.jimok,
      );
      if (mounted) setState(() => _aiResult = result);
    } catch (e) {
      if (mounted) setState(() => _aiResult = '오류: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _parseVoiceToMemo(String voiceText) async {
    final apiKey = await SettingsScreen.getOpenAiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    final fields = widget.session!.fields;
    final prompt = '''
다음 음성 메모에서 아래 항목들을 추출해 JSON으로 답변하세요.
항목: ${fields.join(', ')}
음성 메모: "$voiceText"
응답 형식: {"항목명": "값", ...}
항목이 없으면 빈 문자열로.
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['choices'][0]['message']['content'] as String;
        final parsed = jsonDecode(content) as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            for (final field in fields) {
              final value = parsed[field]?.toString() ?? '';
              if (value.isNotEmpty) {
                _memoData[field] = value;
                _memoControllers[field]?.text = value;
              }
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Voice parse error: $e');
    }
  }

  void _showNoKeyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _navy,
        title: const Text('API 키 없음', style: TextStyle(color: Colors.white)),
        content: const Text(
          '설정 화면에서 OpenAI API 키를 입력해야\nAI 위치 분석을 사용할 수 있습니다.',
          style: TextStyle(color: Color(0xFF8899AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  bool get _isPreciseWithFields {
    final session = widget.session;
    return session != null &&
        session.mode == 'precise' &&
        session.fields.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('촬영 결과 확인',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildingPreview
                ? const Center(child: CircularProgressIndicator())
                : _watermarkedBytes != null
                    ? InteractiveViewer(
                        child: Center(
                          child: Image.memory(_watermarkedBytes!),
                        ),
                      )
                    : const Center(child: Text('미리보기 생성 실패')),
          ),
          if (_aiResult != null || _analyzing)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: _analyzing
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('AI 분석 중...', style: TextStyle(fontSize: 13)),
                      ],
                    )
                  : Text(
                      _aiResult ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE8EDF3),
                        height: 1.5,
                      ),
                    ),
            ),
          // 정밀 모드 현장 메모 섹션
          if (_isPreciseWithFields)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '현장 메모',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.session!.fields.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                field,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8899AA),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1B2A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _border),
                                ),
                                child: TextField(
                                  controller: _memoControllers[field],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFE8EDF3),
                                  ),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 4),
                  if (_voiceService != null)
                    VoiceMemoWidget(
                      voiceService: _voiceService!,
                      onTranscribed: _parseVoiceToMemo,
                    )
                  else
                    const Text(
                      'API 키 설정 후 음성 메모를 사용할 수 있습니다.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF556677)),
                    ),
                ],
              ),
            ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                '저장 실패: $_saveError',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _analyzing ? null : _analyzeWithAi,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 위치 확인'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _accent),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: (_saving || _buildingPreview || _watermarkedBytes == null) ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_alt, size: 16),
                    label: Text(_saving ? '저장 중...' : '갤러리에 저장'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF0D1B2A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
