import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PhoneOrientation { landscape, portrait }

/// Aplica uma orientação em telefones e, quando pedido, também em tablets.
/// Em computadores a chamada é inofensiva e a janela mantém o seu controlo.
class PhoneOrientationLock extends StatefulWidget {
  const PhoneOrientationLock({
    super.key,
    required this.orientation,
    required this.child,
    this.lockOnTablets = false,
  });

  final PhoneOrientation orientation;
  final Widget child;
  final bool lockOnTablets;

  @override
  State<PhoneOrientationLock> createState() => _PhoneOrientationLockState();
}

class _PhoneOrientationLockState extends State<PhoneOrientationLock> {
  bool? _isPhone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    final shouldLock = isPhone || widget.lockOnTablets;
    if (_isPhone == shouldLock) return;
    _isPhone = shouldLock;
    _applyOrientation(shouldLock);
  }

  @override
  void didUpdateWidget(covariant PhoneOrientationLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orientation != widget.orientation && _isPhone == true) {
      _applyOrientation(true);
    }
  }

  void _applyOrientation(bool isPhone) {
    if (!isPhone) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
      return;
    }
    unawaited(
      SystemChrome.setPreferredOrientations(
        widget.orientation == PhoneOrientation.landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
