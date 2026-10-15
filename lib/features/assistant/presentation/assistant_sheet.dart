import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/assistant/assistant_engine.dart';
import '../../../data/store/ajo_store.dart';

class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AssistantSheet(),
    );
  }

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _Msg {
  _Msg(this.text, this.mine);
  final String text;
  final bool mine;
}

class _AssistantSheetState extends State<AssistantSheet> {
  final AjoStore _s = AjoStore.instance;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  late bool _pidgin = _s.pidginDefault;
  bool _typing = false;

  static const _suggestions = [
    'When is my turn?',
    'Why is my payout held?',
    'Who hasn\'t paid?',
    'How much is in the pot?',
    'Show my history',
  ];

  @override
  void initState() {
    super.initState();
    _msgs.add(
      _Msg(
        _pidgin
            ? 'How far ${_s.meName}! Na Ajo AI. I fit read your circle ledger and explain things. I no fit move money.'
            : 'Hi ${_s.meName}! I\'m Ajo AI. I can read your circle\'s ledger and explain what\'s going on. I can\'t move money.',
        false,
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(q, true));
      _typing = true;
    });
    _toBottom();
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    final usePidgin = _pidgin || AssistantEngine.looksPidgin(q);
    final answer = AssistantEngine.reply(q, _s, pidgin: usePidgin);
    setState(() {
      _typing = false;
      _msgs.add(_Msg(answer, false));
    });
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        height: h * 0.82,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajo AI',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Reads your ledger · can\'t move money',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.translate_rounded, size: 16),
                    label: const Text('Pidgin'),
                    selected: _pidgin,
                    onSelected: (v) => setState(() => _pidgin = v),
                    selectedColor: AppColors.mintLight,
                    checkmarkColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                itemCount: _msgs.length + (_typing ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _msgs.length) return const _TypingBubble();
                  return _Bubble(msg: _msgs[i]);
                },
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(_suggestions[i]),
                  onPressed: () => _send(_suggestions[i]),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your circle…',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(_input.text),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(50, 50),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});

  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: msg.mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.mine ? 18 : 4),
            bottomRight: Radius.circular(msg.mine ? 4 : 18),
          ),
          border: msg.mine ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          msg.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: msg.mine ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const SizedBox(
          width: 36,
          height: 10,
          child: LinearProgressIndicator(
            color: AppColors.mint,
            backgroundColor: AppColors.mintLight,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),
    );
  }
}
