import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confetti.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/circle_repository.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _name = TextEditingController();
  int _amountNaira = 5000;
  double _size = 6;
  DemoCircleCreated? _created;
  DemoRules? _rules;
  String? _error;
  bool _loading = false;
  bool _loadingRules = true;
  bool _acceptedRules = false;

  static const _amounts = [1000, 2000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final rules = await CircleRepository.instance.getDemoRules();
      if (mounted) setState(() => _rules = rules);
    } on CircleApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the demo rules.');
    } finally {
      if (mounted) setState(() => _loadingRules = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim().isEmpty
        ? 'My Ajo Circle'
        : _name.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final circle = await CircleRepository.instance.createCircle(
        name: name,
        maxMembers: _size.round(),
        contributionKobo: Money.toKobo(_amountNaira),
        acceptedRulesVersion: _rules!.version,
      );
      if (mounted) setState(() => _created = circle);
    } on CircleApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the circle. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_created == null ? 'Create a circle' : 'Circle created!'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(child: _created == null ? _form() : _success(_created!)),
          if (_created != null) const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }

  Widget _form() {
    final capacity = _size.round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Name your circle',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Hostel Block C Ajo',
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Each person pays',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _amounts)
              ChoiceChip(
                label: Text(Money.fmt(Money.toKobo(a))),
                selected: _amountNaira == a,
                onSelected: (_) => setState(() => _amountNaira = a),
                selectedColor: AppColors.mintLight,
                labelStyle: context.type.moneyBody.copyWith(
                  color: _amountNaira == a
                      ? AppColors.primaryDark
                      : AppColors.ink,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'How many people?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '$capacity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.primaryDark),
            ),
          ],
        ),
        Slider(
          value: _size,
          min: 2,
          max: 12,
          divisions: 10,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _size = v),
        ),
        const SizedBox(height: 10),
        SectionCard(
          color: AppColors.mintLight,
          borderColor: const Color(0xFFBFE8D1),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Weekly contributions · due 09:00 Africa/Lagos time · 24-hour grace',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionCard(
          color: AppColors.purpleLight,
          borderColor: const Color(0xFFD5CBFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.visibility_rounded,
                    size: 19,
                    color: AppColors.purple,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Circle preview',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Each active member contributes ${Money.fmt(Money.toKobo(_amountNaira))} for one demo period. The payout amount is based on active members when you activate the circle.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_rules != null) ...[
          Text(
            'Local demo rules · ${_rules!.version}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  _rules!.text,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptedRules,
            onChanged: (value) => setState(() => _acceptedRules = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I accept these local demo rules.'),
            subtitle: const Text('Synthetic data only. No real money.'),
          ),
        ] else if (_loadingRules) ...[
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Create circle',
          icon: Icons.rocket_launch_rounded,
          loading: _loading,
          onPressed: _loading || _loadingRules || !_acceptedRules ? null : _create,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.warningDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _success(DemoCircleCreated c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mintLight,
            ),
            child: const Icon(
              Icons.group_add_rounded,
              size: 40,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${Money.fmt(c.contributionKobo)} weekly · up to ${c.maxMembers} members',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              children: [
                Text(
                  'Invite code',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  c.invitationCode,
                  style: context.type.code.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.invitationCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Invite code copied'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy code'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Local synthetic demo only. No real money moves. The invitation expires in 7 days.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Manage circle setup',
            icon: Icons.tune_rounded,
            onPressed: () => context.push('/circles/demo/${c.id}'),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: () => context.pop(), child: const Text('Done')),
        ],
      ),
    );
  }
}
