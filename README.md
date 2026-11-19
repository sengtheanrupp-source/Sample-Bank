# Romdoul Bank (sample) — KHQR Scan & Pay

A Flutter sample bank app that does **one thing really well: scan any KHQR and pay fast.**
It uses the same `POST /qr/v2/confirm` contract as the Telegram mini payment app (`app.js`).

> "Romdoul Bank" is a fictional brand (named after Cambodia's national flower) with original
> artwork drawn in code. It does not copy any real bank's logo or brand.

---

## 1. Team review (product · engineering · risk · UX)

| Topic | Decision |
|---|---|
| Scope | KHQR Pay only. Other home tiles show a friendly "coming soon" message that points back to Scan. |
| Speed | QR-only scanning with no duplicate reads. Opens straight to Pay. The Pay screen has the amount pre-filled from dynamic QRs, then one tap and biometric check. Haptic feedback at every step. |
| Static vs dynamic QR | Static (`01=11`): big keypad, KHR/USD toggle, `00` key for riel, `.` key for USD. Dynamic (`01=12`): amount locked and shown as *"Amount set by merchant"*. |
| QR safety | Full EMV TLV parsing plus **CRC-16 check**, so a damaged or edited QR is rejected before the Pay screen opens. Expired QRs (tag 99) are blocked. |
| Double-charge protection | The Pay button locks while sending. `ref_no` is generated once per payment and **kept on a timeout or 5xx**, so a retry can be de-duplicated by the backend. |
| Honest results | Timeout or 5xx shows *"Still confirming… don't pay again"*, never "failed". Offline or declined shows *"Nothing was charged"*. 401/403 shows *"Session expired"*. |
| Friendly messages | Every message is in **English + Khmer**, short, calm, and tells the user what to do next (`lib/services/messages.dart`). Please have a native speaker review the Khmer text before release. |
| Auth | Face ID / fingerprint / device PIN before every payment and before opening Settings. |
| Limits | Per-payment limits ($10,000 / ៛40,000,000) and a balance check before the API is called. |
| Confirm step | When the phone has no fingerprint / screen lock, a branded bottom sheet (shield icon, payee, amount, From account, gold **Pay** button) replaces the plain dialog. |
| API log (support) | Every `/qr/v2/confirm` call is logged on-device: URL, headers (**token masked**), request body, HTTP status, duration, response body, exception. Newest 50 kept, *Clear* button. Open it only from **Settings → API log** (behind fingerprint / PIN). Customers never see technical details on the result screen. |
| Unknown errors | Any unexpected exception during payment shows *Still confirming* (not *Failed*), because we can't be sure nothing was booked. The *Sending…* overlay can no longer get stuck. |

## 2. API (same as Telegram mini app)

```
POST {BASE_URL}/qr/v2/confirm
Headers: Content-Type: application/json · accept: */* · token: <API token>
Body: { khqr_string, currency, amount, ref_no, note, issuer_id, issuer_name, khqr_hash }
Success when response.code == "SUCCESS"; reads data.total_amount, fee_amount, paid_to, paid_date
```

### Settings screen (⚙ on Home)
Change these at runtime, no rebuild needed:
- **Base domain URL** (shows a preview of the full endpoint)
- **Header `token`** (stored in iOS Keychain / Android encrypted storage, with paste and show/hide)
- **Issuer ID** (default `issuing@Bank`)
- **Demo mode** (simulates success with no network call; also on automatically when no token is set)

You can also set build-time defaults:
```
flutter run --dart-define=BASE_URL=https://staging.bill24.io:22080 --dart-define=API_TOKEN=xxxx
```

## 3. Run locally

Requires Flutter 3.27+ (stable).
```bash
bash setup.sh        # flutter create (keeps our files) + iOS 15.5 Podfile + pub get
flutter test         # KHQR parser tests
flutter run
```
Test without a merchant: open `samples/*.png` on another screen and scan it, or save one to your phone and use **Upload QR**.
(`tools/make_sample_khqr.py` generates more.)

## 4. Build APK & iOS

**Locally**
```bash
flutter build apk --release --split-per-abi     # build/app/outputs/flutter-apk/
flutter build ipa --release                     # macOS + Xcode + Apple signing required
```

**GitHub Actions** (`.github/workflows/build.yml`): push to `main`, or run it manually.
- `android` job: analyze, test, then release APKs as downloadable artifacts.
- `ios` job: unsigned `.xcarchive`. For TestFlight, add your signing certificate and provisioning profile as secrets, then replace `--no-codesign` with `--export-options-plist`.

Before the Play Store: create a release keystore and set `signingConfigs` in `android/app/build.gradle(.kts)`. The generated project signs release builds with the debug key.

## 5. Before production (risk team notes)

1. **Don't ship a shared API token in the app.** Anyone can pull it out of an APK. In production, the app should call your own backend with the user's session, and the backend calls `/qr/v2/confirm`. The `token` currently hard-coded in the Telegram app's `index.html` should be rotated.
2. Confirm with the backend that `ref_no` is idempotent, which makes retries safe.
3. Accounts and balances here are in-memory samples (Savings $250,000, Daily Riel ៛500,000,000). Connect them to core banking.
4. Add certificate pinning, root/jailbreak detection and screenshot protection on payment screens, as your security policy requires.

## Project map
```
lib/
  main.dart · config.dart · theme.dart
  models/khqr.dart            EMV TLV + CRC16 KHQR parser
  services/payment_api.dart   /qr/v2/confirm client + error mapping
  services/api_settings.dart  runtime base URL / token / issuer / demo
  services/app_state.dart     sample accounts, balance, history
  services/auth_service.dart  biometric / device PIN
  services/messages.dart      bilingual friendly messages
  screens/ home · scan · pay · result · settings
  widgets/ art (temple header, logo) · keypad · friendly_toast
```
