import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/khqr.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/payment_api.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/art.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openScan(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  Future<void> _openSettings(BuildContext context) async {
    final auth = await AuthService.confirm('Verify to open API settings');
    if (!context.mounted || auth == AuthOutcome.cancelled) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _soon(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
            '$name is coming soon - this sample focuses on fast KHQR Pay.'),
        action:
            SnackBarAction(label: 'Scan', onPressed: () => _openScan(context)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final acc = state.selected;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 330 + top,
            child: const CustomPaint(painter: TempleHeaderPainter()),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(18, top + 10, 18, 120),
            children: [
              // ---- Top bar ----
              Row(
                children: [
                  const RomdoulLogo(size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}!',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const Text(AppConfig.bankName,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  if (state.settings.useMock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: RB.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('DEMO',
                          style: TextStyle(
                              color: RB.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => _soon(context, 'Notifications'),
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ---- Balance card ----
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            // Default layout centers the text; keep it left-aligned with the row below.
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previous,
                                if (current != null) current
                              ],
                            ),
                            child: Text(
                              state.balanceVisible
                                  ? formatMoney(acc.balance, acc.currency)
                                  : '${acc.currency.symbol} ••••••',
                              key: ValueKey(state.balanceVisible),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: state.toggleBalance,
                          icon: Icon(state.balanceVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: RB.gold,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('Default',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: RB.ink)),
                      ),
                      const SizedBox(width: 8),
                      Text('${acc.name} · ${maskAccount(acc.number)}',
                          style: const TextStyle(color: Colors.white70)),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _CardAction(Icons.south_west_rounded, 'Receive',
                            () => _soon(context, 'Receive')),
                        _CardAction(Icons.north_east_rounded, 'Send',
                            () => _soon(context, 'Send')),
                        _CardAction(Icons.insights_rounded, 'Analytics',
                            () => _soon(context, 'Analytics')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---- Hero: Scan KHQR ----
              _ScanHero(onTap: () => _openScan(context)),
              const SizedBox(height: 16),

              // ---- Grid ----
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _Tile(
                      Icons.account_balance_wallet_rounded,
                      'Accounts',
                      const [Color(0xFF2DD4BF), Color(0xFF0F766E)],
                      () => _showAccounts(context)),
                  _Tile(
                      Icons.credit_card_rounded,
                      'Cards',
                      const [Color(0xFF818CF8), Color(0xFF4338CA)],
                      () => _soon(context, 'Cards')),
                  _Tile(
                      Icons.receipt_long_rounded,
                      'Payments',
                      const [Color(0xFFFDBA74), Color(0xFFEA580C)],
                      () => _soon(context, 'Payments')),
                  _Tile(
                      Icons.qr_code_scanner_rounded,
                      'KHQR Scan',
                      const [Color(0xFFFCD34D), RB.goldDeep],
                      () => _openScan(context),
                      badge: 'FAST'),
                  _Tile(
                      Icons.favorite_rounded,
                      'Favorites',
                      const [Color(0xFFF9A8D4), Color(0xFFDB2777)],
                      () => _soon(context, 'Favorites')),
                  _Tile(
                      Icons.swap_horiz_rounded,
                      'Transfers',
                      const [Color(0xFF7DD3FC), Color(0xFF0369A1)],
                      () => _soon(context, 'Transfers')),
                ],
              ),
              const SizedBox(height: 22),

              // ---- Recent ----
              Text('Recent payments',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (state.history.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18)),
                  child: const Row(children: [
                    Icon(Icons.bolt_rounded, color: RB.goldDeep),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'No payments yet. Scan any KHQR to pay in seconds.\n'
                          'មិនទាន់មានការទូទាត់ទេ។ ស្កេន KHQR ដើម្បីទូទាត់ភ្លាមៗ។',
                          style: TextStyle(color: RB.muted, height: 1.4)),
                    ),
                  ]),
                )
              else
                ...state.history.take(8).map((t) => _TxTile(t)),
            ],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'scan',
        backgroundColor: RB.teal,
        foregroundColor: Colors.white,
        onPressed: () => _openScan(context),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan & Pay',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showAccounts(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const AccountPickerSheet(),
    );
  }
}

/// Shared account picker (Home + Pay screen).
class AccountPickerSheet extends StatelessWidget {
  const AccountPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Pay from',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          for (final a in state.accounts)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: RB.sand,
                child: Text(a.currency.symbol,
                    style: const TextStyle(
                        color: RB.teal, fontWeight: FontWeight.w800)),
              ),
              title: Text(a.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${maskAccount(a.number)} · ${a.currency.code}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(formatMoney(a.balance, a.currency),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Icon(
                  a.id == state.selected.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: RB.teal,
                ),
              ]),
              onTap: () {
                HapticFeedback.selectionClick();
                state.select(a);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            Icon(icon, color: RB.gold, size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [RB.gold, RB.goldDeep]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: RB.goldDeep.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: RB.ink, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.qr_code_scanner_rounded,
                    color: RB.gold, size: 30),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan KHQR to pay',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: RB.ink)),
                      Text('ស្កេន KHQR ដើម្បីទូទាត់',
                          style: TextStyle(color: RB.ink, fontSize: 12)),
                    ]),
              ),
              const Icon(Icons.arrow_forward_rounded, color: RB.ink),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.colors, this.onTap, {this.badge});
  final IconData icon;
  final String label;
  final List<Color> colors; // [light, deep]
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: colors.last.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Stack(children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon3D(icon: icon, colors: colors),
                  const SizedBox(height: 10),
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: RB.ink)),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Glossy "3D" app-style icon: gradient squircle, top light reflection,
/// colored depth shadow and an embossed white glyph.
class Icon3D extends StatelessWidget {
  const Icon3D(
      {super.key, required this.icon, required this.colors, this.size = 52});
  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * 0.32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          // colored glow underneath = depth
          BoxShadow(
              color: colors.last.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: Offset(0, size * 0.14)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(children: [
          // darker base for volume
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ),
          // glossy top reflection
          Positioned(
            left: -size * 0.2,
            right: -size * 0.2,
            top: -size * 0.55,
            height: size * 0.95,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
          // inner rim light
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35), width: 1),
              ),
            ),
          ),
          Center(
            child: Icon(icon, size: size * 0.52, color: Colors.white, shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile(this.t);
  final TxRecord t;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (t.status) {
      PaymentStatus.success => (RB.success, 'Paid'),
      PaymentStatus.pending => (RB.warn, 'Checking'),
      _ => (RB.danger, 'Not paid'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.qr_code_2_rounded, color: color),
        ),
        title: Text(t.merchant,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${formatDateTime(t.at)}${t.remark.isEmpty ? '' : ' · ${t.remark}'}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('-${formatMoney(t.amount, t.currency)}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
