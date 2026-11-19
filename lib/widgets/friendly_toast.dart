import 'package:flutter/material.dart';

import '../services/messages.dart';
import '../theme.dart';

Color toneColor(Tone t) => switch (t) {
      Tone.success => RB.success,
      Tone.info => RB.teal,
      Tone.warning => RB.warn,
      Tone.error => RB.danger,
    };

/// Bilingual floating message (English + Khmer).
void showFriendly(BuildContext context, Friendly f) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    backgroundColor: toneColor(f.tone),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    duration: const Duration(seconds: 3),
    content: FriendlyText(f, light: true),
  ));
}

class FriendlyText extends StatelessWidget {
  const FriendlyText(this.f,
      {super.key, this.light = false, this.center = false});
  final Friendly f;
  final bool light;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final main = light ? Colors.white : RB.ink;
    final sub = light ? Colors.white70 : RB.muted;
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(f.title,
            textAlign: align,
            style: TextStyle(
                color: main, fontWeight: FontWeight.w700, fontSize: 15)),
        Text(f.titleKm,
            textAlign: align, style: TextStyle(color: main, fontSize: 13)),
        const SizedBox(height: 4),
        Text(f.body,
            textAlign: align,
            style: TextStyle(color: sub, fontSize: 13, height: 1.3)),
        Text(f.bodyKm,
            textAlign: align,
            style: TextStyle(color: sub, fontSize: 12, height: 1.4)),
      ],
    );
  }
}
