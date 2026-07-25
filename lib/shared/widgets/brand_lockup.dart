import 'package:flutter/material.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2A23A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.front_hand_outlined, color: Color(0xFF10283A)),
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Punho',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Agarra o comando.',
              style: TextStyle(color: Color(0xFFB7C5CE), fontSize: 11),
            ),
          ],
        ),
      ],
    ],
  );
}
