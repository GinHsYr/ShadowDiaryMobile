import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.textFieldKey,
    required this.controller,
    required this.hintText,
    required this.clearTooltip,
    required this.onClear,
    this.clearButtonKey,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onTapOutside,
    this.trailing,
    super.key,
  });

  final Key textFieldKey;
  final TextEditingController controller;
  final String hintText;
  final String clearTooltip;
  final ValueChanged<String>? onChanged;
  final VoidCallback onClear;
  final Key? clearButtonKey;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TapRegionCallback? onTapOutside;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.isNotEmpty;
    final suffix = hasQuery || trailing != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasQuery)
                IconButton(
                  key: clearButtonKey,
                  tooltip: clearTooltip,
                  onPressed: onClear,
                  icon: const Icon(Icons.cancel_rounded),
                ),
              ?trailing,
            ],
          )
        : null;

    return TextField(
      key: textFieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTapOutside: onTapOutside,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: suffix,
        filled: true,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
