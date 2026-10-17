import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/circle_repository.dart';

class DemoCircleScreen extends StatefulWidget {
  const DemoCircleScreen({super.key, required this.circleId, this.repository});

  final String circleId;
  final CircleRepository? repository;

  @override
  State<DemoCircleScreen> createState() => _DemoCircleScreenState();
}

class _DemoCircleScreenState extends State<DemoCircleScreen> {
  late final _repository = widget.repository ?? CircleRepository.instance;
  final _questionController = TextEditingController();
  DemoCircleSetup? _setup;
  DemoCircleSummary? _summary;
  DemoAssistantAnswer? _assistantAnswer;
  String? _recipientMembershipId;
  DateTime? _firstDueDate;
  String? _error;
  bool _loading = false;
  int _requestSequence = 0;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _repository.getSummary(widget.circleId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _setup = null;
      });
    } on CircleApiException catch (error) {
      if (error.statusCode != 409) {
        if (mounted) setState(() => _error = error.message);
        return;
      }
      try {
        final setup = await _repository.getSetup(widget.circleId);
        if (!mounted) return;
        final nonOrganizer = setup.members.where((member) => member.role == 'member');
        setState(() {
          _setup = setup;
          _summary = null;
          if (nonOrganizer.length == 1) {
            _recipientMembershipId = nonOrganizer.first.membershipId;
          } else if (!nonOrganizer.any(
            (member) => member.membershipId == _recipientMembershipId,
          )) {
            _recipientMembershipId = null;
          }
        });
      } on CircleApiException catch (setupError) {
        if (mounted) setState(() => _error = setupError.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this demo circle.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseFirstDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Choose the first weekly due date',
    );
    if (selected != null && mounted) {
      setState(() => _firstDueDate = selected);
    }
  }

  Future<void> _activate() async {
    final recipient = _recipientMembershipId;
    final dueDate = _firstDueDate;
    if (recipient == null || dueDate == null) return;
    await _runAction(() async {
      await _repository.activateCircle(
        circleId: widget.circleId,
        payoutRecipientMembershipId: recipient,
        firstDueDate: dueDate,
      );
      await _refresh();
    });
  }

  Future<void> _recordContribution(DemoObligationSummary obligation) async {
    final controller = TextEditingController(
      text: '${obligation.remainingKobo ~/ 100}',
    );
    final amountNaira = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Simulate ${obligation.memberLabel}\'s contribution'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Amount in naira',
            prefixText: '₦ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) Navigator.pop(context, parsed);
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amountNaira == null || !mounted) return;

    await _runAction(() async {
      _requestSequence++;
      await _repository.recordSimulatedContribution(
        circleId: widget.circleId,
        membershipId: obligation.membershipId,
        amountKobo: Money.toKobo(amountNaira),
        idempotencyKey:
            'demo-${widget.circleId}-${obligation.membershipId}-$_requestSequence',
      );
      await _refresh();
    });
  }

  Future<void> _approvePayout() async {
    await _runAction(() async {
      await _repository.approvePayout(widget.circleId);
      await _refresh();
    });
  }

  Future<void> _settlePayout() async {
    await _runAction(() async {
      await _repository.settleSimulatedPayout(widget.circleId);
      await _refresh();
    });
  }

  Future<void> _askAssistant() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    await _runAction(() async {
      final answer = await _repository.askDemoAssistant(
        circleId: widget.circleId,
        question: question,
      );
      if (mounted) setState(() => _assistantAnswer = answer);
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on CircleApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'The action could not be completed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo circle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh circle',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading && _setup == null && _summary == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _demoNotice(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorNotice(_error!),
                  ],
                  if (_setup != null) ...[
                    const SizedBox(height: 16),
                    _setupView(_setup!),
                  ],
                  if (_summary != null) ...[
                    const SizedBox(height: 16),
                    _summaryView(_summary!),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _demoNotice() => SectionCard(
    color: AppColors.goldLight,
    borderColor: AppColors.gold.withValues(alpha: 0.35),
    child: const Row(
      children: [
        Icon(Icons.science_rounded, color: AppColors.gold),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'LOCAL SYNTHETIC DEMO · No real money moves',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _setupView(DemoCircleSetup setup) {
    final recipients = setup.members.where((member) => member.role == 'member');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(setup.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          '${Money.fmt(setup.contributionKobo)} weekly · ${setup.members.length} active members · max ${setup.maxMembers}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 14),
        Text('Active members', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final member in setup.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              member.role == 'organizer' ? Icons.shield_outlined : Icons.person_outline,
              color: AppColors.primaryDark,
            ),
            title: Text(member.label),
            subtitle: Text(member.role),
          ),
        const SizedBox(height: 16),
        if (setup.status == 'inviting' && setup.canManageCircle) ...[
          DropdownButtonFormField<String>(
            initialValue: _recipientMembershipId,
            decoration: const InputDecoration(labelText: 'First payout recipient'),
            items: [
              for (final member in recipients)
                DropdownMenuItem(
                  value: member.membershipId,
                  child: Text(member.label),
                ),
            ],
            onChanged: (value) => setState(() => _recipientMembershipId = value),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _chooseFirstDueDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              _firstDueDate == null
                  ? 'Choose first due date'
                  : 'First due: ${DateFormat.yMMMd().format(_firstDueDate!)} at 09:00',
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activation locks the selected one-period payout recipient. Members must join first.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Activate one-period circle',
                icon: Icons.play_arrow_rounded,
                loading: _loading,
                onPressed: recipients.isNotEmpty &&
                        _recipientMembershipId != null &&
                        _firstDueDate != null &&
                        !_loading
                    ? _activate
                    : null,
              ),
            ],
          ),
        ] else if (setup.status == 'inviting') ...[
          SectionCard(
            color: AppColors.purpleLight,
            borderColor: const Color(0xFFD5CBFF),
            child: Text(
              'You joined. The organizer will choose the first payout recipient and activate this circle.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryView(DemoCircleSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(summary.name, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(
        'One weekly period · ${summary.status.toUpperCase()}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.muted,
        ),
      ),
      const SizedBox(height: 14),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contribution ledger', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Collected ${Money.fmt(summary.collectedKobo)}'),
            Text('Shortfall ${Money.fmt(summary.shortfallKobo)}'),
            Text('Payout ${summary.payoutStatus.replaceAll('_', ' ')}'),
            if (summary.recipientLabel != null)
              Text('Recipient ${summary.recipientLabel}'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next step', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(summary.nextAction, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text('Member obligations', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      for (final obligation in summary.obligations)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(obligation.memberLabel, style: context.type.moneyBody),
                      const SizedBox(height: 3),
                      Text(
                        '${Money.fmt(obligation.paidKobo)} paid · ${Money.fmt(obligation.remainingKobo)} remaining',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary.canOperateDemo && obligation.remainingKobo > 0)
                  IconButton.filledTonal(
                    tooltip: 'Record simulated contribution',
                    onPressed: _loading ? null : () => _recordContribution(obligation),
                    icon: const Icon(Icons.add_card_rounded),
                  ),
              ],
            ),
          ),
        ),
      SectionCard(
        color: AppColors.mintLight,
        borderColor: const Color(0xFFBFE8D1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backend explanation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(summary.explanation),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask Ajo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Answers use this circle’s authorized backend records.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _questionController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _askAssistant(),
              decoration: const InputDecoration(
                hintText: 'Why is the payout not eligible?',
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Ask about this circle',
              icon: Icons.question_answer_rounded,
              loading: _loading,
              onPressed: _loading ? null : _askAssistant,
            ),
            if (_assistantAnswer != null) ...[
              const SizedBox(height: 12),
              Text(
                _assistantAnswer!.answer,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Based on current backend records · simulated demo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
      if (summary.currentRole == 'organizer' &&
          summary.payoutEligible &&
          summary.payoutStatus == 'awaiting_approval') ...[
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Approve eligible payout',
          icon: Icons.verified_rounded,
          loading: _loading,
          onPressed: _loading ? null : _approvePayout,
        ),
      ],
      if (summary.canOperateDemo && summary.payoutStatus == 'processing') ...[
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Record simulated payout settlement',
          icon: Icons.account_balance_rounded,
          color: AppColors.purple,
          loading: _loading,
          onPressed: _loading ? null : _settlePayout,
        ),
      ],
    ],
  );

  Widget _errorNotice(String text) => SectionCard(
    color: AppColors.warningLight,
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.warningDark,
      ),
    ),
  );
}