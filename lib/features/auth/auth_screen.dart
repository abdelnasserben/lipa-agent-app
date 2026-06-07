import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/code_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/lipa_brand.dart';
import 'login_controller.dart';
import 'session_controller.dart';

/// The full agent auth surface (login → MFA → PIN setup → expired → locked).
/// Reuses the Lipa dark-hero auth layout, adapted to agent copy.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  @override
  void initState() {
    super.initState();
    // If we arrived here due to an expired session, show that variant once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionControllerProvider);
      if (session.expiredNotice) {
        ref
            .read(loginControllerProvider.notifier)
            .goToStep(AuthStep.sessionExpired);
        ref.read(sessionControllerProvider.notifier).clearExpiredNotice();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final step = state.step;

    final (heroTitle, heroSubtitle) = switch (step) {
      AuthStep.login => (
          'Espace agent',
          'Connectez-vous pour gérer vos opérations cash et l’enrôlement client.'
        ),
      AuthStep.mfa => (
          'Vérifiez votre identité',
          'Saisissez le code à 6 chiffres de votre application d’authentification.'
        ),
      AuthStep.pinSetup => (
          'Définir votre PIN',
          'Choisissez le PIN qui protégera votre compte agent et vos opérations.'
        ),
      AuthStep.forgotPin => (
          'PIN oublié',
          'Réinitialisez votre PIN avec le code de votre application d’authentification.'
        ),
      AuthStep.sessionExpired => (
          'Session expirée',
          'Vous avez été déconnecté afin de protéger votre compte agent.'
        ),
      AuthStep.locked => (
          'PIN bloqué',
          'Trop de tentatives incorrectes. Réessayez dans 15 minutes.'
        ),
    };

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Dark hero header.
          Stack(
            children: [
              Container(
                height: 320 + topInset,
                width: double.infinity,
                color: AppColors.nearBlack,
              ),
              const GridBackground(),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, topInset, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const LipaWordmark(dark: true, size: 44),
                      const SizedBox(height: 36),
                      Text(heroTitle,
                          style: AppText.ui(
                              size: 32,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.8,
                              height: 1.05)),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(heroSubtitle,
                            style: AppText.ui(
                                size: 14.5,
                                color: Colors.white.withValues(alpha: 0.62),
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                left: 0,
                right: 0,
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: switch (step) {
                AuthStep.login => _LoginForm(state: state),
                AuthStep.mfa => _MfaForm(state: state),
                AuthStep.pinSetup => _PinSetupForm(state: state),
                AuthStep.forgotPin => _ForgotPinForm(state: state),
                AuthStep.sessionExpired => const _SessionExpired(),
                AuthStep.locked => const _PinLocked(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({required this.state});
  final LoginState state;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _reveal = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _valid =>
      PhoneValidator.isComplete(_phone.text) && PinValidator.isValid(_pin.text);

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.pinResetDone) ...[
          const InfoBanner(
            icon: Icons.check_circle_outline,
            kind: PillKind.success,
            text: 'PIN réinitialisé. Connectez-vous avec votre nouveau PIN.',
          ),
          const SizedBox(height: 18),
        ],
        const FieldLabel('Numéro de téléphone'),
        const SizedBox(height: 8),
        PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        FieldLabel(
          'PIN',
          trailing: Text('4 à 8 chiffres',
              style: AppText.ui(size: 12, color: AppColors.inkLow)),
        ),
        const SizedBox(height: 8),
        _BoxedInput(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pin,
                  obscureText: !_reveal,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  style: AppText.mono(size: 18, letterSpacing: 4),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Saisissez votre PIN',
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _reveal = !_reveal),
                icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility,
                    size: 20, color: AppColors.inkMid),
              ),
            ],
          ),
        ),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 18),
        LipaButton(
          label: 'Se connecter',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _valid
              ? () => ref
                  .read(loginControllerProvider.notifier)
                  .login(phoneNumber: _phone.text, pin: _pin.text)
              : null,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => ref
                .read(loginControllerProvider.notifier)
                .goToStep(AuthStep.forgotPin),
            child: Text('PIN oublié ?',
                style: AppText.ui(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: AppColors.brand)),
          ),
        ),
        const SizedBox(height: 16),
        LipaCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 20, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppText.ui(
                        size: 12.5, color: AppColors.inkMid, height: 1.55),
                    children: [
                      TextSpan(
                          text: 'Sécurité renforcée par Lipa. ',
                          style: AppText.ui(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: AppColors.inkHi)),
                      const TextSpan(
                          text: 'Votre PIN reste confidentiel et protégé.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// MFA: a single hidden field backing 6 display cells.
class _MfaForm extends ConsumerStatefulWidget {
  const _MfaForm({required this.state});
  final LoginState state;
  @override
  ConsumerState<_MfaForm> createState() => _MfaFormState();
}

class _MfaFormState extends ConsumerState<_MfaForm> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CodeField(onChanged: (v) => setState(() => _code = v)),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 18),
        LipaButton(
          label: 'Vérifier et continuer',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _code.length == 6
              ? () =>
                  ref.read(loginControllerProvider.notifier).verifyMfa(_code)
              : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.login),
          child: Text('← Retour à la connexion',
              style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
        ),
      ],
    );
  }
}

class _PinSetupForm extends ConsumerStatefulWidget {
  const _PinSetupForm({required this.state});
  final LoginState state;
  @override
  ConsumerState<_PinSetupForm> createState() => _PinSetupFormState();
}

class _PinSetupFormState extends ConsumerState<_PinSetupForm> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      PinValidator.isValid(_pin.text) && _pin.text == _confirm.text;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.lock_outline,
          text: 'Configuration unique. Choisissez un PIN de 4 à 8 chiffres.',
        ),
        const SizedBox(height: 18),
        const FieldLabel('Nouveau PIN'),
        const SizedBox(height: 8),
        PinDigitsInput(controller: _pin, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        const FieldLabel('Confirmer le PIN'),
        const SizedBox(height: 8),
        PinDigitsInput(controller: _confirm, onChanged: (_) => setState(() {})),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 22),
        LipaButton(
          label: 'Enregistrer le PIN',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _valid
              ? () =>
                  ref.read(loginControllerProvider.notifier).setupPin(_pin.text)
              : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.login),
          child: Text('← Retour à la connexion',
              style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
        ),
      ],
    );
  }
}

/// Forgotten-PIN reset (spec §3.6): phone + current TOTP code + new PIN.
class _ForgotPinForm extends ConsumerStatefulWidget {
  const _ForgotPinForm({required this.state});
  final LoginState state;
  @override
  ConsumerState<_ForgotPinForm> createState() => _ForgotPinFormState();
}

class _ForgotPinFormState extends ConsumerState<_ForgotPinForm> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.state.phoneNumber);
  final _newPin = TextEditingController();
  final _confirm = TextEditingController();
  String _code = '';

  @override
  void dispose() {
    _phone.dispose();
    _newPin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      PhoneValidator.isComplete(_phone.text) &&
      _code.length == 6 &&
      PinValidator.isValid(_newPin.text) &&
      _newPin.text == _confirm.text;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.shield_outlined,
          text:
              'Réinitialisation possible uniquement si le TOTP est activé. Sinon, contactez le back-office Lipa.',
        ),
        const SizedBox(height: 18),
        const FieldLabel('Numéro de téléphone'),
        const SizedBox(height: 8),
        PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        const FieldLabel('Nouveau PIN'),
        const SizedBox(height: 8),
        PinDigitsInput(controller: _newPin, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        const FieldLabel('Confirmer le PIN'),
        const SizedBox(height: 8),
        PinDigitsInput(controller: _confirm, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        const FieldLabel('Code d’authentification (TOTP)'),
        const SizedBox(height: 8),
        CodeField(onChanged: (v) => setState(() => _code = v)),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 22),
        LipaButton(
          label: 'Réinitialiser le PIN',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _valid
              ? () => ref.read(loginControllerProvider.notifier).resetPin(
                    phoneNumber: _phone.text,
                    totpCode: _code,
                    newPin: _newPin.text,
                  )
              : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.login),
          child: Text('← Retour à la connexion',
              style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
        ),
      ],
    );
  }
}

class _SessionExpired extends ConsumerWidget {
  const _SessionExpired();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LipaCard(
          padding: const EdgeInsets.all(18),
          radius: AppRadius.lg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warnSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 20, color: AppColors.warn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vous avez été déconnecté',
                        style:
                            AppText.ui(size: 14.5, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'Reconnectez-vous pour continuer vos opérations agent Lipa.',
                        style: AppText.ui(
                            size: 13, color: AppColors.inkMid, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LipaButton(
          label: 'Se reconnecter',
          size: BtnSize.lg,
          full: true,
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.login),
        ),
      ],
    );
  }
}

class _PinLocked extends ConsumerWidget {
  const _PinLocked();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Icon(Icons.lock_outline,
                    size: 20, color: AppColors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saisie du PIN bloquée',
                        style:
                            AppText.ui(size: 14.5, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'PIN incorrect saisi 3 fois. Réessayez dans 15 minutes.',
                        style: AppText.ui(
                            size: 13, color: AppColors.inkMid, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LipaButton(
          label: 'Réinitialiser mon PIN',
          variant: BtnVariant.secondary,
          size: BtnSize.lg,
          full: true,
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.forgotPin),
        ),
      ],
    );
  }
}

class _BoxedInput extends StatelessWidget {
  const _BoxedInput({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderHi),
        ),
        child: child,
      );
}
