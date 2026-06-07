import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class PhotoService {
  /// 워터마크를 합성한 JPEG 바이트를 반환
  Future<Uint8List> buildWatermarkedJpeg({
    required String imagePath,
    required String address,
    required String jimok,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd  HH:mm:ss').format(now);
    final addrText = address + (jimok.isNotEmpty ? ' | $jimok' : '');

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawImage(srcImage, Offset.zero, Paint());

    final w = srcImage.width.toDouble();
    final h = srcImage.height.toDouble();
    final barH = (h * 0.09).clamp(60.0, 140.0);

    canvas.drawRect(
      Rect.fromLTWH(0, h - barH, w, barH),
      Paint()..color = const Color(0x99000000),
    );

    final fs1 = (w * 0.026).clamp(18.0, 50.0);
    final fs2 = (w * 0.020).clamp(14.0, 40.0);

    _drawText(canvas, addrText,
        style: TextStyle(
          color: Colors.white,
          fontSize: fs1,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
        offset: Offset(20, h - barH + 10),
        maxWidth: w - 40);

    _drawText(canvas, timestamp,
        style: TextStyle(
          color: const Color(0xCCFFFFFF),
          fontSize: fs2,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
        offset: Offset(20, h - barH + 14 + fs1),
        maxWidth: w - 40);

    final imgWidth = srcImage.width;
    final imgHeight = srcImage.height;

    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(imgWidth, imgHeight);
    final byteData =
        await resultImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    srcImage.dispose();
    resultImage.dispose();

    final rgba = byteData!.buffer.asUint8List();

    final imgObj = img.Image.fromBytes(
      width: imgWidth,
      height: imgHeight,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    return Uint8List.fromList(img.encodeJpg(imgObj, quality: 92));
  }

  void _drawText(
    ui.Canvas canvas,
    String text, {
    required TextStyle style,
    required Offset offset,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  /// 이미 생성된 JPEG 바이트를 갤러리에 저장
  Future<String> saveJpegToGallery(Uint8List jpegBytes) async {
    final now = DateTime.now();
    final fileName =
        '현장점검_${DateFormat('yyyyMMdd_HHmmss').format(now)}.jpg';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(jpegBytes);

    await Gal.requestAccess(toAlbum: true);
    await Gal.putImage(file.path, album: '농업현장점검');
    return file.path;
  }
}
