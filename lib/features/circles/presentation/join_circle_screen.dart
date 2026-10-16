import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/circle_repository.dart';

class JoinCircleScreen extends StatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  State<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends State<JoinCircleScreen> {
  final _code = TextEditingController();
  DemoInvitationPreview? _found;
  String? _error;
  bool _acceptedRules = false;
  bool _lookingUp = false;
  bool _joining = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _found = null;
      _acceptedRules = false;
      _error = null;
      _lookingUp = true;
    });
    try {
      final invitation = await CircleRepository.instance.inspectInvitation(
        _code.text.trim(),
      );
      if (mounted) setState(() => _found = invitation);
    } on CircleApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not inspect this invitation. Try again.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _join() async {
    final c = _found;
    if (c == null || !_acceptedRules || _joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final circleId = await CircleRepository.instance.acceptInvitation(
        invitationCode: _code.text.trim(),
        acceptedRulesVersion: c.rulesVersion,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/circles/demo/${Uri.encodeComponent(circleId)}');
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryDark,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('You joined ${c.name}!')),
            ],
          ),
        ),
      );
    } on CircleApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
      return;
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not join this circle. Try again.');
      return;
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a circle'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.key_rounded,
                size: 48,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Got an invite code?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Circles are invite-only. Ask the organizer for their code.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
              style: context.type.codeInput,
              decoration: const InputDecoration(hintText: 'AJO-XXXX'),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Look up circle',
              loading: _lookingUp,
              onPressed: _lookingUp ? null : _lookup,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_rounded,
                      color: AppColors.warningDark,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.warningDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_found != null) ...[
              const SizedBox(height: 18),
              SectionCard(
                color: AppColors.mintLight,
                borderColor: const Color(0xFFBFE8D1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _found!.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Money.fmt(_found!.contributionKobo)} weekly · ${_found!.activeMemberCount} of ${_found!.maxMembers} members',
                      style: context.type.moneyBody,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due 09:00 Africa/Lagos time · 24-hour grace',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Demo rules ${_found!.rulesVersion}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _found!.rulesText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _acceptedRules,
                      onChanged: (value) => setState(
                        () => _acceptedRules = value ?? false,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('I accept these local demo rules.'),
                      subtitle: const Text('Synthetic data only. No real money.'),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Join circle',
                      icon: Icons.handshake_rounded,
                      loading: _joining,
                      onPressed: _acceptedRules && !_joining ? _join : null,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
