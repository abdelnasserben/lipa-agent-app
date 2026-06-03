import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import 'security_controller.dart';

/// Change PIN (spec §3.6): current PIN + new PIN (4–8 digits) + confirm.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _current = TextEditingController();
  final _newPin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _newPin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _current.text.length >= 4 &&
      _newPin.text.length >= 4 &&
      _newPin.text == _confirm.text;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePinControllerProvider);

    ref.listen(changePinControllerProvider, (prev, next) {
      if (next.done) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PIN mis à jour',
              style: AppText.ui(color: Colors.white)),
          backgroundColor: AppColors.brandDeep,
        ));
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Changer mon PIN',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const FieldLabel('PIN actuel'),
                  const SizedBox(height: 8),
                  PinDigitsInput(
                      controller: _current, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 18),
                  const FieldLabel('Nouveau PIN'),
                  const SizedBox(height: 8),
                  PinDigitsInput(
                      controller: _newPin, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 18),
                  const FieldLabel('Confirmer le nouveau PIN'),
                  const SizedBox(height: 8),
                  PinDigitsInput(
                      controller: _confirm, onChanged: (_) => setState(() {})),
                  if (state.error != null) ...[
                    const SizedBox(height: 14),
                    Text(state.error!,
                        style: AppText.ui(size: 13, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  LipaButton(
                    label: 'Enregistrer',
                    size: BtnSize.lg,
                    full: true,
                    loading: state.loading,
                    onPressed: _valid
                        ? () => ref
                            .read(changePinControllerProvider.notifier)
                            .submit(
                                currentPin: _current.text,
                                newPin: _newPin.text)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
