import 'package:flutter/material.dart';
import '../services/voice_service.dart';

class QuickCaptureOverlay extends StatefulWidget {
  final List<String> statusButtons;
  final void Function(String? status) onDone;
  final bool enableVoice;
  final VoiceService? voiceService;
  final void Function(String text)? onVoiceMemo;

  const QuickCaptureOverlay({
    super.key,
    required this.statusButtons,
    required this.onDone,
    this.enableVoice = false,
    this.voiceService,
    this.onVoiceMemo,
  });

  @override
  State<QuickCaptureOverlay> createState() => _QuickCaptureOverlayState();
}

class _QuickCaptureOverlayState extends State<QuickCaptureOverlay>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF1B2D45);
  static const _accent = Color(0xFF4EA8DE);
  static const _surface = Color(0xFF162234);
  static const _border = Color(0x264EA8DE);
  static const _textSecondary = Color(0xFF8899AA);

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _showMemoDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _navy,
        title: const Text('메모 입력',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: Color(0xFFE8EDF3)),
          decoration: InputDecoration(
            hintText: '현장 특이사항을 입력하세요',
            hintStyle:
                const TextStyle(color: Color(0xFF556677), fontSize: 13),
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
                style: TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              Navigator.pop(context);
              if (text.isNotEmpty) {
                widget.onVoiceMemo?.call(text);
              }
              widget.onDone(null);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: const Color(0xFF0D1B2A),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showMemo = widget.enableVoice && widget.voiceService != null;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: _navy.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.statusButtons.map((label) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () => widget.onDone(label),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _accent),
                        backgroundColor: _surface,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(label,
                          style: const TextStyle(fontSize: 15)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (showMemo) ...[
                  GestureDetector(
                    onTap: _showMemoDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _accent, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note,
                              color: _accent, size: 16),
                          SizedBox(width: 6),
                          Text('메모',
                              style: TextStyle(
                                  color: _accent, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onDone(null),
                  style: TextButton.styleFrom(
                      foregroundColor: _textSecondary),
                  child: const Text('건너뛰기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
