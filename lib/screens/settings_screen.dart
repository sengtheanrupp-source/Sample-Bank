import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/api_log.dart';
import '../services/api_settings.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'api_log_screen.dart';

/// API settings: base domain URL, `token` header, issuer id, demo mode.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final ApiSettings _settings;
  late final TextEditingController _url;
  late final TextEditingController _token;
  late final TextEditingController _issuer;
  late bool _demo;
  bool _showToken = false;
  bool _saving = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _settings = AppStateScope.read(context).settings;
    _url = TextEditingController(text: _settings.baseUrl);
    _token = TextEditingController(text: _settings.token);
    _issuer = TextEditingController(text: _settings.issuerId);
    _demo = _settings.demoMode;
    if (!_settings.isLoaded) _refillWhenLoaded();
  }

  /// Screen opened before storage finished loading: swap the defaults for
  /// the saved values, unless the user has already started typing.
  Future<void> _refillWhenLoaded() async {
    final url = _url.text, token = _token.text, issuer = _issuer.text;
    final demo = _demo;
    await _settings.ready;
    if (!mounted) return;
    if (_url.text != url ||
        _token.text != token ||
        _issuer.text != issuer ||
        _demo != demo) {
      return;
    }
    setState(() {
      _url.text = _settings.baseUrl;
      _token.text = _settings.token;
      _issuer.text = _settings.issuerId;
      _demo = _settings.demoMode;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _issuer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _settings.save(
        baseUrl: _url.text,
        token: _token.text,
        issuerId: _issuer.text,
        demoMode: _demo,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: RB.success,
        content: Text(_settings.useMock
            ? 'Saved. App is in DEMO mode - no real payments.'
            : 'Saved. Payments go to ${_settings.confirmUrl}'),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: RB.danger,
        content: Text("Couldn't save settings: $e"),
      ));
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset API settings?'),
        content: const Text(
            'Base URL, token and issuer ID go back to the build defaults.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    await _settings.resetToDefaults();
    if (!mounted) return;
    setState(() {
      _url.text = _settings.baseUrl;
      _token.text = _settings.token;
      _issuer.text = _settings.issuerId;
      _demo = _settings.demoMode;
    });
  }

  InputDecoration _dec(String label,
          {String? hint, Widget? suffix, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  @override
  Widget build(BuildContext context) {
    final preview =
        '${_url.text.trim().replaceAll(RegExp(r'/+$'), '')}${AppConfig.confirmPath}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              tooltip: 'Reset to defaults',
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _dec('Base domain URL',
                  hint: 'https://api.yourbank.com', helper: 'POST → $preview'),
              validator: (v) => ApiSettings.validateBaseUrl(v ?? ''),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _token,
              obscureText: !_showToken,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _dec(
                'Header: token',
                hint: 'Paste API token',
                helper: 'Sent as the "token" header. Stored in secure storage.',
                suffix: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Paste',
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: () async {
                      final data =
                          await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        setState(() => _token.text = data!.text!.trim());
                      }
                    },
                  ),
                  IconButton(
                    tooltip: _showToken ? 'Hide' : 'Show',
                    icon: Icon(_showToken
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showToken = !_showToken),
                  ),
                ]),
              ),
              validator: (v) => (!_demo && (v ?? '').trim().isEmpty)
                  ? 'Token is required when Demo mode is off'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _issuer,
              autocorrect: false,
              decoration: _dec('Issuer ID',
                  hint: 'issuing@Bank',
                  helper: 'Sent as issuer_id in the payload.'),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                value: _demo,
                onChanged: (v) => setState(() => _demo = v),
                title: const Text('Demo mode',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    const Text('Simulate success without calling the API.'),
              ),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: ApiLog.instance,
              builder: (context, _) {
                final last = ApiLog.instance.entries.firstOrNull;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: const CircleAvatar(
                      backgroundColor: RB.sand,
                      child: Icon(Icons.receipt_long_rounded, color: RB.teal),
                    ),
                    title: const Text('API log',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(last == null
                        ? 'No calls yet'
                        : '${ApiLog.instance.entries.length} calls · last: ${last.reason}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ApiLogScreen())),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RB.sand,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Request headers: Content-Type: application/json · accept: */* · token: <your token>\n'
                'Body: khqr_string, currency, amount, ref_no, note, issuer_id, issuer_name, khqr_hash',
                style: TextStyle(fontSize: 12, color: RB.ink, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: RB.teal,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : const Text('Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
