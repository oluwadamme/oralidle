import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/captcha/hcaptcha_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../data/email_suggestion.dart';
import '../providers/auth_provider.dart';

enum _Step { details, code }

class LinkAccountSheet extends ConsumerStatefulWidget {
  const LinkAccountSheet({super.key, this.requestCaptcha});

  final Future<String?> Function(BuildContext context)? requestCaptcha;

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.raised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (_) => const LinkAccountSheet(),
    );
  }

  @override
  ConsumerState<LinkAccountSheet> createState() => _LinkAccountSheetState();
}

class _LinkAccountSheetState extends ConsumerState<LinkAccountSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Step _step = _Step.details;
  String? _suggestion;
  LinkFlow? _flow;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }


  Future<void> _sendCode() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final captchaToken = await _requestCaptcha();

      if (captchaToken == null || !mounted) return;

      final flow = await ref
          .read(authProvider.notifier)
          .sendLinkCode(
            name: _nameController.text.trim(),
            email: _normalise(_emailController.text),
            captchaToken: captchaToken,
          );
      if (!mounted) return;
      setState(() {
        _flow = flow;
        _step = _Step.code;
      });
    } catch (e, stackTrace) {
      log('LinkAccountSheet: send code failed', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _requestCaptcha() =>
      (widget.requestCaptcha ?? HCaptchaService.verify)(context);

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .verifyLinkCode(
            email: _normalise(_emailController.text),
            token: code,
            flow: _flow!,
          );

      TextInput.finishAutofillContext();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      log('LinkAccountSheet: verify failed', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readable(Object e) {
    final raw = e.toString().replaceFirst('AuthApiException: ', '');
    if (raw.toLowerCase().contains('expired') ||
        raw.toLowerCase().contains('invalid')) {
      return 'That code is wrong or has expired. Request a new one.';
    }
    return raw.isEmpty ? 'Something went wrong. Try again.' : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Space.xl,
        right: Space.xl,
        top: Space.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + Space.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.refreshCw,
                  size: IconSize.md,
                  color: AppColors.accent,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    _step == _Step.details
                        ? 'Sync across devices'
                        : 'Check your email',
                    style: context.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              _step == _Step.details
                  ? 'Add your email and your history follows you to any browser '
                        'or phone. No password — we send a 6-digit code.'
                  : 'We sent a 6-digit code to ${_normalise(_emailController.text)}.',
              style: context.body.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: Space.xl),
            if (_step == _Step.details) ..._detailsFields() else _codeField(),
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.circleAlert,
                    size: IconSize.sm,
                    color: AppColors.critical,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: context.caption.copyWith(
                        color: AppColors.critical,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.xl),
            AppButton.primary(
              label: _step == _Step.details ? 'Send code' : 'Verify',
              expand: true,
              busy: _busy,
              size: AppButtonSize.large,
              onPressed: _busy
                  ? null
                  : (_step == _Step.details ? _sendCode : _verify),
            ),
            if (_step == _Step.code) ...[
              const SizedBox(height: Space.sm),
              AppButton.quiet(
                label: 'Use a different email',
                expand: true,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _step = _Step.details;
                        _error = null;
                        _codeController.clear();
                      }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _detailsFields() => [
    AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'What should we call you?',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
              onChanged: (_) => _refreshSuggestion(),
              validator: (v) {
                final value = _normalise(v ?? '');
                if (value.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return 'That does not look like an email address';
                }
                return null;
              },
              // onFieldSubmitted: (_) => _sendCode(),
            ),
            if (_suggestion != null) _didYouMean(_suggestion!),
          ],
        ),
      ),
    ),
  ];

  /// A tappable correction for a mistyped domain.
  ///
  Widget _didYouMean(String corrected) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: AppButton.quiet(
        label: 'Did you mean $corrected?',
        icon: LucideIcons.wandSparkles,
        onPressed: () {
          _emailController.text = corrected;
          _emailController.selection = TextSelection.collapsed(
            offset: corrected.length,
          );
          setState(() => _suggestion = null);
        },
      ),
    ),
  );

  void _refreshSuggestion() {
    final next = EmailSuggestion.forAddress(_normalise(_emailController.text));
    if (next != _suggestion) setState(() => _suggestion = next);
  }

  static String _normalise(String raw) => raw.trim().toLowerCase();

  Widget _codeField() => TextField(
    controller: _codeController,
    keyboardType: TextInputType.number,
    autofillHints: const [AutofillHints.oneTimeCode],
    maxLength: 6,
    textAlign: TextAlign.center,
    style: context.display,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: const InputDecoration(hintText: '000000', counterText: ''),
    onSubmitted: (_) => _verify(),
  );
}
