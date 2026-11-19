import 'package:flutter/material.dart';

/// Big, thumb-friendly number pad. [extraKey] is "00" for KHR or "." for USD.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey, required this.extraKey});

  final ValueChanged<String> onKey;
  final String extraKey;

  static const backspace = '⌫';

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [extraKey, '0', backspace],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(children: [for (final k in row) Expanded(child: _Key(k, onKey))]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.onKey);
  final String label;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onKey(label),
          onLongPress:
              label == AmountKeypad.backspace ? () => onKey('CLEAR') : null,
          child: SizedBox(
            height: 54,
            child: Center(
              child: label == AmountKeypad.backspace
                  ? const Icon(Icons.backspace_outlined,
                      color: Colors.white, size: 24)
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
