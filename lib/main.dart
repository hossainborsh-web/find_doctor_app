import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/route_names.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'prototype/care_flow.dart';
import 'prototype/prototype_routes.dart';
import 'prototype/prototype_session.dart';
import 'services/account_service.dart';
import 'services/cloud/cloud_session.dart';
import 'services/connect_service.dart';
import 'services/hr_service.dart';
import 'services/inventory_service.dart';
import 'services/localization_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var online = true;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    online = false;
    debugPrint('Find Doctor: Firebase could not start: $error');
  }
  AppAccount? initialAccount;
  if (online) {
    try {
      initialAccount = await AccountService.instance.restoreSession();
    } catch (_) {
      // Start signed out if the saved session can't be read.
    }
    CloudSession.start();
    if (initialAccount != null) {
      // Give the first data a moment so screens don't open empty.
      try {
        await Future.wait([
          ConnectService.instance.load(),
          HrService.instance.load(),
          InventoryService().load(),
        ]).timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
  }
  runApp(FindDoctorApp(initialAccount: initialAccount));
}

class FindDoctorApp extends StatelessWidget {
  const FindDoctorApp({super.key, this.initialAccount});

  final AppAccount? initialAccount;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PrototypeSession>(
          create: (_) => PrototypeSession(initialAccount: initialAccount),
        ),
        ChangeNotifierProvider<CareStore>(create: (_) => CareStore()),
        ChangeNotifierProvider<ConnectService>.value(
            value: ConnectService.instance),
        ChangeNotifierProvider<InventoryService>.value(
            value: InventoryService()),
        ChangeNotifierProvider<HrService>.value(value: HrService.instance),
        ChangeNotifierProvider<LocalizationService>(
          create: (_) => LocalizationService()..loadSavedLocale(),
        ),
      ],
      child: const _FindDoctorAppView(),
    );
  }
}

class _FindDoctorAppView extends StatelessWidget {
  const _FindDoctorAppView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    final session = context.watch<PrototypeSession>();
    return MaterialApp(
      title: 'Find Doctor',
      debugShowCheckedModeBanner: false,
      locale: localization.locale,
      supportedLocales: LocalizationService.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: session.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute:
          session.isSignedIn ? RouteNames.explore : RouteNames.initial,
      onGenerateRoute: (settings) => generatePrototypeRoute(context, settings),
    );
  }
}
