import 'package:flutter/material.dart';

class HoverPasswordField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;

  const HoverPasswordField({super.key, required this.label, this.controller});

  @override
  State<HoverPasswordField> createState() => _HoverPasswordFieldState();
}

class _HoverPasswordFieldState extends State<HoverPasswordField> {
  bool _isObscure = true; // 기본

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _isObscure,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: MouseRegion(
          cursor: SystemMouseCursors.click, // 마우스 올리면 손가락 모양으로 변경
          onEnter: (_) => setState(() => _isObscure = false), // 아이콘 진입 시 노출
          onExit: (_) => setState(() => _isObscure = true), // 아이콘 이탈 시 은폐
          child: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }
}
