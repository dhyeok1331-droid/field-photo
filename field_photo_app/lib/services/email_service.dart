import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:path/path.dart' as path_pkg;

import '../models/field_record.dart';
import '../models/mission_session.dart';

class EmailService {
  /// Gmail SMTP로 하루 보고서 이메일 발송
  static Future<void> sendDailyReport({
    required List<FieldRecord> records,
    required MissionSession session,
    required String senderEmail,
    required String appPassword,
    required String recipientEmail,
    required String date,
  }) async {
    final smtpServer = gmail(senderEmail, appPassword);

    final excelBytes = buildExcel(
      records: records,
      session: session,
      date: date,
    );
    final fileName = '현장점검_${date.replaceAll('-', '')}.xlsx';

    final message = Message()
      ..from = Address(senderEmail, '농업현장점검')
      ..recipients.add(recipientEmail)
      ..subject = '[농업현장점검] $date 현장조사 보고서 (${records.length}건)'
      ..text = _buildEmailBody(records, session, date)
      ..attachments = [
        StreamAttachment(
          Stream.fromIterable([excelBytes]),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          fileName: fileName,
        ),
      ];

    await send(message, smtpServer);
  }

  /// Excel 파일 생성 후 Uint8List 반환
  static Uint8List buildExcel({
    required List<FieldRecord> records,
    required MissionSession session,
    required String date,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['현장점검'];

    // 헤더 행 구성
    final headers = <String>[
      '번호', '시간', '주소', '지목', '위도', '경도', '사진파일명',
    ];

    if (session.mode == 'fast') {
      headers.add('상태');
    } else {
      headers.addAll(session.fields);
    }
    headers.add('AI분석');

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // 데이터 행
    final timeFormat = DateFormat('HH:mm');
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final row = <CellValue?>[
        IntCellValue(i + 1),
        TextCellValue(timeFormat.format(record.timestamp)),
        TextCellValue(record.address),
        TextCellValue(record.jimok),
        record.lat != null ? DoubleCellValue(record.lat!) : TextCellValue(''),
        record.lng != null ? DoubleCellValue(record.lng!) : TextCellValue(''),
        TextCellValue(path_pkg.basename(record.imagePath)),
      ];

      if (session.mode == 'fast') {
        row.add(TextCellValue(record.memoData['상태'] ?? ''));
      } else {
        for (final fieldName in session.fields) {
          row.add(TextCellValue(record.memoData[fieldName] ?? ''));
        }
      }
      row.add(TextCellValue(record.aiAnalysis ?? ''));

      sheet.appendRow(row);
    }

    // 기본 시트 제거 (Excel.createExcel()이 'Sheet1'을 자동 생성)
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded!);
  }

  static String _buildEmailBody(
    List<FieldRecord> records,
    MissionSession session,
    String date,
  ) {
    final timeFormat = DateFormat('HH:mm');
    final buffer = StringBuffer();

    buffer.writeln('[농업현장점검] $date 현장조사 보고서');
    buffer.writeln();
    buffer.writeln('작업 목적: ${session.purpose}');
    buffer.writeln('총 ${records.length}건 현장 기록');
    buffer.writeln();
    buffer.writeln('--- 현장 목록 ---');

    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final time = timeFormat.format(record.timestamp);
      buffer.writeln('${i + 1}. $time | ${record.address} | ${record.memoSummary}');
    }

    buffer.writeln();
    buffer.write('본 이메일은 농업현장점검 앱에서 자동 발송되었습니다.');

    return buffer.toString();
  }
}
