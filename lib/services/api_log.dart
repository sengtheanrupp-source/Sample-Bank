import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One API call as it really happened: request, response, timing, error.
class ApiLogEntry {
  ApiLogEntry({
    required this.at,
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.requestBody,
    required this.durationMs,
    required this.outcome,
    this.statusCode,
    this.responseBody,
    this.error,
  });

  final DateTime at;
  final String method;
  final String url;
  final Map<String, String> requestHeaders; // token already masked
  final String requestBody;
  final int durationMs;

  /// success | declined | pending | failed | demo
  final String outcome;
  final int? statusCode;
  final String? responseBody;
  final String? error;

  /// Short one-line reason, e.g. "HTTP 502" or "Timeout after 20 s".
  String get reason {
    if (error != null) return error!;
    if (statusCode != null) return 'HTTP $statusCode';
    return outcome;
  }

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'method': method,
        'url': url,
        'reqHeaders': requestHeaders,
        'reqBody': requestBody,
        'ms': durationMs,
        'outcome': outcome,
        'status': statusCode,
        'resBody': responseBody,
        'error': error,
      };

  static ApiLogEntry fromJson(Map<String, dynamic> j) => ApiLogEntry(
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        method: j['method'] as String? ?? 'POST',
        url: j['url'] as String? ?? '',
        requestHeaders: Map<String, String>.from(
            (j['reqHeaders'] as Map?)?.cast<String, String>() ?? const {}),
        requestBody: j['reqBody'] as String? ?? '',
        durationMs: j['ms'] as int? ?? 0,
        outcome: j['outcome'] as String? ?? '',
        statusCode: j['status'] as int?,
        responseBody: j['resBody'] as String?,
        error: j['error'] as String?,
      );

  /// Plain-text version for copy / share with the backend team.
  String toReport() {
    String pretty(String? s) {
      if (s == null || s.isEmpty) return '(empty)';
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(s));
      } catch (_) {
        return s;
      }
    }

    final b = StringBuffer()
      ..writeln('$method $url')
      ..writeln('Time: ${at.toIso8601String()}  ·  ${durationMs}ms')
      ..writeln('Outcome: $outcome  ·  $reason')
      ..writeln()
      ..writeln('Request headers:');
    requestHeaders.forEach((k, v) => b.writeln('  $k: $v'));
    b
      ..writeln()
      ..writeln('Request body:')
      ..writeln(pretty(requestBody))
      ..writeln()
      ..writeln('Response (${statusCode ?? 'none'}):')
      ..writeln(pretty(responseBody));
    if (error != null) {
      b
        ..writeln()
        ..writeln('Error: $error');
    }
    return b.toString();
  }
}

/// On-device API log (newest first). Kept in shared_preferences so it
/// survives an app restart. Never leaves the device.
class ApiLog extends ChangeNotifier {
  ApiLog._();
  static final instance = ApiLog._();

  static const _key = 'api.log.v1';
  static const maxEntries = 50;
  static const _maxBody = 8000;

  final List<ApiLogEntry> _entries = [];
  List<ApiLogEntry> get entries => List.unmodifiable(_entries);

  /// "3c81cc406c554b7a90030efed8a4c23b" -> "3c81…c23b (32 chars)".
  static String mask(String secret) {
    final s = secret.trim();
    if (s.isEmpty) return '(none)';
    if (s.length <= 8) return '••••';
    return '${s.substring(0, 4)}…${s.substring(s.length - 4)} (${s.length} chars)';
  }

  static String clip(String s) =>
      s.length <= _maxBody ? s : '${s.substring(0, _maxBody)}… [truncated]';

  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      _entries
        ..clear()
        ..addAll((jsonDecode(raw) as List)
            .map((e) => ApiLogEntry.fromJson(Map<String, dynamic>.from(e))));
      notifyListeners();
    } catch (_) {/* corrupt log - start fresh */}
  }

  Future<void> add(ApiLogEntry e) async {
    _entries.insert(0, e);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
    if (kDebugMode) debugPrint('[api] ${e.method} ${e.url} -> ${e.reason}');
    await _persist();
  }

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    } catch (_) {/* logging must never break a payment */}
  }
}
