import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/field_record.dart';
import '../models/mission_session.dart';
import '../models/parcel_info.dart';
import '../services/geocoding_service.dart';
import '../services/gps_service.dart';
import '../services/mission_service.dart';
import '../services/photo_service.dart';
import '../services/record_service.dart';
import '../services/voice_service.dart';
import '../utils/geo_utils.dart';
import '../widgets/map_view_widget.dart';
import '../widgets/quick_capture_overlay.dart';
import 'mission_screen.dart';
import 'preview_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ── 색상 팔레트 ──────────────────────────────────────────
  static const _bg = Color(0xFFF5F5F5);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF1A1A2E);
  static const _textSecondary = Color(0xFF9E9E9E);
  static const _accent = Color(0xFFFF6B35);
  static const _border = Color(0xFFEBEBEB);
  static const _success = Color(0xFF4CAF50);
  static const _warning = Color(0xFFFFA726);

  // ── 상태 ────────────────────────────────────────────────
  int _tabIndex = 0; // 0=지도, 1=카메라
  bool _cadastralVisible = true;
  bool _autoRotate = false;
  bool _gpsReady = false;
  double? _lat, _lng, _heading;
  ParcelInfo _currentParcel =
      const ParcelInfo(address: '위치를 수신하고 있습니다...', jimok: '');
  ParcelInfo _selectedParcel = const ParcelInfo(address: '', jimok: '');
  List<LatLng>? _selectedBoundary;

  // ── 서비스 ──────────────────────────────────────────────
  final _gpsService = GpsService();
  final _geocodingService = GeocodingService();

  // ── 카메라 ──────────────────────────────────────────────
  CameraController? _cameraCtrl;
  bool _cameraReady = false;
  String? _cameraError;

  // ── 세션 ────────────────────────────────────────────────
  MissionSession? _currentSession;

  // ── 타이머 ──────────────────────────────────────────────
  String _timeStr = '--:--:--';
  Timer? _clockTimer;
  Timer? _geocodeDebounce;
  int _centerRequestSeq = 0;

  // ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
    _initPermissionsAndStart();
    _loadActiveSession();
  }

  Future<void> _loadActiveSession() async {
    final apiKey = await SettingsScreen.getOpenAiKey();
    if (apiKey == null || apiKey.isEmpty) return;
    final service = MissionService(apiKey);
    final session = await service.getActiveSession();
    if (mounted) setState(() => _currentSession = session);
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        });
      }
    });
  }

  Future<void> _initPermissionsAndStart() async {
    final camStatus = await Permission.camera.request();
    final locStatus = await Permission.location.request();
    if (camStatus.isGranted) _startCamera();
    if (locStatus.isGranted) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) _startGps();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _cameraError = '사용 가능한 카메라가 없습니다');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _cameraCtrl = CameraController(back, ResolutionPreset.high,
          enableAudio: false);
      await _cameraCtrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (kDebugMode) debugPrint('Camera init error: $e');
      if (mounted) setState(() => _cameraError = e.toString());
    }
  }

  void _startGps() {
    _gpsService.startTracking();
    _gpsService.positionStream.listen(_onPosition);
    _gpsService.headingStream.listen((h) {
      if (mounted) setState(() => _heading = h);
    });
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _gpsReady = true;
    });
    _geocodeDebounce?.cancel();
    _geocodeDebounce =
        Timer(const Duration(milliseconds: 500), () async {
      final info = await _geocodingService.reverseGeocode(
          pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _currentParcel = info;
        if (_selectedParcel.isEmpty) _selectedParcel = info;
      });
    });
  }

  Future<void> _onMapTap(double lat, double lng) async {
    // 지번(주소·지목)과 필지 경계를 동시에 조회
    final results = await Future.wait([
      _geocodingService.reverseGeocode(lat, lng),
      _geocodingService.fetchParcelBoundary(lat, lng),
    ]);
    if (!mounted) return;
    setState(() {
      _selectedParcel = results[0] as ParcelInfo;
      _selectedBoundary = results[1] as List<LatLng>?;
    });
  }

  Future<void> _capture() async {
    if (!_cameraReady || _cameraCtrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라가 준비되지 않았습니다')),
      );
      return;
    }
    try {
      final xFile = await _cameraCtrl!.takePicture();
      final parcel =
          _selectedParcel.isEmpty ? _currentParcel : _selectedParcel;
      if (_currentSession?.mode == 'fast') {
        await _handleFastCapture(xFile.path, parcel);
      } else {
        await _handlePreciseCapture(xFile.path, parcel);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('촬영 실패: $e')));
      }
    }
  }

  Future<void> _handlePreciseCapture(
      String imagePath, ParcelInfo parcel) async {
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          imagePath: imagePath,
          parcel: parcel,
          session: _currentSession,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장 완료')));
    }
  }

  Future<void> _handleFastCapture(
      String imagePath, ParcelInfo parcel) async {
    if (!mounted) return;
    final apiKey = await SettingsScreen.getOpenAiKey();
    if (!mounted) return;

    String? selectedStatus;
    String? voiceMemo;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => QuickCaptureOverlay(
        statusButtons: _currentSession!.statusButtons,
        onDone: (status) {
          selectedStatus = status;
          Navigator.pop(context);
        },
        enableVoice: apiKey != null && apiKey.isNotEmpty,
        voiceService: apiKey != null && apiKey.isNotEmpty
            ? VoiceService(apiKey)
            : null,
        onVoiceMemo: (text) {
          voiceMemo = text;
        },
      ),
    );

    try {
      final photoService = PhotoService();
      final recordService = RecordService();
      final bytes = await photoService.buildWatermarkedJpeg(
        imagePath: imagePath,
        address: parcel.address,
        jimok: parcel.jimok,
      );
      final savedPath = await photoService.saveJpegToGallery(bytes);

      if (_currentSession?.id != null) {
        final memoData = <String, String>{};
        if (selectedStatus != null) memoData['상태'] = selectedStatus!;
        if (voiceMemo != null) memoData['음성메모'] = voiceMemo!;
        await recordService.insertRecord(FieldRecord(
          sessionId: _currentSession!.id!,
          timestamp: DateTime.now(),
          address: parcel.address,
          jimok: parcel.jimok,
          lat: parcel.lat,
          lng: parcel.lng,
          imagePath: savedPath,
          memoData: memoData,
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(selectedStatus != null
              ? '저장 완료 · $selectedStatus'
              : '저장 완료'),
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  Future<void> _goToMissionScreen() async {
    final apiKey = await SettingsScreen.getOpenAiKey();
    if (!mounted) return;
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정에서 OpenAI API 키를 먼저 입력해주세요')),
      );
      return;
    }
    final session = await Navigator.push<MissionSession>(
      context,
      MaterialPageRoute(builder: (_) => MissionScreen(apiKey: apiKey)),
    );
    if (session != null && mounted) {
      setState(() => _currentSession = session);
    }
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;

  void _showManualInput() {
    final addrCtrl = TextEditingController(
      text: _selectedParcel.address.isNotEmpty
          ? _selectedParcel.address
          : _currentParcel.address,
    );
    final jimokCtrl = TextEditingController(
      text: _selectedParcel.jimok.isNotEmpty
          ? _selectedParcel.jimok
          : _currentParcel.jimok,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('지번 직접 입력',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _inputField(addrCtrl, '주소 (예: 충남 서천군 장항읍 OO리 123-4)'),
            const SizedBox(height: 10),
            _inputField(jimokCtrl, '지목 (예: 전, 답, 임야)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final addr = addrCtrl.text.trim();
              if (addr.isEmpty) return;
              setState(() {
                _selectedParcel = ParcelInfo(
                  address: addr,
                  jimok: jimokCtrl.text.trim(),
                );
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style:
          const TextStyle(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraCtrl == null) return;
    if (state == AppLifecycleState.inactive) {
      _cameraCtrl!.dispose();
      _cameraCtrl = null;
      setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _cameraError = null);
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _geocodeDebounce?.cancel();
    _gpsService.dispose();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final displayParcel =
        _selectedParcel.isEmpty ? _currentParcel : _selectedParcel;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildInfoBar(displayParcel),
            _buildTabBar(),
            Expanded(child: _buildBody(displayParcel)),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('🌾', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text(
            '농업현장점검',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // GPS 상태 뱃지
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gpsReady
                  ? _success.withValues(alpha: 0.12)
                  : _warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _gpsReady ? _success : _warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _gpsReady ? 'GPS' : 'GPS 수신중',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _gpsReady ? _success : _warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 작업 세션 버튼
          GestureDetector(
            onTap: _goToMissionScreen,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _currentSession == null
                    ? _accent
                    : _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _currentSession == null
                    ? '+ 작업 시작'
                    : '${_currentSession!.mode == 'fast' ? '⚡' : '🎯'} ${_truncate(_currentSession!.purpose, 8)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _currentSession == null ? Colors.white : _accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(ParcelInfo parcel) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              parcel.displayText.isNotEmpty
                  ? parcel.displayText
                  : '위치 정보 없음',
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeStr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            _tabPill('지도', Icons.map_outlined, 0),
            _tabPill('카메라', Icons.camera_alt_outlined, 1),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(String label, IconData icon, int index) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? _textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? Colors.white : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ParcelInfo parcel) {
    return IndexedStack(
      index: _tabIndex,
      children: [
        _buildMapTab(parcel),
        _buildCameraTab(parcel),
      ],
    );
  }

  Widget _buildMapTab(ParcelInfo parcel) {
    return Stack(
      children: [
        MapViewWidget(
          lat: _lat,
          lng: _lng,
          heading: _heading,
          cadastralVisible: _cadastralVisible,
          autoRotate: _autoRotate,
          centerRequestSeq: _centerRequestSeq,
          selectedBoundary: _selectedBoundary,
          onMapTap: _onMapTap,
        ),
        // 우측 오버레이 버튼 묶음
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _mapOverlayBtn(
                icon: _autoRotate
                    ? Icons.screen_rotation
                    : Icons.screen_lock_rotation,
                label: '자동회전',
                active: _autoRotate,
                onTap: () =>
                    setState(() => _autoRotate = !_autoRotate),
              ),
              const SizedBox(height: 8),
              _mapOverlayBtn(
                icon: Icons.layers_outlined,
                label: '지적도',
                active: _cadastralVisible,
                onTap: () =>
                    setState(() => _cadastralVisible = !_cadastralVisible),
              ),
              const SizedBox(height: 8),
              _mapOverlayBtn(
                icon: Icons.my_location,
                label: '내 위치',
                active: false,
                onTap: () {
                  if (_lat == null || _lng == null) return;
                  setState(() => _centerRequestSeq++);
                },
              ),
            ],
          ),
        ),
        // 선택 필지 표시
        if (!_selectedParcel.isEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE5FFFFFF)],
                  stops: [0, 0.5],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '선택 필지',
                    style: TextStyle(
                        fontSize: 10,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedParcel.displayText,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary),
                  ),
                  _buildProximityChip(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 내 위치가 선택 필지 안/밖인지 + 밖이면 거리·방위를 표시.
  /// 필지 경계나 GPS가 없으면 아무것도 표시하지 않는다.
  Widget _buildProximityChip() {
    final boundary = _selectedBoundary;
    if (boundary == null ||
        boundary.length < 3 ||
        _lat == null ||
        _lng == null) {
      return const SizedBox.shrink();
    }
    final me = LatLng(_lat!, _lng!);
    final inside = pointInPolygon(me, boundary);

    final Color color;
    final IconData icon;
    final String text;
    if (inside) {
      color = _success;
      icon = Icons.check_circle;
      text = '선택 필지 안에 있습니다';
    } else {
      final centroid = polygonCentroid(boundary);
      final meters = const Distance().as(LengthUnit.Meter, me, centroid);
      final dir = bearing8Korean(bearingBetween(me, centroid));
      color = _warning;
      icon = Icons.warning_amber_rounded;
      text = '선택 필지 밖 · 약 ${formatDistance(meters)} $dir';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapOverlayBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? _accent : _border),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: active ? Colors.white : _textSecondary),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraTab(ParcelInfo parcel) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_cameraReady && _cameraCtrl != null)
          CameraPreview(_cameraCtrl!)
        else if (_cameraError != null)
          Container(
            color: _bg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          size: 36, color: _accent),
                    ),
                    const SizedBox(height: 16),
                    const Text('카메라 오류',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      _cameraError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: _textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        setState(() => _cameraError = null);
                        _startCamera();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: _accent),
          ),
        // 워터마크 오버레이
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  parcel.displayText.isNotEmpty
                      ? parcel.displayText
                      : '지번 정보 없음',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd  HH:mm:ss').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xCCFFFFFF),
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          // 지번 수정 버튼
          _actionIconBtn(
            icon: Icons.edit_outlined,
            label: '지번 수정',
            onTap: _showManualInput,
          ),
          const Spacer(),
          // 촬영 버튼 (중앙)
          _captureBtn(),
          const Spacer(),
          // 자리 맞춤용 투명 위젯
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _actionIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _bg,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: Icon(icon, size: 20, color: _textPrimary),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _captureBtn() {
    final onCamera = _tabIndex == 1;
    return GestureDetector(
      onTap: () {
        if (!onCamera) {
          setState(() => _tabIndex = 1);
        } else {
          _capture();
        }
      },
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _accent,
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          onCamera ? Icons.camera_alt : Icons.camera_alt_outlined,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
