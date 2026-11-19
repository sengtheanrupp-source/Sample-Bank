import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/khqr.dart';
import 'api_log.dart';
import 'api_settings.dart';
import 'messages.dart';

enum PaymentStatus { success, declined, pending, failed }

class PaymentResult {
  final PaymentStatus status;
  final String refNo;
  final double amount;
  final KhqrCurrency currency;
  final double fee;
  final String paidTo;
  final DateTime paidAt;
  final Friendly message;

  /// Technical reason for support (e.g. "HTTP 502", "Timeout after 20 s").
  final String? detail;

  const PaymentResult({
    required this.status,
    required this.refNo,
    required this.amount,
    required this.currency,
    required this.fee,
    required this.paidTo,
    required this.paidAt,
    required this.message,
    this.detail,
  });

  bool get isSuccess => status == PaymentStatus.success;
}

/// Calls POST {BASE_URL}/qr/v2/confirm with the same headers and payload
/// as submitQRConfirmAfterAuth() in the Telegram mini app's app.js.
class PaymentApi {
  PaymentApi(this.settings, {http.Client? client})
      : _client = client ?? http.Client();
  final ApiSettings settings;
  final http.Client _client;

  Future<PaymentResult> confirmKhqr({
    required KhqrData qr,
    required double amount,
    required KhqrCurrency currency,
    required String refNo,
    required String khqrHash,
    String note = '',
  }) async {
    final payload = <String, dynamic>{
      'khqr_string': qr.raw,
      'currency': currency.code,
      'amount': amount,
      'ref_no': refNo,
      'note': note.isEmpty ? 'Romdoul Bank KHQR Pay' : note,
      'issuer_id': settings.issuerId,
      'issuer_name': qr.merchantName,
      'khqr_hash': khqrHash,
    };

    PaymentResult result(PaymentStatus s, Friendly m,
            {double? total,
            double fee = 0,
            String? paidTo,
            DateTime? at,
            String? detail}) =>
        PaymentResult(
          status: s,
          refNo: refNo,
          amount: total ?? amount,
          currency: currency,
          fee: fee,
          paidTo: paidTo ?? qr.merchantName,
          paidAt: at ?? DateTime.now(),
          message: m,
          detail: detail,
        );

    final headers = {
      'Content-Type': 'application/json',
      'accept': '*/*',
      'token': settings.token,
    };
    final body = jsonEncode(payload);
    final started = DateTime.now();
    final sw = Stopwatch()..start();

    void log(String outcome, {int? status, String? resBody, String? error}) {
      ApiLog.instance.add(ApiLogEntry(
        at: started,
        method: 'POST',
        url: settings.useMock
            ? '(demo) ${settings.confirmUrl}'
            : settings.confirmUrl,
        requestHeaders: {...headers, 'token': ApiLog.mask(settings.token)},
        requestBody: ApiLog.clip(body),
        durationMs: sw.elapsedMilliseconds,
        outcome: outcome,
        statusCode: status,
        responseBody: resBody == null ? null : ApiLog.clip(resBody),
        error: error,
      ));
    }

    if (settings.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      log('demo', error: 'Demo mode - no network call');
      return result(PaymentStatus.success, Friendly.success);
    }

    try {
      final res = await _client
          .post(Uri.parse(settings.confirmUrl), headers: headers, body: body)
          .timeout(AppConfig.requestTimeout);

      Map<String, dynamic> json = const {};
      if (res.body.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) json = decoded;
        } catch (_) {/* non-JSON body */}
      }
      final serverMsg = (json['message'] ?? json['error'])?.toString();
      final serverCode = json['code']?.toString();
      final detail = [
        'HTTP ${res.statusCode}',
        if (serverCode != null && serverCode.isNotEmpty) 'code $serverCode',
        if (serverMsg != null && serverMsg.trim().isNotEmpty) serverMsg.trim(),
      ].join(' · ');

      PaymentResult done(PaymentStatus s, Friendly m,
          {double? total, double fee = 0, String? paidTo, DateTime? at}) {
        log(s.name, status: res.statusCode, resBody: res.body);
        return result(s, m,
            total: total, fee: fee, paidTo: paidTo, at: at, detail: detail);
      }

      if (res.statusCode == 401 || res.statusCode == 403) {
        return done(PaymentStatus.failed, Friendly.session);
      }
      if (res.statusCode >= 500) {
        // Server may or may not have booked it - never tell the user it failed.
        return done(PaymentStatus.pending, Friendly.pending);
      }

      final data = json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{};

      if (res.statusCode < 400 && serverCode == 'SUCCESS') {
        return done(
          PaymentStatus.success,
          Friendly.success,
          total: _num(data['total_amount'], amount),
          fee: _num(data['fee_amount'], 0),
          paidTo: (data['paid_to'] ?? data['biller_name'])?.toString(),
          at: DateTime.tryParse(data['paid_date']?.toString() ?? ''),
        );
      }

      final declined = (serverMsg != null && serverMsg.trim().isNotEmpty)
          ? Friendly.declined.withBody('$serverMsg Nothing was charged.')
          : Friendly.declined;
      return done(PaymentStatus.declined, declined);
    } catch (e) {
      final (status, friendly, why) = switch (e) {
        TimeoutException() => (
            PaymentStatus.pending,
            Friendly.pending,
            'No response within ${AppConfig.requestTimeout.inSeconds} s (timeout)'
          ),
        SocketException(:final message, :final osError) => (
            PaymentStatus.failed,
            Friendly.offline,
            'Network error: ${osError?.message ?? message}'
          ),
        HandshakeException(:final message) => (
            PaymentStatus.failed,
            Friendly.offline,
            'TLS/SSL handshake failed: $message'
          ),
        http.ClientException(:final message) => (
            PaymentStatus.failed,
            Friendly.offline,
            'Connection error: $message'
          ),
        FormatException() || ArgumentError() => (
            PaymentStatus.failed,
            Friendly.badConfig,
            'Invalid base URL: ${settings.confirmUrl}'
          ),
        // Unknown problem: we can't be sure nothing was booked.
        _ => (PaymentStatus.pending, Friendly.pending, 'Unexpected error: $e'),
      };
      log(status.name, error: why);
      return result(status, friendly, detail: why);
    }
  }

  /// Handles numbers, "12.50", and "15.50 USD" style strings.
  static double _num(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim().split(' ').first.replaceAll(',', '')) ??
          fallback;
    }
    return fallback;
  }
}
