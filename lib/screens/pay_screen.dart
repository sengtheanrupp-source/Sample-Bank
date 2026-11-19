import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/khqr.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/messages.dart';
import '../services/payment_api.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/friendly_toast.dart';
import '../widgets/keypad.dart';
import 'home_screen.dart' show AccountPickerSheet;
import 'result_screen.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.qr});
  final KhqrData qr;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  late KhqrCurrency _currency = widget.qr.currency;
  String _input = '';
  String _remark = '';
  bool _busy = false;
  bool _sending = false;

  // Kept across retries of the same payment so the backend can de-duplicate.
  String? _refNo;
  String? _hash;

  static const _remarks = [
    'Thanks',
    'Dinner',
    'Coffee',
    'Shopping',
    'Transport',
    'Groceries'
  ];

  bool get _locked => widget.qr.hasAmount;
  double get _amount =>
      _locked ? widget.qr.amount! : (double.tryParse(_input) ?? 0);
  double get _limit =>
      _currency == KhqrCurrency.khr ? AppConfig.maxKhr : AppConfig.maxUsd;

  void _onKey(String k) {
    if (_locked || _busy) return;
    HapticFeedback.selectionClick();
    String next;
    if (k == 'CLEAR') {
      next = '';
    } else if (k == AmountKeypad.backspace) {
      next = _input.isEmpty ? '' : _input.substring(0, _input.length - 1);
    } else if (k == '.') {
      if (_input.contains('.')) return;
      next = _input.isEmpty ? '0.' : '$_input.';
    } else {
      if (_input.isEmpty && (k == '0' || k == '00')) return; // no leading zeros
      next = _input + k;
      final dot = next.indexOf('.');
      if (dot >= 0 && next.length - dot - 1 > 2) return; // max 2 decimals
      if (next.replaceAll('.', '').length > 11) return;
    }
    final v = double.tryParse(next) ?? 0;
    if (v > _limit) {
      HapticFeedback.heavyImpact();
      showFriendly(context, Friendly.overLimit);
      return;
    }
    setState(() => _input = next);
  }

  void _setCurrency(KhqrCurrency c) {
    if (_locked || c == _currency) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currency = c;
      _input = '';
    });
  }

  Future<void> _customRemark() async {
    final ctrl = TextEditingController(text: _remark);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add a note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(hintText: 'e.g. Lunch with team'),
          onSubmitted: (t) => Navigator.pop(c, t),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) setState(() => _remark = v.trim());
  }

  Friendly? _validate(AppState state) {
    if (_amount <= 0) return Friendly.enterAmount;
    if (_amount > _limit) return Friendly.overLimit;
    if (widget.qr.isExpired) return Friendly.qrExpired;
    if (!state.canAfford(state.selected, _amount, _currency)) {
      return Friendly.insufficient;
    }
    return null;
  }

  Future<void> _pay() async {
    if (_busy) return;
    final state = AppStateScope.read(context);
    final problem = _validate(state);
    if (problem != null) {
      HapticFeedback.heavyImpact();
      showFriendly(context, problem);
      return;
    }

    setState(() => _busy = true);
    final amount = _amount;
    final money = formatMoney(amount, _currency);

    final auth =
        await AuthService.confirm('Pay $money to ${widget.qr.merchantName}');
    if (!mounted) return;
    if (auth == AuthOutcome.cancelled) {
      setState(() => _busy = false);
      showFriendly(context, Friendly.authCancelled);
      return;
    }
    if (auth == AuthOutcome.unavailable) {
      final ok = await _fallbackConfirm(money);
      if (!mounted) return;
      if (ok != true) {
        setState(() => _busy = false);
        return;
      }
    }

    _refNo ??= generateRef16();
    _hash ??= generateRef16();
    setState(() => _sending = true);

    final account = state.selected;
    final result = await state.api.confirmKhqr(
      qr: widget.qr,
      amount: amount,
      currency: _currency,
      refNo: _refNo!,
      khqrHash: _hash!,
      note: _remark,
    );
    if (!mounted) return;
    state.record(account, result, _remark);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }
    // A clear failure (offline / declined) can be retried with a fresh ref;
    // "pending" keeps the same ref so a retry can never double-charge.
    if (result.status == PaymentStatus.declined ||
        result.status == PaymentStatus.failed) {
      _refNo = null;
      _hash = null;
    }

    setState(() {
      _sending = false;
      _busy = false;
    });
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
          result: result, accountName: account.name, remark: _remark),
    ));
  }

  Future<bool?> _fallbackConfirm(String money) {
    final acc = AppStateScope.read(context).selected;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        qr: widget.qr,
        money: money,
        from: '${acc.name} ${maskAccount(acc.number)}',
        note: _remark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final acc = state.selected;
    final qr = widget.qr;
    final canPay = _amount > 0 && !_busy;
    final display = _locked
        ? formatMoney(_amount, _currency)
        : (_input.isEmpty
            ? '${_currency.symbol}0'
            : '${_currency.symbol}$_input');

    return Scaffold(
      backgroundColor: RB.night,
      body: Container(
        decoration: const BoxDecoration(gradient: RB.payGradient),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        // Header
                        Row(children: [
                          IconButton(
                            onPressed:
                                _busy ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                          ),
                          const Text('KHQR Pay',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          const Spacer(),
                          if (qr.isMerchant)
                            const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Row(children: [
                                Icon(Icons.storefront_rounded,
                                    color: RB.gold, size: 18),
                                SizedBox(width: 4),
                                Text('Merchant',
                                    style: TextStyle(
                                        color: RB.gold,
                                        fontWeight: FontWeight.w700)),
                              ]),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        // Payee
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: RB.aqua,
                          child: Text(qr.initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 10),
                        Text(qr.merchantName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6)),
                        const SizedBox(height: 14),
                        // Currency toggle / lock chip
                        if (_locked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(30)),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline_rounded,
                                      color: RB.gold, size: 16),
                                  SizedBox(width: 6),
                                  Text('Amount set by merchant',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600)),
                                ]),
                          )
                        else
                          _CurrencyToggle(
                              value: _currency, onChanged: _setCurrency),
                        const SizedBox(height: 12),
                        // Amount
                        FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(display,
                                style: TextStyle(
                                    color: _amount > 0
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        if (qr.billNumber != null)
                          Text('Bill #${qr.billNumber}',
                              style: const TextStyle(color: Colors.white54)),
                        const SizedBox(height: 10),
                        // Pay from
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _busy
                              ? null
                              : () => showModalBottomSheet<void>(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (_) => const AccountPickerSheet(),
                                  ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                  'Pay from ${acc.name} ${maskAccount(acc.number)} | ',
                                  style: const TextStyle(color: Colors.white)),
                              Text(acc.currency.code,
                                  style: const TextStyle(
                                      color: RB.aqua,
                                      fontWeight: FontWeight.w700)),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: RB.aqua),
                            ]),
                          ),
                        ),
                        Text(
                          state.balanceVisible
                              ? 'Available ${formatMoney(acc.balance, acc.currency)}'
                              : 'Available balance hidden',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        // Remarks
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _RemarkChip(
                                label: _remark.isNotEmpty &&
                                        !_remarks.contains(_remark)
                                    ? _remark
                                    : 'Custom',
                                icon: Icons.edit_outlined,
                                selected: _remark.isNotEmpty &&
                                    !_remarks.contains(_remark),
                                onTap: _customRemark,
                              ),
                              for (final r in _remarks)
                                _RemarkChip(
                                  label: r,
                                  selected: _remark == r,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(
                                        () => _remark = _remark == r ? '' : r);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (!_locked)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AmountKeypad(
                        onKey: _onKey,
                        extraKey: _currency == KhqrCurrency.khr ? '00' : '.',
                      ),
                    )
                  else
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Text(
                        'Check the name and amount, then tap Pay.\n'
                        'សូមពិនិត្យឈ្មោះ និងចំនួនទឹកប្រាក់ រួចចុច "ទូទាត់"។',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, height: 1.5),
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Pay button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: canPay
                            ? const LinearGradient(
                                colors: [RB.gold, RB.goldDeep])
                            : null,
                        color: canPay
                            ? null
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _busy
                              ? null
                              : (canPay
                                  ? _pay
                                  : () => showFriendly(
                                      context, Friendly.enterAmount)),
                          child: Center(
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.fingerprint_rounded,
                                  color: canPay ? RB.ink : Colors.white38),
                              const SizedBox(width: 8),
                              Text(
                                canPay
                                    ? 'PAY ${formatMoney(_amount, _currency)}'
                                    : 'PAY NOW',
                                style: TextStyle(
                                  color: canPay ? RB.ink : Colors.white38,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_sending)
                _SendingOverlay(
                    money: formatMoney(_amount, _currency),
                    payee: widget.qr.merchantName),
            ],
          ),
        ),
      ),
    );
  }
}

/// Branded confirm step used when the phone has no fingerprint / screen lock.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.qr,
    required this.money,
    required this.from,
    required this.note,
  });
  final KhqrData qr;
  final String money;
  final String from;
  final String note;

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(k, style: const TextStyle(color: RB.muted, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: RB.ink, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RB.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [RB.gold, RB.goldDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color: RB.gold.withValues(alpha: 0.35), blurRadius: 18)
                ],
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 12),
            const Text('Confirm payment',
                style: TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, color: RB.ink)),
            const Text('បញ្ជាក់ការទូទាត់',
                style: TextStyle(fontSize: 14, color: RB.muted)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 12)
                ],
              ),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: RB.aqua,
                    child: Text(qr.initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pay to',
                            style: TextStyle(color: RB.muted, fontSize: 12)),
                        Text(qr.merchantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: RB.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ]),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: RB.sand),
                ),
                Text(money,
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: RB.ink,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _row('From', from),
                if (note.isNotEmpty) _row('Note', note),
              ]),
            ),
            const SizedBox(height: 12),
            const Row(children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: RB.muted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Set a screen lock to pay faster with fingerprint or Face ID.',
                    style: TextStyle(color: RB.muted, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: RB.teal,
                    side: const BorderSide(color: RB.teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [RB.gold, RB.goldDeep]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, true);
                      },
                      child: SizedBox(
                        height: 54,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fingerprint_rounded,
                                  color: RB.ink),
                              const SizedBox(width: 8),
                              Text('Pay $money',
                                  style: const TextStyle(
                                      color: RB.ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({required this.value, required this.onChanged});
  final KhqrCurrency value;
  final ValueChanged<KhqrCurrency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final c in KhqrCurrency.values)
          GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 92,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: c == value ? RB.aqua : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text(c.code,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c == value ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}

class _RemarkChip extends StatelessWidget {
  const _RemarkChip(
      {required this.label,
      required this.onTap,
      this.icon,
      this.selected = false});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? RB.aqua.withValues(alpha: 0.25) : Colors.transparent,
        shape: StadiumBorder(
            side: BorderSide(color: selected ? RB.aqua : Colors.white24)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: RB.aqua),
                const SizedBox(width: 6)
              ],
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Full-screen "sending" state: blurred backdrop, card with a spinning gold
/// ring around a shield, the amount and payee, and calm bilingual copy.
class _SendingOverlay extends StatefulWidget {
  const _SendingOverlay({required this.money, required this.payee});
  final String money;
  final String payee;

  @override
  State<_SendingOverlay> createState() => _SendingOverlayState();
}

class _SendingOverlayState extends State<_SendingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 300,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                decoration: BoxDecoration(
                  color: RB.cream,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55000000), blurRadius: 30)
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(alignment: Alignment.center, children: [
                      RotationTransition(
                        turns: _spin,
                        child: const CustomPaint(
                            size: Size.square(92), painter: _RingPainter()),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [RB.teal, RB.navy],
                          ),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: RB.gold, size: 32),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  const Text('Sending securely…',
                      style: TextStyle(
                          color: RB.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                  const Text('កំពុងទូទាត់ដោយសុវត្ថិភាព…',
                      style: TextStyle(color: RB.muted, fontSize: 13)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      Text(widget.money,
                          style: const TextStyle(
                              color: RB.ink,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('to ${widget.payee}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: RB.muted, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: RB.muted),
                    SizedBox(width: 6),
                    Text("Please don't close the app",
                        style: TextStyle(color: RB.muted, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold arc that fades along its length - spun by _SendingOverlay.
class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    canvas.drawArc(
        rect,
        0,
        6.2832,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = RB.sand);
    canvas.drawArc(
      rect,
      0,
      4.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(colors: [
          RB.gold.withValues(alpha: 0.0),
          RB.gold,
          RB.goldDeep,
        ], stops: const [
          0.0,
          0.55,
          0.7
        ]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
