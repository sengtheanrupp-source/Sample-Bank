import 'dart:convert';

enum KhqrCurrency { khr, usd }

extension KhqrCurrencyX on KhqrCurrency {
  String get code => this == KhqrCurrency.khr ? 'KHR' : 'USD';
  String get symbol => this == KhqrCurrency.khr ? '៛' : '\$';
}

enum KhqrError { notKhqr, badChecksum, malformed }

class KhqrException implements Exception {
  final KhqrError reason;
  const KhqrException(this.reason);
  @override
  String toString() => 'KhqrException($reason)';
}

/// Decoded KHQR (EMVCo merchant-presented QR, Bakong profile).
class KhqrData {
  final String raw;
  final bool isDynamic; // tag 01 = "12"
  final bool isMerchant; // tag 30 (merchant) vs tag 29 (individual)
  final String merchantName; // tag 59
  final String? merchantCity; // tag 60
  final String? accountId; // tag 29/30 sub 00 - Bakong account id
  final String? acquiringBank; // tag 29/30 sub 02 (when present)
  final KhqrCurrency currency; // tag 53 (116 = KHR, 840 = USD)
  final double? amount; // tag 54
  final String? billNumber; // tag 62 sub 01
  final String? storeLabel; // tag 62 sub 03
  final String? terminalLabel; // tag 62 sub 07
  final DateTime? expiresAt; // tag 99 sub 01

  const KhqrData({
    required this.raw,
    required this.isDynamic,
    required this.isMerchant,
    required this.merchantName,
    required this.currency,
    this.merchantCity,
    this.accountId,
    this.acquiringBank,
    this.amount,
    this.billNumber,
    this.storeLabel,
    this.terminalLabel,
    this.expiresAt,
  });

  bool get hasAmount => amount != null && amount! > 0;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  String get initials {
    final parts = merchantName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class KhqrParser {
  /// Parses one level of EMV TLV: 2-char id, 2-digit length, value.
  static Map<String, String> parseTlv(String s) {
    final out = <String, String>{};
    var i = 0;
    while (i < s.length) {
      if (i + 4 > s.length) throw const KhqrException(KhqrError.malformed);
      final id = s.substring(i, i + 2);
      final len = int.tryParse(s.substring(i + 2, i + 4));
      if (len == null || i + 4 + len > s.length) {
        throw const KhqrException(KhqrError.malformed);
      }
      out[id] = s.substring(i + 4, i + 4 + len);
      i += 4 + len;
    }
    return out;
  }

  /// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) - the EMVCo QR checksum.
  static String crc16(String data) {
    var crc = 0xFFFF;
    for (final b in utf8.encode(data)) {
      crc ^= (b << 8);
      for (var j = 0; j < 8; j++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static KhqrData parse(String input) {
    final s = input.trim();
    if (!s.startsWith('000201') || s.length < 40) {
      throw const KhqrException(KhqrError.notKhqr);
    }

    // CRC is always the last field: "6304" + 4 hex chars.
    if (s.substring(s.length - 8, s.length - 4) != '6304') {
      throw const KhqrException(KhqrError.badChecksum);
    }
    final body = s.substring(0, s.length - 4);
    final crc = s.substring(s.length - 4).toUpperCase();
    if (crc16(body) != crc) {
      throw const KhqrException(KhqrError.badChecksum);
    }

    final tags = parseTlv(s);

    final isMerchant = tags.containsKey('30');
    final accountRaw = tags['30'] ?? tags['29'];
    if (accountRaw == null) throw const KhqrException(KhqrError.notKhqr);
    final account = parseTlv(accountRaw);
    final accountId = account['00'];
    if (accountId == null || !accountId.contains('@')) {
      throw const KhqrException(KhqrError.notKhqr);
    }

    final name = (tags['59'] ?? '').trim();
    if (name.isEmpty) throw const KhqrException(KhqrError.malformed);

    final currency = tags['53'] == '116' ? KhqrCurrency.khr : KhqrCurrency.usd;
    final amount = tags['54'] == null ? null : double.tryParse(tags['54']!);

    Map<String, String> extra = const {};
    if (tags['62'] != null) {
      try {
        extra = parseTlv(tags['62']!);
      } on KhqrException {
        extra = const {};
      }
    }

    DateTime? expiresAt;
    if (tags['99'] != null) {
      try {
        final ts = parseTlv(tags['99']!);
        final exp = int.tryParse(ts['01'] ?? '');
        if (exp != null && exp > 0) {
          // KHQR uses epoch milliseconds; tolerate seconds just in case.
          expiresAt = DateTime.fromMillisecondsSinceEpoch(
              exp < 100000000000 ? exp * 1000 : exp);
        }
      } on KhqrException {
        expiresAt = null;
      }
    }

    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    return KhqrData(
      raw: s,
      isDynamic: tags['01'] == '12',
      isMerchant: isMerchant,
      merchantName: name,
      merchantCity: clean(tags['60']),
      accountId: accountId,
      acquiringBank: clean(account['02']),
      currency: currency,
      amount: (amount != null && amount > 0) ? amount : null,
      billNumber: clean(extra['01']),
      storeLabel: clean(extra['03']),
      terminalLabel: clean(extra['07']),
      expiresAt: expiresAt,
    );
  }
}
