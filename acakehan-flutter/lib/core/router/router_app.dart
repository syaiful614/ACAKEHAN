// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/core/router/router_app.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/provider_auth.dart';
import '../../presentation/screens/auth/halaman_daftar.dart';
import '../../presentation/screens/auth/halaman_masuk.dart';
import '../../presentation/screens/dashboard/halaman_dashboard.dart';
import '../constants/konstanta_app.dart';

final providerRouter = Provider<GoRouter>((ref) {
  final stateAuth = ref.watch(providerAuthNotifier);

  return GoRouter(
    initialLocation: NamaRoute.masuk,
    debugLogDiagnostics: true,

    redirect: (context, state) {
      final sudahLogin   = stateAuth.sudahLogin;
      final sedangMemuat = stateAuth.sedangMemuat;
      final lokasi       = state.matchedLocation;

      if (sedangMemuat) return null;

      final diHalamanAuth = lokasi == NamaRoute.masuk ||
                            lokasi == NamaRoute.daftar;

      if (!sudahLogin && !diHalamanAuth) return NamaRoute.masuk;
      if (sudahLogin && diHalamanAuth)   return NamaRoute.dashboard;

      return null;
    },

    routes: [
      GoRoute(
        path:    NamaRoute.masuk,
        builder: (_, __) => const HalamanMasuk(),
      ),
      GoRoute(
        path:    NamaRoute.daftar,
        builder: (_, __) => const HalamanDaftar(),
      ),
      GoRoute(
        path:    NamaRoute.dashboard,
        builder: (_, __) => const HalamanDashboard(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Halaman tidak ditemukan',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(state.error.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(NamaRoute.masuk),
              child: const Text('Kembali ke Login'),
            ),
          ],
        ),
      ),
    ),
  );
});
