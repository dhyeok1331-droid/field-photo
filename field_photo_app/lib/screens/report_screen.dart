import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/field_record.dart';
import '../models/mission_session.dart';
import '../services/email_service.dart';
import '../services/openai_service.dart';
import '../services/record_service.dart';
import 'settings_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _navyDeep = Color(0xFFF5F5F5);
  static const _navy = Colors.white;
  static const _accent = Color(0xFFFF6B35);
  static const _surface = Colors.white;
  static const _border = Color(0xFFEBEBEB);
  static const _textSecondary = Color(0xFF9E9E9E);
  static const _success = Color(0xFF4CAF50);
  static const _warning = Color(0xFFFFA726);

  final _recordService = RecordService();

  DateTime _selectedDate = DateTime.now();
  List<FieldRecord> _records = [];
  bool _loading = false;

  // AI 분석 진행 상태
  bool _analyzing = false;
  int _analyzeProgress = 0;
  int _analyzeTotal = 0;

  // 이메일 전송 중
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final records = await _recordService.getRecordsByDate(dateStr);
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  void _goToPrevDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadRecords();
  }

  void _goToNextDay() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (selectedDate.isBefore(todayDate)) {
      setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
      _loadRecords();
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: today,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF6B35),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadRecords();
    }
  }

  String _formatDisplayDate(DateTime date) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final d = DateTime(date.year, date.month, date.day);
    final base = DateFormat('yyyy년 MM월 dd일').format(date);
    return d == todayDate ? '$base (오늘)' : base;
  }

  bool get _isToday {
    final today = DateTime.now();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }

  bool get _hasUnanalyzed => _records.any((r) => r.aiAnalysis == null);

  Future<void> _runBatchAnalysis() async {
    final apiKey = await SettingsScreen.getOpenAiKey();
    if (!mounted) return;
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정에서 OpenAI API 키를 먼저 입력해 주세요.')),
      );
      return;
    }

    final unanalyzed = _records.where((r) => r.aiAnalysis == null).toList();
    if (unanalyzed.isEmpty) return;

    setState(() {
      _analyzing = true;
      _analyzeProgress = 0;
      _analyzeTotal = unanalyzed.length;
    });

    final service = OpenAiService(apiKey);

    for (final record in unanalyzed) {
      if (!mounted) break;
      try {
        final result = await service.analyzeFieldPhoto(
          imagePath: record.imagePath,
          lat: record.lat ?? 0,
          lng: record.lng ?? 0,
          currentAddress: record.address,
          jimok: record.jimok,
        );
        final updated = record.copyWith(aiAnalysis: result);
        await _recordService.updateRecord(updated);
        if (mounted) {
          setState(() {
            _analyzeProgress++;
            final idx = _records.indexWhere((r) => r.id == record.id);
            if (idx != -1) _records[idx] = updated;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _analyzeProgress++);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('분석 오류 (${record.address}): $e')),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 분석이 완료되었습니다.')),
      );
    }
  }

  Future<void> _sendEmail() async {
    if (_records.isEmpty) return;

    final emailSettings = await SettingsScreen.getEmailSettings();
    final recipient = emailSettings['recipient']!;
    final sender = emailSettings['sender']!;
    final appPassword = emailSettings['appPassword']!;

    if (!mounted) return;

    if (recipient.isEmpty || sender.isEmpty || appPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일 설정(수신자/발신자/앱비밀번호)이 완료되지 않았습니다. 설정 화면에서 입력해 주세요.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final sessions = await _recordService.getRecentSessions(1);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final session = sessions.isNotEmpty
          ? sessions.first
          : MissionSession(
              date: dateStr,
              mode: 'fast',
              purpose: '현장점검',
              fields: [],
              statusButtons: [],
              createdAt: DateTime.now(),
            );

      await EmailService.sendDailyReport(
        records: _records,
        session: session,
        senderEmail: sender,
        appPassword: appPassword,
        recipientEmail: recipient,
        date: dateStr,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일을 전송했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteRecord(FieldRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _navy,
        title: const Text('기록 삭제',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        content: const Text('이 기록을 삭제하시겠습니까?',
            style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true && record.id != null) {
      await _recordService.deleteRecord(record.id!);
      _loadRecords();
    }
  }

  void _showDetail(FieldRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              DateFormat('HH:mm').format(record.timestamp),
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              record.address,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
            ),
            if (record.jimok.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(record.jimok,
                  style: const TextStyle(fontSize: 13, color: _accent)),
            ],
            const SizedBox(height: 16),
            // 사진
            if (File(record.imagePath).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(record.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              record.imagePath,
              style: const TextStyle(fontSize: 10, color: _textSecondary),
            ),
            const SizedBox(height: 16),
            // 메모
            if (record.memoData.isNotEmpty) ...[
              const Text('메모',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _accent)),
              const SizedBox(height: 6),
              ...record.memoData.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key}: ',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: _textSecondary)),
                      Expanded(
                        child: Text(e.value,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1A1A2E))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // AI 분석
            if (record.aiAnalysis != null) ...[
              const Text('AI 분석 결과',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _success)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _navyDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  record.aiAnalysis!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), height: 1.5),
                ),
              ),
            ],
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
        title: const Text(
          '현장 보고서',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E)),
        ),
        backgroundColor: _navy,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today,
                size: 20, color: Color(0xFF1A1A2E)),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateBar(),
          if (_analyzing) _buildAnalyzingBanner(),
          Expanded(child: _buildRecordList()),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildDateBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: _accent),
            onPressed: _goToPrevDay,
            tooltip: '어제',
          ),
          Expanded(
            child: Text(
              _formatDisplayDate(_selectedDate),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _isToday ? _textSecondary : _accent,
            ),
            onPressed: _isToday ? null : _goToNextDay,
            tooltip: '다음날',
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingBanner() {
    return Container(
      color: _warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _warning,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '분석 중... ($_analyzeProgress/$_analyzeTotal)',
            style: const TextStyle(fontSize: 13, color: _warning),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48, color: _textSecondary),
            const SizedBox(height: 12),
            Text(
              '${_formatDisplayDate(_selectedDate)}에\n기록이 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _textSecondary, height: 1.6),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _records.length,
      itemBuilder: (_, index) => _buildRecordCard(_records[index]),
    );
  }

  Widget _buildRecordCard(FieldRecord record) {
    return GestureDetector(
      onTap: () => _showDetail(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진 썸네일
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 52,
                child: File(record.imagePath).existsSync()
                    ? Image.file(
                        File(record.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(record.timestamp),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: _accent),
                      ),
                      if (record.jimok.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            record.jimok,
                            style: const TextStyle(fontSize: 10, color: _accent),
                          ),
                        ),
                      ],
                      if (record.aiAnalysis != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.auto_awesome, size: 12, color: _success),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.address,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (record.memoSummary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      record.memoSummary,
                      style: const TextStyle(fontSize: 11, color: _textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 삭제 버튼
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: _textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _deleteRecord(record),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: _navy,
      child: const Icon(Icons.image_not_supported_outlined,
          size: 20, color: _textSecondary),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: (_analyzing || !_hasUnanalyzed) ? null : _runBatchAnalysis,
              icon: _analyzing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _navyDeep),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI 일괄 분석', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _navyDeep,
                disabledBackgroundColor: _accent.withValues(alpha: 0.3),
                disabledForegroundColor: _textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: (_sending || _records.isEmpty) ? null : _sendEmail,
              icon: _sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _navyDeep),
                    )
                  : const Icon(Icons.email_outlined, size: 16),
              label: const Text('이메일로 보내기', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: _success,
                foregroundColor: _navyDeep,
                disabledBackgroundColor: _success.withValues(alpha: 0.3),
                disabledForegroundColor: _textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
