import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Editable quantity selector for B2B bulk orders.
///
/// Replaces the old +/- only stepper. The numeric field is the primary
/// input (typing is the common case for bulk orders); +/- buttons remain
/// as a ±1 fallback and never disable visually — tapping `−` when the
/// value is already 1 is a silent no-op, matching the previous behavior.
class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the controller when the parent changes the value externally
    // (e.g. via the +/- buttons), but only if the field isn't being
    // actively edited — otherwise we'd overwrite the user's typing.
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _inc() => widget.onChanged(widget.value + 1);

  void _dec() {
    if (widget.value > 1) {
      widget.onChanged(widget.value - 1);
    }
    // value == 1 → silent no-op (kept on purpose)
  }

  /// Called on Enter / focus-loss. If the field ended empty or with an
  /// invalid number, revert the controller to the last valid value so the
  /// UI doesn't get stuck on "0" or "".
  void _commitOnExit() {
    final text = _controller.text.trim();
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 1) {
      if (parsed != widget.value) widget.onChanged(parsed);
    } else {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.label,
            style: GoogleFonts.outfit(
              color: const Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Color(0xFF475569),
                ),
                onPressed: _dec,
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 5,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (text) {
                    if (text.isEmpty) return;
                    final parsed = int.tryParse(text);
                    if (parsed != null && parsed >= 1) {
                      widget.onChanged(parsed);
                    }
                  },
                  onSubmitted: (_) => _focusNode.unfocus(),
                  onEditingComplete: () {
                    _commitOnExit();
                    _focusNode.unfocus();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF475569),
                ),
                onPressed: _inc,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
