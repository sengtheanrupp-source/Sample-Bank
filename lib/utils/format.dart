import 'dart:math';

import 'package:intl/intl.dart';

import '../models/khqr.dart';

final _khr = NumberFormat('#,##0', 'en_US');
final _usd = NumberFormat('#,##0.00', 'en_US');

String formatMoney(double v, KhqrCurrency c) =>
    c == KhqrCurrency.khr ? '៛${_khr.format(v)}' : '\$${_usd.format(v)}';

String formatDateTime(DateTime d) =>
    DateFormat('dd MMM yyyy, hh:mm a').format(d);

String maskAccount(String number) {
  final digits = number.replaceAll(' ', '');
  return digits.length <= 4
      ? digits
      : '•••${digits.substring(digits.length - 4)}';
}

final _rng = Random.secure();
const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/// 16-char reference, same format the Telegram mini app sends as ref_no / khqr_hash.
String generateRef16() =>
    List.generate(16, (_) => _chars[_rng.nextInt(_chars.length)]).join();
