import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';

class JoinCircleScreen extends StatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  State<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends State<JoinCircleScreen> {
  final _code = TextEditingController();
  DraftCircle? _found;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _lookup() {
    FocusScope.of(context).unfocus();
    final c = AjoStore.instance.lookupInvite(_code.text);
    setState(() {
      _found = c;
      _error = c == null
          ? 'We couldn\'t find that code. Double-check it, or try FUN-2026 to see how it works.'
          : null;
    });
  }

  void _join() {
    final c = _found;
    if (c == null) return;
    AjoStore.instance.joinCircle(c);
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        content: Text('🎉 You joined ${c.name}!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Join a circle', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('🔑', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text('Got an invite code?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Circles are invite-only. Ask the organizer for their code.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'AJO-XXXX',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(label: 'Look up circle', onPressed: _lookup),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.warning, fontWeight: FontWeight.w600)),
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
                    Text(_found!.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                        '${Money.fmt(_found!.amountKobo)} ${_found!.frequency.label.toLowerCase()} · ${_found!.memberCount} of ${_found!.size} members'),
                    const SizedBox(height: 4),
                    Text('Organizer: ${_found!.organizer}',
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 14),
                    PrimaryButton(label: 'Join circle', icon: Icons.handshake_rounded, onPressed: _join),
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
