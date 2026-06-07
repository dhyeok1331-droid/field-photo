// 음성 인식은 현재 Gradle 9 호환 패키지 미제공으로 텍스트 입력으로 대체.
// 인터페이스는 유지해 향후 업그레이드 시 내부만 교체하면 됨.

class VoiceService {
  final String apiKey;
  bool _isRecording = false;

  VoiceService(this.apiKey);

  bool get isRecording => _isRecording;

  // 텍스트 입력 방식에서는 미사용 (위젯에서 직접 처리)
  Future<void> startRecording() async {
    _isRecording = true;
  }

  Future<String?> stopRecording() async {
    _isRecording = false;
    return null;
  }

  Future<String?> stopAndTranscribe() async {
    _isRecording = false;
    return null;
  }

  void dispose() {}
}
