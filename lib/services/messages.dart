import 'package:flutter/material.dart';

import '../models/khqr.dart';

enum Tone { success, info, warning, error }

/// A short, human message in English + Khmer. Every error the user can see
/// comes from here so wording stays calm, consistent and actionable.
class Friendly {
  final String title;
  final String titleKm;
  final String body;
  final String bodyKm;
  final Tone tone;

  const Friendly(this.title, this.titleKm, this.body, this.bodyKm, this.tone);

  IconData get icon => switch (tone) {
        Tone.success => Icons.check_rounded,
        Tone.info => Icons.info_outline_rounded,
        Tone.warning => Icons.hourglass_top_rounded,
        Tone.error => Icons.error_outline_rounded,
      };

  Friendly withBody(String en) => Friendly(title, titleKm, en, bodyKm, tone);

  // ---- Scanning ----
  static const notKhqr = Friendly(
    "This isn't a KHQR code",
    'កូដនេះមិនមែនជា KHQR ទេ',
    'Please scan the KHQR shown by the merchant.',
    'សូមស្កេនកូដ KHQR របស់អ្នកលក់។',
    Tone.error,
  );
  static const badChecksum = Friendly(
    'QR code looks damaged',
    'កូដ QR ហាក់ដូចជាខូច',
    'Hold your phone steady, or ask the merchant for a new code.',
    'សូមកាន់ទូរស័ព្ទឲ្យនឹង ឬស្នើសុំកូដថ្មីពីអ្នកលក់។',
    Tone.error,
  );
  static const qrExpired = Friendly(
    'This QR has expired',
    'កូដ QR នេះផុតកំណត់ហើយ',
    'Ask the merchant to create a new one.',
    'សូមឲ្យអ្នកលក់បង្កើតកូដថ្មី។',
    Tone.warning,
  );
  static const noQrInImage = Friendly(
    'No QR found in that photo',
    'រកមិនឃើញកូដ QR ក្នុងរូបភាពនេះទេ',
    'Try a clearer screenshot of the KHQR.',
    'សូមសាកល្បងរូបថតអេក្រង់ដែលច្បាស់ជាងនេះ។',
    Tone.info,
  );
  static const cameraDenied = Friendly(
    'Camera access is off',
    'ការប្រើកាមេរ៉ាត្រូវបានបិទ',
    'Turn on camera in Settings, or use Upload QR below.',
    'សូមបើកកាមេរ៉ានៅក្នុងការកំណត់ ឬប្រើ "បញ្ចូល QR" ខាងក្រោម។',
    Tone.info,
  );

  static const noFlash = Friendly(
    'No flashlight on this phone',
    'ទូរស័ព្ទនេះគ្មានពិល',
    'Move to a brighter spot or turn up the light, or use Upload QR.',
    'សូមផ្លាស់ទីទៅកន្លែងភ្លឺជាងនេះ ឬប្រើ "បញ្ចូល QR"។',
    Tone.info,
  );

  static Friendly fromKhqr(KhqrError e) => switch (e) {
        KhqrError.notKhqr => notKhqr,
        KhqrError.badChecksum => badChecksum,
        KhqrError.malformed => badChecksum,
      };

  // ---- Before paying ----
  static const enterAmount = Friendly(
    'Enter an amount',
    'សូមបញ្ចូលចំនួនទឹកប្រាក់',
    'Type how much you want to pay.',
    'សូមវាយបញ្ចូលចំនួនដែលអ្នកចង់ទូទាត់។',
    Tone.info,
  );
  static const insufficient = Friendly(
    'Not enough balance',
    'សមតុល្យមិនគ្រប់គ្រាន់',
    'Choose another account or top up first.',
    'សូមជ្រើសរើសគណនីផ្សេង ឬបញ្ចូលប្រាក់ជាមុនសិន។',
    Tone.warning,
  );
  static const overLimit = Friendly(
    'Above the per-payment limit',
    'លើសដែនកំណត់ក្នុងមួយប្រតិបត្តិការ',
    'Please pay a smaller amount.',
    'សូមទូទាត់ចំនួនតិចជាងនេះ។',
    Tone.warning,
  );
  static const authCancelled = Friendly(
    'Payment not sent',
    'ការទូទាត់មិនទាន់បានផ្ញើទេ',
    'Verification was cancelled. Your money is safe.',
    'ការផ្ទៀងផ្ទាត់ត្រូវបានបោះបង់។ ប្រាក់របស់អ្នកនៅសុវត្ថិភាព។',
    Tone.info,
  );

  // ---- Result ----
  static const success = Friendly(
    'Payment successful',
    'ការទូទាត់បានជោគជ័យ',
    'Thank you! Your payment was sent.',
    'សូមអរគុណ! ការទូទាត់របស់អ្នកត្រូវបានផ្ញើ។',
    Tone.success,
  );
  static const declined = Friendly(
    'Payment declined',
    'ការទូទាត់ត្រូវបានបដិសេធ',
    'Nothing was charged. Please try again.',
    'មិនទាន់កាត់ប្រាក់ទេ។ សូមព្យាយាមម្តងទៀត។',
    Tone.error,
  );
  static const offline = Friendly(
    'No internet connection',
    'គ្មានការតភ្ជាប់អ៊ីនធឺណិត',
    'Nothing was charged. Check your connection and try again.',
    'មិនទាន់កាត់ប្រាក់ទេ។ សូមពិនិត្យការតភ្ជាប់ ហើយព្យាយាមម្តងទៀត។',
    Tone.error,
  );
  static const pending = Friendly(
    'Still confirming…',
    'កំពុងបញ្ជាក់…',
    "The bank is taking longer than usual. Please don't pay again - check your history in a moment.",
    'ធនាគារត្រូវការពេលយូរជាងធម្មតា។ សូមកុំទូទាត់ម្តងទៀត — សូមពិនិត្យប្រវត្តិប្រតិបត្តិការបន្តិចទៀត។',
    Tone.warning,
  );
  static const badConfig = Friendly(
    'Payment service not set up',
    'សេវាទូទាត់មិនទាន់បានកំណត់',
    'Nothing was charged. Please check the API settings.',
    'មិនទាន់កាត់ប្រាក់ទេ។ សូមពិនិត្យការកំណត់ API។',
    Tone.error,
  );
  static const session = Friendly(
    'Session expired',
    'សម័យប្រើប្រាស់បានផុតកំណត់',
    'Please sign in again. Nothing was charged.',
    'សូមចូលម្តងទៀត។ មិនទាន់កាត់ប្រាក់ទេ។',
    Tone.error,
  );
}
