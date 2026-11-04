import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/route_names.dart';
import 'core/theme/app_theme.dart';
import 'prototype/care_flow.dart';
import 'prototype/prototype_routes.dart';
import 'prototype/prototype_session.dart';
import 'prototype/splash_screen.dart';
import 'services/account_service.dart';
import 'services/cloud/cloud_session.dart';
import 'services/cloud/supabase_api.dart';
import 'services/connect_service.dart';
import 'services/hr_service.dart';
import 'services/inventory_service.dart';
import 'services/localization_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FindDoctorRoot());
}

/// Shows the opening animation while the cloud connection starts and the signed-in
/// account loads, then fades into the app.
class FindDoctorRoot extends StatefulWidget {
  const FindDoctorRoot({super.key});

  @override
  State<FindDoctorRoot> createState() => _FindDoctorRootState();
}

class _FindDoctorRootState extends State<FindDoctorRoot> {
  /// The animation stays at least this long, so it never just flickers.
  static const _minimumSplash = Duration(milliseconds: 2200);

  final _status = ValueNotifier<String>('Starting…');
  bool _ready = false;
  AppAccount? _initialAccount;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final minimum = Future<void>.delayed(_minimumSplash);
    AppAccount? account;
    var online = true;
    _status.value = 'Connecting…';
    try {
      // Restores the saved Supabase sign-in (if any).
      await CloudAuth.instance.init();
    } catch (error) {
      online = false;
      debugPrint('Find Doctor: cloud could not start: $error');
    }
    if (online) {
      _status.value = 'Checking your account…';
      try {
        account = await AccountService.instance.restoreSession();
      } catch (_) {
        // Start signed out if the saved session can't be read.
      }
      CloudSession.start();
      if (account != null) {
        _status.value = 'Loading your data…';
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
    _status.value = 'Almost ready…';
    await minimum;
    if (!mounted) return;
    setState(() {
      _initialAccount = account;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _ready
            ? FindDoctorApp(
                key: const ValueKey('app'), initialAccount: _initialAccount)
            : MaterialApp(
                key: const ValueKey('splash'),
                title: 'Find Doctor',
                debugShowCheckedModeBanner: false,
                home: SplashScreen(status: _status),
              ),
      ),
    );
  }
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
