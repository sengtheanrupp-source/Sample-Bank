import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/payment_api.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/friendly_toast.dart';
import 'scan_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.accountName,
    required this.remark,
  });

  final PaymentResult result;
  final String accountName;
  final String remark;

  void _home(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  void _scanAgain(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final f = result.message;
    final color = toneColor(f.tone);
    final ok = result.isSuccess;
    final pending = result.status == PaymentStatus.pending;

    return PopScope(
      canPop: !ok, // after success, back goes home instead of to the pay screen
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context);
      },
      child: Scaffold(
        backgroundColor: RB.cream,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                  children: [
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 24)
                            ],
                          ),
                          child: Icon(f.icon, color: Colors.white, size: 52),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (ok || pending)
                      Center(
                        child: Text(
                          formatMoney(result.amount, result.currency),
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: RB.ink),
                        ),
                      ),
                    const SizedBox(height: 6),
                    FriendlyText(f, center: true),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(children: [
                        _row('Paid to', result.paidTo),
                        _row('Amount',
                            formatMoney(result.amount, result.currency)),
                        _row('Fee', formatMoney(result.fee, result.currency)),
                        _row('From', accountName),
                        if (remark.isNotEmpty) _row('Note', remark),
                        _row('Reference', result.refNo,
                            copy: true, context: context),
                        _row('Date', formatDateTime(result.paidAt)),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(children: [
                  if (ok) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _outlined,
                        onPressed: () => _scanAgain(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: _filled,
                        onPressed: () => _home(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ] else if (pending) ...[
                    Expanded(
                      child: FilledButton(
                        style: _filled,
                        onPressed: () => _home(context),
                        child: const Text('Back to home'),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: OutlinedButton(
                        style: _outlined,
                        onPressed: () => _home(context),
                        child: const Text('Home'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: _filled,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _filled = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    backgroundColor: RB.teal,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
  static final _outlined = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    foregroundColor: RB.teal,
    side: const BorderSide(color: RB.teal),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  Widget _row(String k, String v, {bool copy = false, BuildContext? context}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 92, child: Text(k, style: const TextStyle(color: RB.muted))),
        Expanded(
          child: Text(v,
              textAlign: TextAlign.end,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, color: RB.ink)),
        ),
        if (copy && context != null)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: v));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reference copied')));
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.copy_rounded, size: 18, color: RB.teal),
            ),
          ),
      ]),
    );
  }
}
