import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confetti.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _name = TextEditingController();
  int _amountNaira = 5000;
  double _size = 6;
  Frequency _freq = Frequency.weekly;
  DraftCircle? _created;

  static const _amounts = [1000, 2000, 5000, 10000];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim().isEmpty ? 'My Ajo Circle' : _name.text.trim();
    final c = AjoStore.instance.createCircle(
      name: name,
      amountKobo: Money.toKobo(_amountNaira),
      size: _size.round(),
      frequency: _freq,
    );
    setState(() => _created = c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(_created == null ? 'Create a circle' : 'Circle created!',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _created == null ? _form() : _success(_created!),
          ),
          if (_created != null) const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }

  Widget _form() {
    final rounds = _size.round();
    final pot = Money.toKobo(_amountNaira) * rounds;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text('Name your circle',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Hostel Block C Ajo',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text('Each person pays',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _amountNaira == a ? AppColors.primaryDark : AppColors.ink,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('How many people?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('$rounds',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
          ],
        ),
        Slider(
          value: _size,
          min: 3,
          max: 12,
          divisions: 9,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _size = v),
        ),
        const SizedBox(height: 10),
        const Text('How often?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in Frequency.values)
              ChoiceChip(
                label: Text(f.label),
                selected: _freq == f,
                onSelected: (_) => setState(() => _freq = f),
                selectedColor: AppColors.mintLight,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _freq == f ? AppColors.primaryDark : AppColors.ink,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        SectionCard(
          color: AppColors.purpleLight,
          borderColor: const Color(0xFFD5CBFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preview ✨', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Each round, the pot is ${Money.fmt(pot)}. Over $rounds rounds, everyone receives it once — about ${(rounds * _freq.days / 7).round()} weeks in total.',
                style: const TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Create circle', icon: Icons.rocket_launch_rounded, onPressed: _create),
      ],
    );
  }

  Widget _success(DraftCircle c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const Spacer(),
          const Text('🌱', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(c.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              '${Money.fmt(c.amountKobo)} ${c.frequency.label.toLowerCase()} · ${c.size} people',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              children: [
                const Text('Invite code',
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(c.code,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.primaryDark)),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Invite code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy code'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Circles are invite-only. Share this code with people you trust. (Prototype: nobody can actually join this demo circle.)',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
          ),
          const Spacer(),
          PrimaryButton(label: 'Done', onPressed: () => context.pop()),
        ],
      ),
    );
  }
}
