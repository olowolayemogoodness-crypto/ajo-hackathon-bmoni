import 'package:flutter/material.dart';

import '../../data/models/models.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.size = 42, this.ring = false});

  final Member member;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: member.color.withValues(alpha: 0.16),
      ),
      child: Text(
        member.initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: member.color,
        ),
      ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: member.color, width: 2),
      ),
      child: avatar,
    );
  }
}
