import 'package:flutter/material.dart';

class MicButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const MicButton({
    super.key,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  bool _pressed = false;

  void _handlePress() {
    setState(() => _pressed = true);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _pressed = false);
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePress,
      onLongPress: _handlePress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5252).withValues(alpha: _pressed ? 0.2 : 0.4),
                blurRadius: _pressed ? 6 : 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
