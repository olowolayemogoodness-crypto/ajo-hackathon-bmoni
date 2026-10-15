import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confetti.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/logic/circle_rules_logic.dart';
import '../../../data/models/circle_rules.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';
import 'circle_rules_view.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  static const _amounts = [1000, 2000, 5000, 10000];
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _customAmount = TextEditingController();

  int _amountNaira = 5000;
  int _members = 6;
  Frequency _freq = Frequency.weekly;
  DateTime? _start;
  DateTime? _end;
  bool _endEdited = false;
  PayoutOrderMode _mode = PayoutOrderMode.randomised;
  List<int> _manualOrder = List<int>.generate(6, (i) => i + 1);
  int _seed = Random().nextInt(1 << 30);
  int _deadlineDay = DateTime.friday;
  int _grace = 2;
  MissedPaymentPolicy _policy = MissedPaymentPolicy.reminderThenReview;
  bool _approval = false;

  bool _submitted = false;
  Map<String, String> _errors = {};
  DraftCircle? _created;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _start = DateTime(today.year, today.month, today.day + 1);
    _autoEnd();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _customAmount.dispose();
    super.dispose();
  }

  int? get _amountKobo {
    final raw = _customAmount.text.trim().replaceAll(',', '');
    if (raw.isNotEmpty) {
      final v = int.tryParse(raw);
      return v == null ? null : Money.toKobo(v);
    }
    return Money.toKobo(_amountNaira);
  }

  CircleRulesDraft _draft() => CircleRulesDraft(
    name: _name.text,
    description: _description.text,
    amountKobo: _amountKobo,
    memberCount: _members,
    frequency: _freq,
    startDate: _start,
    endDate: _end,
    payoutMode: _mode,
    payoutOrder: _manualOrder,
    randomSeed: _seed,
    deadlineDay: _deadlineDay,
    graceDays: _grace,
    missedPolicy: _policy,
    approvalRequired: _approval,
  );

  /// Suggests an end date (the last contribution deadline) until the
  /// organiser picks their own.
  void _autoEnd() {
    final start = _start;
    if (_endEdited || start == null) return;
    if (_members < 2) return;
    final dates = CircleRulesLogic.schedule(
      start: start,
      frequency: _freq,
      deadlineDay: _deadlineDay,
      cycles: _members,
    );
    _end = dates.last;
  }

  void _touch(VoidCallback change) {
    setState(() {
      change();
      _autoEnd();
      if (_submitted) _errors = CircleRulesLogic.validate(_draft());
    });
  }

  Future<void> _pickStart() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? first,
      firstDate: first,
      lastDate: DateTime(first.year + 3, first.month, first.day),
    );
    if (picked != null) _touch(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final start = _start ?? DateTime.now();
    final first = DateTime(start.year, start.month, start.day + 1);
    final initial = (_end != null && _end!.isAfter(start)) ? _end! : first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(first.year + 5, first.month, first.day),
    );
    if (picked != null) {
      _touch(() {
        _end = picked;
        _endEdited = true;
      });
    }
  }

  void _setMembers(int n) {
    _touch(() {
      _members = n;
      _manualOrder = List<int>.generate(n, (i) => i + 1);
    });
  }

  void _setFrequency(Frequency f) {
    _touch(() {
      _freq = f;
      _deadlineDay = f == Frequency.monthly ? 25 : DateTime.friday;
    });
  }

  void _create() {
    setState(() {
      _submitted = true;
      _errors = CircleRulesLogic.validate(_draft());
    });
    if (_errors.isNotEmpty) return;
    final rules = CircleRulesLogic.build(_draft());
    final c = AjoStore.instance.createCircleWithRules(rules);
    setState(() => _created = c);
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

  // ------------------------------------------------------------------ form

  Widget _label(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);

  Widget _error(String key) {
    final msg = _errors[key];
    if (msg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_rounded,
            size: 16,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              msg,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warningDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    final text = Theme.of(context).textTheme;
    final amount = _amountKobo;
    final pot = (amount ?? 0) * _members;
    final previewDates = _start == null
        ? <DateTime>[]
        : CircleRulesLogic.schedule(
            start: _start!,
            frequency: _freq,
            deadlineDay: _deadlineDay,
            cycles: max(_members, 1),
          );
    final order = _mode == PayoutOrderMode.randomised
        ? CircleRulesLogic.randomisedOrder(_members, _seed)
        : _manualOrder;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (_submitted && _errors.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _errors.length == 1
                  ? 'One thing needs fixing below.'
                  : '${_errors.length} things need fixing below.',
              style: text.bodyMedium?.copyWith(
                color: AppColors.warningDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        _label('Name your circle'),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          onChanged: (_) => _touch(() {}),
          decoration: const InputDecoration(
            hintText: 'e.g. Hostel Block C Ajo',
            counterText: '',
          ),
        ),
        _error('name'),
        const SizedBox(height: 16),
        _label('Description (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          maxLines: 3,
          maxLength: 280,
          onChanged: (_) => _touch(() {}),
          decoration: const InputDecoration(
            hintText: 'What is this circle saving for?',
          ),
        ),
        _error('description'),
        const SizedBox(height: 20),
        _label('Each person pays'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _amounts)
              ChoiceChip(
                label: Text(Money.fmt(Money.toKobo(a))),
                selected: _customAmount.text.trim().isEmpty && _amountNaira == a,
                onSelected: (_) => _touch(() {
                  _customAmount.clear();
                  _amountNaira = a;
                }),
                selectedColor: AppColors.mintLight,
                labelStyle: context.type.moneyBody.copyWith(
                  color: _customAmount.text.trim().isEmpty && _amountNaira == a
                      ? AppColors.primaryDark
                      : AppColors.ink,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _customAmount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9,]'))],
          onChanged: (_) => _touch(() {}),
          decoration: const InputDecoration(
            prefixText: '₦ ',
            hintText: 'Or enter another amount',
          ),
        ),
        _error('amount'),
        const SizedBox(height: 20),
        _label('How many members?'),
        const SizedBox(height: 8),
        _Stepper(
          value: _members,
          min: 2,
          max: CircleRulesLogic.maxMembers,
          suffix: _members == 1 ? 'member' : 'members',
          onChanged: _setMembers,
        ),
        _error('members'),
        const SizedBox(height: 20),
        _label('How often?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in Frequency.values)
              ChoiceChip(
                label: Text(f.label),
                selected: _freq == f,
                onSelected: (_) => _setFrequency(f),
                selectedColor: AppColors.mintLight,
                labelStyle: text.labelLarge?.copyWith(
                  color: _freq == f ? AppColors.primaryDark : AppColors.ink,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _label('Contribution deadline'),
        const SizedBox(height: 8),
        if (_freq == Frequency.monthly)
          _Stepper(
            value: _deadlineDay,
            min: 1,
            max: 28,
            prefix: 'Day',
            suffix: 'of each month',
            onChanged: (v) => _touch(() => _deadlineDay = v),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                ChoiceChip(
                  label: Text(_dayNames[d - 1]),
                  selected: _deadlineDay == d,
                  onSelected: (_) => _touch(() => _deadlineDay = d),
                  selectedColor: AppColors.mintLight,
                  labelStyle: text.labelLarge?.copyWith(
                    color: _deadlineDay == d
                        ? AppColors.primaryDark
                        : AppColors.ink,
                  ),
                ),
            ],
          ),
        _error('deadline'),
        const SizedBox(height: 20),
        _label('Grace period'),
        const SizedBox(height: 4),
        Text(
          'Days after a deadline before a payment counts as missed.',
          style: text.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        _Stepper(
          value: _grace,
          min: 0,
          max: CircleRulesLogic.maxGraceDays,
          suffix: _grace == 1 ? 'day' : 'days',
          onChanged: (v) => _touch(() => _grace = v),
        ),
        _error('grace'),
        const SizedBox(height: 20),
        _label('Dates'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DateButton(
                label: 'Start date',
                value: _start == null ? null : Dates.short(_start!),
                onTap: _pickStart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateButton(
                label: 'Expected end',
                value: _end == null ? null : Dates.short(_end!),
                onTap: _pickEnd,
              ),
            ),
          ],
        ),
        _error('start'),
        _error('end'),
        const SizedBox(height: 20),
        _label('Payout order'),
        const SizedBox(height: 8),
        SegmentedButton<PayoutOrderMode>(
          segments: const [
            ButtonSegment(
              value: PayoutOrderMode.randomised,
              label: Text('Randomised'),
            ),
            ButtonSegment(
              value: PayoutOrderMode.manual,
              label: Text('Manual'),
            ),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (v) => _touch(() => _mode = v.first),
        ),
        const SizedBox(height: 6),
        Text(
          '${_mode.description} It is shown to every member before they join.${_mode == PayoutOrderMode.manual ? ' Long-press a row and drag to reorder.' : ''}',
          style: text.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        if (_mode == PayoutOrderMode.randomised)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _touch(() => _seed = Random().nextInt(1 << 30)),
              icon: const Icon(Icons.casino_rounded, size: 18),
              label: const Text('Redraw order'),
            ),
          ),
        _orderList(order, previewDates),
        _error('order'),
        const SizedBox(height: 20),
        _label('If a payment is missed'),
        const SizedBox(height: 8),
        for (final p in MissedPaymentPolicy.values)
          _PolicyTile(
            policy: p,
            selected: _policy == p,
            onTap: () => _touch(() => _policy = p),
          ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _approval,
          onChanged: (v) => _touch(() => _approval = v),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: Text('Approve new members', style: text.titleSmall),
          subtitle: Text(
            _approval
                ? 'People who join will wait for your approval.'
                : 'Anyone with the invite code can join.',
            style: text.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 16),
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
                  Text('Circle preview', style: text.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                amount == null || amount <= 0
                    ? 'Enter an amount to see the pot.'
                    : 'Each round the pot is ${Money.fmt(pot)}. Over $_members rounds, everyone receives it once.',
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Create circle',
          icon: Icons.rocket_launch_rounded,
          onPressed: _create,
        ),
      ],
    );
  }

  String _slotName(int slot) => slot == 1 ? 'You (organiser)' : 'Member $slot';

  Widget _orderList(List<int> order, List<DateTime> dates) {
    final text = Theme.of(context).textTheme;
    Widget row(int i) {
      final when = i < dates.length ? ' · ${Dates.short(dates[i])}' : '';
      return Container(
        key: ValueKey('slot-${order[i]}'),
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${i + 1}',
                style: text.titleSmall?.copyWith(color: AppColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                '${_slotName(order[i])}$when',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_mode == PayoutOrderMode.manual)
              const Icon(Icons.drag_handle_rounded, color: AppColors.muted),
          ],
        ),
      );
    }

    if (_mode == PayoutOrderMode.manual) {
      return ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        onReorder: (oldIndex, newIndex) => _touch(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _manualOrder.removeAt(oldIndex);
          _manualOrder.insert(newIndex, item);
        }),
        children: [for (var i = 0; i < order.length; i++) row(i)],
      );
    }
    return Column(children: [for (var i = 0; i < order.length; i++) row(i)]);
  }

  // --------------------------------------------------------------- success

  Widget _success(DraftCircle c) {
    final text = Theme.of(context).textTheme;
    final rules = c.rules!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Center(
          child: Container(
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
        ),
        const SizedBox(height: 12),
        Text(
          c.name,
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          '${Money.fmt(c.amountKobo)} ${c.frequency.label.toLowerCase()} · ${c.size} people',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            children: [
              Text(
                'Invite code',
                style: text.labelMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                c.code,
                style: context.type.code.copyWith(color: AppColors.primaryDark),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: c.code));
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
          'Circles are invite-only. Members review these rules and must accept them before they join. (Prototype: nobody can actually join this demo circle.)',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        CircleRulesView(rules: rules, slotLabel: _slotName),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Done', onPressed: () => context.pop()),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton.outlined(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: 12),
        Text(
          '${prefix == null ? '' : '$prefix '}$value${suffix == null ? '' : ' $suffix'}',
          style: text.titleMedium?.copyWith(color: AppColors.primaryDark),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(58),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border, width: 1.4),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.muted)),
          Text(
            value ?? 'Pick a date',
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: value == null ? AppColors.muted : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({
    required this.policy,
    required this.selected,
    required this.onTap,
  });

  final MissedPaymentPolicy policy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.muted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    policy.label,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    policy.description,
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
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
