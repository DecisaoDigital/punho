import 'package:flutter/material.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 38,
        height: 38,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Transform.scale(
            scale: 1.12,
            child: Image.asset(
              'assets/brand/punho_elo_operacao_v010.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
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
