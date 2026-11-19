import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'services/api_log.dart';
import 'services/api_settings.dart';
import 'services/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  final settings = ApiSettings();
  // Draw the first frame right away; storage loads run in parallel behind it.
  // Payments await settings.ready, so nothing uses half-loaded values.
  runApp(RomdoulBankApp(state: AppState(settings)));
  unawaited(settings.load());
  unawaited(ApiLog.instance.load());
}

class RomdoulBankApp extends StatelessWidget {
  const RomdoulBankApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        title: AppConfig.bankName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
