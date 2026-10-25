import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Whole-franc input used by the simulators.
class MoneyField extends StatefulWidget {
  const MoneyField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final Money value;
  final ValueChanged<Money> onChanged;
  final String? helper;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final _controller = TextEditingController(
    text: widget.value.isZero ? '' : '${widget.value.amount.round()}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: 'CHF ',
        helperText: widget.helper,
        helperMaxLines: 3,
      ),
      onChanged: (text) =>
          widget.onChanged(Money.cents((int.tryParse(text) ?? 0) * 100)),
    ),
  );
}

/// Label on the left, value on the right.
class ResultRow extends StatelessWidget {
  const ResultRow({
    required this.label,
    required this.value,
    this.emphasised = false,
    super.key,
  });
  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasised ? finoraInk : finoraMutedInk,
              fontWeight: emphasised ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: emphasised ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Small grey explanation under a result.
class SimulatorNote extends StatelessWidget {
  const SimulatorNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: const TextStyle(color: finoraMutedInk, fontSize: 12, height: 1.4),
    ),
  );
}
