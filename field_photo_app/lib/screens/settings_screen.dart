import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> getOpenAiKey() async {
    return await _storage.read(key: 'openai_api_key');
  }

  static Future<String?> getVWorldKey() async {
    return await _storage.read(key: 'vworld_api_key');
  }

  static Future<Map<String, String>> getEmailSettings() async {
    return {
      'recipient': await _storage.read(key: 'email_recipient') ?? '',
      'sender': await _storage.read(key: 'email_sender') ?? '',
      'appPassword': await _storage.read(key: 'email_app_password') ?? '',
    };
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyController = TextEditingController();
  final _vworldController = TextEditingController();
  final _recipientController = TextEditingController();
  final _senderController = TextEditingController();
  final _appPasswordController = TextEditingController();

  bool _obscure = true;
  bool _obscureVworld = true;
  bool _obscurePassword = true;
  bool _saved = false;
  bool _vworldSaved = false;
  bool _emailSaved = false;

  static const _navy = Colors.white;
  static const _accent = Color(0xFFFF6B35);
  static const _surface = Color(0xFFF5F5F5);
  static const _border = Color(0xFFEBEBEB);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _allKeys = [
    'openai_api_key',
    'vworld_api_key',
    'email_recipient',
    'email_sender',
    'email_app_password',
  ];

  Future<void> _loadSettings() async {
    // 기존 SharedPreferences 값을 암호화 저장소로 1회 마이그레이션
    final prefs = await SharedPreferences.getInstance();
    for (final key in _allKeys) {
      final existing = await _storage.read(key: key);
      if (existing == null) {
        final oldValue = prefs.getString(key);
        if (oldValue != null && oldValue.isNotEmpty) {
          await _storage.write(key: key, value: oldValue);
          await prefs.remove(key);
        }
      }
    }

    _keyController.text = await _storage.read(key: 'openai_api_key') ?? '';
    _vworldController.text = await _storage.read(key: 'vworld_api_key') ?? '';
    _recipientController.text = await _storage.read(key: 'email_recipient') ?? '';
    _senderController.text = await _storage.read(key: 'email_sender') ?? '';
    _appPasswordController.text = await _storage.read(key: 'email_app_password') ?? '';
  }

  Future<void> _save() async {
    await _storage.write(key: 'openai_api_key', value: _keyController.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _saveEmail() async {
    await _storage.write(key: 'email_recipient', value: _recipientController.text.trim());
    await _storage.write(key: 'email_sender', value: _senderController.text.trim());
    await _storage.write(key: 'email_app_password', value: _appPasswordController.text.trim());
    setState(() => _emailSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _emailSaved = false);
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool? showObscure,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        obscureText: showObscure ?? false,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    (showObscure ?? false) ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF9E9E9E),
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _saveVworld() async {
    await _storage.write(key: 'vworld_api_key', value: _vworldController.text.trim());
    setState(() => _vworldSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _vworldSaved = false);
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _vworldController.dispose();
    _recipientController.dispose();
    _senderController.dispose();
    _appPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('설정',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E))),
        backgroundColor: _navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'OpenAI API 키',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _keyController,
            hint: 'sk-...',
            showObscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI 위치 분석 기능에 사용됩니다.\nopenai.com에서 발급받은 API 키를 입력하세요.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _saved ? '저장됨 ✓' : '저장',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(color: _border),
          const SizedBox(height: 16),
          const Text(
            'VWorld API 키',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _vworldController,
            hint: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
            showObscure: _obscureVworld,
            onToggleObscure: () => setState(() => _obscureVworld = !_obscureVworld),
          ),
          const SizedBox(height: 8),
          const Text(
            '지도 및 지번 조회에 사용되는 국토정보플랫폼 키입니다.\nvworld.kr에서 발급받은 키를 입력하세요.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saveVworld,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _vworldSaved ? '저장됨 ✓' : '저장',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(color: _border),
          const SizedBox(height: 16),
          const Text(
            '이메일 보고서 설정',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '수신자 이메일',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _recipientController,
            hint: 'recipient@gmail.com',
          ),
          const SizedBox(height: 12),
          const Text(
            '발신 Gmail 주소',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _senderController,
            hint: 'sender@gmail.com',
          ),
          const SizedBox(height: 12),
          const Text(
            'Gmail 앱 비밀번호',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _appPasswordController,
            hint: 'xxxx xxxx xxxx xxxx',
            showObscure: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 8),
          const Text(
            '앱 비밀번호는 Google 계정 → 보안 →\n2단계 인증 → 앱 비밀번호에서 발급하세요.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saveEmail,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _emailSaved ? '저장됨 ✓' : '저장',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
