import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/khqr.dart';
import '../services/messages.dart';
import '../theme.dart';
import '../widgets/friendly_toast.dart';
import 'pay_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // QR-only + no duplicates = fastest detection on both platforms.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  bool _handling = false;
  Friendly? _error;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && !_handling) {
      _quiet(_controller.start);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _quiet(_controller.stop);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _errorTimer?.cancel();
    _line.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _quiet(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {/* camera already in that state */}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _handleRaw(raw);
        return;
      }
    }
  }

  Future<void> _handleRaw(String raw) async {
    _handling = true;
    try {
      final qr = KhqrParser.parse(raw);
      if (qr.isExpired) {
        _showError(Friendly.qrExpired);
        return;
      }
      HapticFeedback.mediumImpact();
      await _quiet(_controller.stop);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PayScreen(qr: qr)),
      );
    } on KhqrException catch (e) {
      _showError(Friendly.fromKhqr(e.reason));
    }
  }

  void _showError(Friendly f) {
    HapticFeedback.heavyImpact();
    setState(() => _error = f);
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(milliseconds: 2400), () {
      _handling = false;
      if (mounted) setState(() => _error = null);
    });
  }

  Future<void> _upload() async {
    if (_handling) return;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final capture = await _controller.analyzeImage(file.path);
      String? raw;
      if (capture != null) {
        for (final b in capture.barcodes) {
          if ((b.rawValue ?? '').isNotEmpty) {
            raw = b.rawValue;
            break;
          }
        }
      }
      if (raw == null) {
        _showError(Friendly.noQrInImage);
        return;
      }
      await _handleRaw(raw);
    } catch (_) {
      _showError(Friendly.noQrInImage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, c) => _body(context, c.biggest)),
      ),
    );
  }

  Widget _body(BuildContext context, Size size) {
    final box = size.width * 0.68;
    final boxRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.40),
      width: box,
      height: box,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _CameraError(
              denied:
                  error.errorCode == MobileScannerErrorCode.permissionDenied,
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _OverlayPainter(boxRect))),
        // Animated scan line
        AnimatedBuilder(
          animation: _line,
          builder: (_, __) => Positioned(
            left: boxRect.left + 18,
            width: boxRect.width - 36,
            top: boxRect.top + 14 + (boxRect.height - 28) * _line.value,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                      color: RB.aqua.withValues(alpha: 0.8), blurRadius: 12)
                ],
                color: RB.aqua,
              ),
            ),
          ),
        ),
        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                const SizedBox(width: 48),
                const Expanded(
                  child: Text('KHQR Scan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                ),
              ]),
            ),
          ),
        ),
        // Hint under the frame
        Positioned(
          top: boxRect.bottom + 18,
          left: 24,
          right: 24,
          child: const Text(
            'Point at the KHQR - it scans automatically\nដាក់កាមេរ៉ាចំ KHQR — ស្កេនដោយស្វ័យប្រវត្តិ',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        // Friendly error card
        if (_error != null)
          Positioned(
            left: 20,
            right: 20,
            top: boxRect.top - 8,
            child: _ErrorCard(_error!),
          ),
        // Bottom actions
        Positioned(
          left: 20,
          right: 20,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (_, s, __) {
                      final on = s.torchState == TorchState.on;
                      // Torch is "unavailable" until the camera starts, and
                      // forever on phones without a flash unit.
                      final none = s.isInitialized &&
                          s.torchState == TorchState.unavailable;
                      return Opacity(
                        opacity: none ? 0.55 : 1,
                        child: _PillButton(
                          icon: on
                              ? Icons.flashlight_on_rounded
                              : Icons.flashlight_off_rounded,
                          label:
                              none ? 'No flash' : (on ? 'Flash on' : 'Flash'),
                          active: on,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (s.torchState == TorchState.unavailable) {
                              showFriendly(context, Friendly.noFlash);
                            } else {
                              _quiet(_controller.toggleTorch);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PillButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Upload QR',
                      onTap: _upload),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_rounded, color: RB.gold, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text('Pay any KHQR · all Bakong member banks',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.box);
  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(box, const Radius.circular(26));
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rr);
    canvas.drawPath(
        scrim, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const l = 34.0, r = 26.0;
    void corner(Offset o, double sx, double sy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + sy * l)
        ..lineTo(o.dx, o.dy + sy * r)
        ..arcToPoint(Offset(o.dx + sx * r, o.dy),
            radius: const Radius.circular(r), clockwise: sx * sy > 0)
        ..lineTo(o.dx + sx * l, o.dy);
      canvas.drawPath(path, p);
    }

    corner(box.topLeft, 1, 1);
    corner(box.topRight, -1, 1);
    corner(box.bottomLeft, 1, -1);
    corner(box.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => old.box != box;
}

class _PillButton extends StatelessWidget {
  const _PillButton(
      {required this.icon,
      required this.label,
      this.onTap,
      this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RB.gold : const Color(0xFF1F1F1F),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: active ? RB.ink : Colors.white),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: active ? RB.ink : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.f);
  final Friendly f;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor: toneColor(f.tone).withValues(alpha: 0.12),
            child: Icon(f.icon, color: toneColor(f.tone)),
          ),
          const SizedBox(width: 12),
          Expanded(child: FriendlyText(f)),
        ]),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.denied});
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final f = denied
        ? Friendly.cameraDenied
        : Friendly.cameraDenied
            .withBody("The camera couldn't start. Use Upload QR below.");
    return ColoredBox(
      color: RB.night,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white54, size: 56),
            const SizedBox(height: 14),
            FriendlyText(f, light: true, center: true),
          ]),
        ),
      ),
    );
  }
}
