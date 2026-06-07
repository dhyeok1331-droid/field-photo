import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MapViewWidget extends StatefulWidget {
  final double? lat;
  final double? lng;
  final double? heading;
  final bool cadastralVisible;
  final bool autoRotate;
  final int centerRequestSeq;
  final void Function(double lat, double lng) onMapTap;

  const MapViewWidget({
    super.key,
    this.lat,
    this.lng,
    this.heading,
    required this.cadastralVisible,
    required this.autoRotate,
    required this.centerRequestSeq,
    required this.onMapTap,
  });

  @override
  State<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends State<MapViewWidget> {
  String _vworldKey = '';
  final _mapController = MapController();
  LatLng? _tapMarker;
  bool _initialMoved = false;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _storage.read(key: 'vworld_api_key') ?? '';
    if (mounted) setState(() => _vworldKey = key);
  }

  @override
  void didUpdateWidget(MapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 처음 GPS 수신 시 자동 이동
    if (!_initialMoved &&
        widget.lat != null &&
        widget.lng != null &&
        (widget.lat != oldWidget.lat || widget.lng != oldWidget.lng)) {
      _initialMoved = true;
      _mapController.move(LatLng(widget.lat!, widget.lng!), 17);
      return;
    }

    // 내 위치 버튼: seq 값 변경 시 이동
    if (widget.centerRequestSeq != oldWidget.centerRequestSeq &&
        widget.lat != null &&
        widget.lng != null) {
      _mapController.move(LatLng(widget.lat!, widget.lng!), 18);
    }

    // 자동 회전: 방향 변경 시 지도 회전
    if (widget.autoRotate && widget.heading != null &&
        widget.heading != oldWidget.heading) {
      _mapController.rotate(widget.heading!);
    }

    // 자동 회전 OFF 시 북쪽으로 복원
    if (!widget.autoRotate && oldWidget.autoRotate) {
      _mapController.rotate(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsPoint = (widget.lat != null && widget.lng != null)
        ? LatLng(widget.lat!, widget.lng!)
        : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: gpsPoint ?? const LatLng(36.08, 126.688),
            initialZoom: 17,
            maxZoom: 19,
            minZoom: 5,
            onTap: (_, latlng) {
              setState(() => _tapMarker = latlng);
              widget.onMapTap(latlng.latitude, latlng.longitude);
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://api.vworld.kr/req/wmts/1.0.0/$_vworldKey/Base/{z}/{y}/{x}.png',
              userAgentPackageName: 'com.fieldphoto.field_photo_app',
            ),
            if (widget.cadastralVisible)
              Opacity(
                opacity: 0.6,
                child: TileLayer(
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl:
                        'https://api.vworld.kr/req/wms?key=$_vworldKey&',
                    layers: const ['lt_c_landinfobasemap'],
                    styles: const ['lt_c_landinfobasemap'],
                    format: 'image/png',
                    transparent: true,
                    version: '1.3.0',
                    crs: const Epsg3857(),
                  ),
                ),
              ),
            TileLayer(
              urlTemplate:
                  'https://api.vworld.kr/req/wmts/1.0.0/$_vworldKey/Hybrid/{z}/{y}/{x}.png',
              userAgentPackageName: 'com.fieldphoto.field_photo_app',
            ),
            MarkerLayer(markers: [
              if (gpsPoint != null)
                Marker(
                  point: gpsPoint,
                  width: 80,
                  height: 80,
                  // 자동회전 ON: 지도가 이미 방향으로 회전했으므로 콘은 항상 위를 가리킴(heading=0)
                  child: _GpsMarker(
                      heading: widget.autoRotate ? 0 : widget.heading),
                ),
              if (_tapMarker != null)
                Marker(
                  point: _tapMarker!,
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
            ]),
          ],
        ),
        // 나침반 (자동회전 OFF일 때만 표시)
        if (!widget.autoRotate)
          Positioned(
            top: 8,
            left: 8,
            child: _CompassIndicator(heading: widget.heading),
          ),
      ],
    );
  }
}

class _GpsMarker extends StatelessWidget {
  final double? heading;
  const _GpsMarker({this.heading});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (heading != null)
          Transform.rotate(
            angle: heading! * (math.pi / 180),
            child: CustomPaint(
              size: const Size(80, 80),
              painter: _HeadingConePainter(),
            ),
          ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const halfAngle = 35.0 * math.pi / 180;

    final path = ui.Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: size.width / 2 - 1),
        -math.pi / 2 - halfAngle,
        halfAngle * 2,
        false,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0x44FF6B35));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x88FF6B35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_HeadingConePainter old) => false;
}

class _CompassIndicator extends StatelessWidget {
  final double? heading;
  const _CompassIndicator({this.heading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFEBEBEB)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: heading == null
          ? const Icon(Icons.explore_outlined,
              color: Color(0xFF9E9E9E), size: 22)
          : Transform.rotate(
              angle: -(heading! * math.pi / 180),
              child: CustomPaint(painter: _CompassDialPainter()),
            ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx, 10),
      Paint()
        ..color = const Color(0xFFFF6B35)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx, size.height - 10),
      Paint()
        ..color = const Color(0xFFCCCCCC)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFFFF6B35),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, 1));
  }

  @override
  bool shouldRepaint(_CompassDialPainter old) => false;
}
