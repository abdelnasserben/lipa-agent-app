import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'core/widgets/lipa_brand.dart';
import 'features/agent/agent_shell.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/session_controller.dart';

/// Root widget. Switches between the auth surface and the agent shell based on
/// session state. Like the Lipa customer app, there is no GoRouter URL tree —
/// the agent app is a single-actor mobile shell with in-tab navigation; the
/// top-level branch is purely auth vs. authenticated.
class LipaAgentApp extends ConsumerWidget {
  const LipaAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return MaterialApp(
      title: 'Lipa Agent',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: switch (session.status) {
        SessionStatus.unknown => const _Splash(),
        SessionStatus.unauthenticated => const AuthScreen(),
        SessionStatus.authenticated => const AgentShell(),
      },
    );
  }
}

/// First-frame splash shown while the session resolves — the warm Lipa surface
/// with the agent wordmark and a thin progress hint, never a black screen.
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LipaWordmark(size: 44),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
