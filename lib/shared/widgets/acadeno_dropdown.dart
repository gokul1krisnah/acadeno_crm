import 'package:flutter/material.dart';

/// A standardized item model for [AcadenoDropdown].
class AcadenoDropdownItem<T> {
  final T value;
  final String label;
  final Widget? icon;
  final String? subtitle;

  const AcadenoDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
  });
}

/// A centralized, modern, high-quality dropdown component used across the Acadeno CRM.
/// Provides consistent padding, clean borders, custom chevron icon, and smooth popup styling.
class AcadenoDropdown<T> extends StatelessWidget {
  final T? value;
  final List<AcadenoDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? label;
  final Widget? prefixIcon;
  final bool isExpanded;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;
  final String? Function(T?)? validator;
  final Color? fillColor;
  final Color? borderColor;
  final double borderRadius;
  final bool enabled;

  const AcadenoDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.label,
    this.prefixIcon,
    this.isExpanded = true,
    this.isDense = true,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.validator,
    this.fillColor = Colors.white,
    this.borderColor = const Color(0xFFE5E7EB),
    this.borderRadius = 14.0,
    this.enabled = true,
  });

  /// Factory constructor for simple String lists.
  static AcadenoDropdown<String> strings({
    Key? key,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    String? hint,
    String? label,
    Widget? prefixIcon,
    bool isExpanded = true,
    bool isDense = true,
    EdgeInsetsGeometry? contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    String? Function(String?)? validator,
    Color? fillColor = Colors.white,
    Color? borderColor = const Color(0xFFE5E7EB),
    double borderRadius = 14.0,
    bool enabled = true,
  }) {
    return AcadenoDropdown<String>(
      key: key,
      value: value,
      items: items
          .map((s) => AcadenoDropdownItem<String>(value: s, label: s))
          .toList(),
      onChanged: onChanged,
      hint: hint,
      label: label,
      prefixIcon: prefixIcon,
      isExpanded: isExpanded,
      isDense: isDense,
      contentPadding: contentPadding,
      validator: validator,
      fillColor: fillColor,
      borderColor: borderColor,
      borderRadius: borderRadius,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? const Color(0xFFE5E7EB);
    final effectiveRadius = BorderRadius.circular(borderRadius);

    final dropdownWidget = DropdownButtonFormField<T>(
      initialValue: (items.any((item) => item.value == value)) ? value : null,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: isExpanded,
      isDense: isDense,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF6B7280),
        size: 20,
      ),
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: Color(0xFF111827),
      ),
      hint: hint != null
          ? Text(
              hint!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF9CA3AF),
              ),
              overflow: TextOverflow.ellipsis,
            )
          : null,
      decoration: InputDecoration(
        isDense: isDense,
        contentPadding: contentPadding,
        filled: true,
        fillColor: enabled ? (fillColor ?? Colors.white) : const Color(0xFFF9FAFB),
        prefixIcon: prefixIcon,
        border: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide(color: effectiveBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide(color: effectiveBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: const BorderSide(color: Color(0xFF4338CA), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                item.icon!,
                const SizedBox(width: 8),
              ],
              Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
              if (item.subtitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  item.subtitle!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label!,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          dropdownWidget,
        ],
      );
    }

    return dropdownWidget;
  }
}
