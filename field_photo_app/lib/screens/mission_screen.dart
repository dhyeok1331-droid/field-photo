import 'package:flutter/material.dart';

import '../models/mission_session.dart';
import '../services/mission_service.dart';

class MissionScreen extends StatefulWidget {
  final String apiKey;

  const MissionScreen({super.key, required this.apiKey});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  static const _navyDeep = Color(0xFF0D1B2A);
  static const _navy = Color(0xFF1B2D45);
  static const _accent = Color(0xFF4EA8DE);
  static const _surface = Color(0xFF162234);
  static const _border = Color(0x264EA8DE);
  static const _textSecondary = Color(0xFF8899AA);
  static const _success = Color(0xFF34D399);

  late final MissionService _service;
  final _descController = TextEditingController();

  MissionSession? _activeSession;
  List<MissionSession> _templates = [];
  bool _loading = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _service = MissionService(widget.apiKey);
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _service.getActiveSession(),
      _service.getRecentTemplates(),
    ]);
    if (!mounted) return;
    setState(() {
      _activeSession = results[0] as MissionSession?;
      _templates = results[1] as List<MissionSession>;
      _initializing = false;
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _onTemplateTab(MissionSession template) async {
    setState(() => _loading = true);
    try {
      final session = await _service.reuseSession(template);
      if (mounted) Navigator.pop(context, session);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _onAiRequest() async {
    final text = _descController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작업을 설명해주세요')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final session = await _service.createSessionFromDescription(text);
      if (mounted) Navigator.pop(context, session);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _modeBadge(String mode) {
    final isfast = mode == 'fast';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isfast
            ? const Color(0xFFFB923C).withValues(alpha: 0.2)
            : _accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isfast
              ? const Color(0xFFFB923C).withValues(alpha: 0.5)
              : _accent.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        isfast ? '⚡ 고속모드' : '🎯 정밀모드',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isfast ? const Color(0xFFFB923C) : _accent,
        ),
      ),
    );
  }

  Widget _buildTemplateCard(MissionSession session) {
    final subtitle = session.mode == 'fast'
        ? '버튼: ${session.statusButtons.join(' / ')}'
        : '필드: ${session.fields.join(', ')}';

    return GestureDetector(
      onTap: _loading ? null : () => _onTemplateTab(session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.purpose,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE8EDF3),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _modeBadge(session.mode),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: _textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDeep,
      appBar: AppBar(
        backgroundColor: _navy,
        title: const Text(
          '오늘 작업 설정',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_activeSession != null)
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.pop(context, _activeSession),
              child: const Text(
                '이어서 하기',
                style: TextStyle(
                  color: _success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_templates.isNotEmpty) ...[
                      const Text(
                        '최근 작업',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._templates.map(_buildTemplateCard),
                      const SizedBox(height: 20),
                      const Divider(color: _border),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      '오늘 작업을 설명하세요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: TextField(
                        controller: _descController,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE8EDF3),
                        ),
                        decoration: const InputDecoration(
                          hintText: '예) "태풍 피해 농가 150곳 조사"',
                          hintStyle: TextStyle(
                            color: Color(0xFF556677),
                            fontSize: 13,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _onAiRequest,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _navyDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'AI에게 작업 설정 요청',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_loading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Center(
                      child: CircularProgressIndicator(color: _accent),
                    ),
                  ),
              ],
            ),
    );
  }
}
