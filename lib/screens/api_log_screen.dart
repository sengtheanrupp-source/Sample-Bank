import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_log.dart';
import '../theme.dart';
import '../utils/format.dart';

Color _tone(ApiLogEntry e) => switch (e.outcome) {
      'success' => RB.success,
      'demo' => RB.aqua,
      'pending' => RB.warn,
      _ => RB.danger,
    };

/// Every /qr/v2/confirm call made on this device, newest first.
class ApiLogScreen extends StatelessWidget {
  const ApiLogScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear API log?'),
        content:
            const Text('All saved requests and responses will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await ApiLog.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    final log = ApiLog.instance;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final items = log.entries;
        return Scaffold(
          appBar: AppBar(
            title: const Text('API log',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Clear log',
                  onPressed: () => _clear(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: items.isEmpty
              ? const _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        'Last ${items.length} of max ${ApiLog.maxEntries} calls · '
                        'stored on this phone only · token is masked',
                        style: const TextStyle(color: RB.muted, fontSize: 12),
                      );
                    }
                    return _EntryCard(items[i - 1]);
                  },
                ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: RB.muted),
            SizedBox(height: 12),
            Text('No API calls yet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            SizedBox(height: 4),
            Text('Make a payment and each request and response will show here.',
                textAlign: TextAlign.center, style: TextStyle(color: RB.muted)),
          ]),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.e);
  final ApiLogEntry e;

  @override
  Widget build(BuildContext context) {
    final c = _tone(e);
    final label =
        e.statusCode?.toString() ?? (e.outcome == 'demo' ? 'DEMO' : 'ERR');
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: c, fontWeight: FontWeight.w800)),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard(this.e);
  final ApiLogEntry e;

  @override
  Widget build(BuildContext context) {
    final path = Uri.tryParse(e.url.replaceFirst('(demo) ', ''))?.path ?? e.url;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ApiLogDetailScreen(entry: e))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            _StatusPill(e),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.method} $path',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: RB.ink)),
                  const SizedBox(height: 2),
                  Text(e.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _tone(e), fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('${formatDateTime(e.at)} · ${e.durationMs} ms',
                      style: const TextStyle(color: RB.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: RB.muted),
          ]),
        ),
      ),
    );
  }
}

/// Full request / response of one call, selectable and copyable.
class ApiLogDetailScreen extends StatelessWidget {
  const ApiLogDetailScreen({super.key, required this.entry});
  final ApiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final report = e.toReport();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call details',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Copied - paste it to the backend team')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _tone(e).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _tone(e).withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              _StatusPill(e),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.reason,
                        style: TextStyle(
                            color: _tone(e), fontWeight: FontWeight.w800)),
                    Text(
                        '${formatDateTime(e.at)} · ${e.durationMs} ms · ${e.outcome}',
                        style: const TextStyle(color: RB.muted, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          SelectableText(
            report,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
                color: RB.ink),
          ),
        ],
      ),
    );
  }
}
