import 'package:flutter/material.dart';
import '../services/voice_service.dart';

// 음성 인식 패키지 미호환으로 텍스트 입력 방식으로 구현.
// 인터페이스는 동일 — 향후 음성 인식 추가 시 내부만 교체.
class VoiceMemoWidget extends StatelessWidget {
  final VoiceService voiceService;
  final void Function(String text) onTranscribed;
  final bool enabled;

  static const _accent = Color(0xFF4EA8DE);
  static const _navy = Color(0xFF1B2D45);
  static const _surface = Color(0xFF162234);
  static const _border = Color(0x264EA8DE);

  const VoiceMemoWidget({
    super.key,
    required this.voiceService,
    required this.onTranscribed,
    this.enabled = true,
  });

  void _showInputDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _navy,
        title: const Text(
          '메모 입력',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: Color(0xFFE8EDF3)),
          decoration: InputDecoration(
            hintText: '예) 홍길동 농가, 침수 피해, 논 2000평',
            hintStyle: const TextStyle(color: Color(0xFF556677), fontSize: 13),
            filled: true,
            fillColor: _surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF8899AA))),
          ),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              Navigator.pop(context);
              if (text.isNotEmpty) onTranscribed(text);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: const Color(0xFF0D1B2A),
            ),
            child: const Text('AI 자동 입력'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => _showInputDialog(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? _accent.withValues(alpha: 0.15)
              : _accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note,
                color: enabled ? _accent : const Color(0xFF8899AA), size: 18),
            const SizedBox(width: 8),
            Text(
              '메모 입력 → AI 자동 입력',
              style: TextStyle(
                color: enabled ? _accent : const Color(0xFF8899AA),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
