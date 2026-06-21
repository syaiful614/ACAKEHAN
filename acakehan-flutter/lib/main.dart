// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/main.dart
//  Fungsi : Entry point utama — inisialisasi Flutter,
//           Riverpod, intl, dan konfigurasi tema aplikasi.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/router_app.dart';
import 'presentation/theme/tema_acakehan.dart';
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:                    Colors.transparent,
      statusBarIconBrightness:           Brightness.dark,
      systemNavigationBarColor:          Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    const ProviderScope(
      child: AplikasiAcakehan(),
    ),
  );
}
 
class AplikasiAcakehan extends ConsumerWidget {
  const AplikasiAcakehan({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(providerRouter);
    return MaterialApp.router(
      title:                      'Acakehan',
      debugShowCheckedModeBanner: false,
      theme:                      TemaAcakehan.temaTerang,
      themeMode:                  ThemeMode.light,
      routerConfig:               router,
      locale:                     const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}