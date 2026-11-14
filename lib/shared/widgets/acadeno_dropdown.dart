import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

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
/// Matches Figma source of truth (node-id=1809-1576 & 1809-1570):
/// - Soft grey trigger bar (0xFFF5F5F5), 16px corner radius, subtle shadow
/// - Up/down chevron in dark plum (0xFF2E1D44)
/// - Expanded list card (0xFFE2E2E2), 12px corner radius, soft violet shadow
/// - Active/selected item highlighted in rich orange (0xFFD35401), rounded 12px, white text
/// - Unselected items in 0xFF2E1D44
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
  final Color? dropdownColor;
  final Color? activeItemColor;
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
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 21,
      vertical: 11,
    ),
    this.validator,
    this.fillColor = const Color(0xFFF5F5F5),
    this.borderColor = const Color(0xFFE5E7EB),
    this.dropdownColor = const Color(0xFFE2E2E2),
    this.activeItemColor = const Color(0xFFD35401),
    this.borderRadius = 16.0,
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
    EdgeInsetsGeometry? contentPadding = const EdgeInsets.symmetric(
      horizontal: 21,
      vertical: 11,
    ),
    String? Function(String?)? validator,
    Color? fillColor = const Color(0xFFF5F5F5),
    Color? borderColor = const Color(0xFFE5E7EB),
    Color? dropdownColor = const Color(0xFFE2E2E2),
    Color? activeItemColor = const Color(0xFFD35401),
    double borderRadius = 16.0,
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
      dropdownColor: dropdownColor,
      activeItemColor: activeItemColor,
      borderRadius: borderRadius,
      enabled: enabled,
    );
  }

  /// Builds a DropdownMenuItem styled to match Figma 1809:1576 active & inactive states.
  static Widget buildMenuItemChild({
    required String label,
    required bool isSelected,
    Widget? icon,
    String? subtitle,
    Color activeColor = const Color(0xFFD35401),
    Color textColor = const Color(0xFF2E1D44),
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 16,
              ),
              child: icon,
            ),
            const Gap(8),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: isSelected ? 13.5 : 14,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? Colors.white : textColor,
                letterSpacing: isSelected ? 0.425 : 0,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const Gap(6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: isSelected ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? const Color(0xFFE5E7EB);
    final effectiveFillColor = enabled
        ? (fillColor ?? const Color(0xFFF5F5F5))
        : const Color(0xFFF9FAFB);
    final effectiveRadius = BorderRadius.circular(borderRadius);
    final activeColor = activeItemColor ?? const Color(0xFFD35401);
    const textColor = Color(0xFF2E1D44);

    final dropdownWidget = Container(
      decoration: BoxDecoration(
        color: effectiveFillColor,
        borderRadius: effectiveRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D764BA2),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: (items.any((item) => item.value == value)) ? value : null,
          focusColor: Colors.transparent,
          onChanged: enabled ? onChanged : null,
        validator: validator,
        isExpanded: isExpanded,
        isDense: isDense,
        dropdownColor: dropdownColor ?? const Color(0xFFE2E2E2),
        borderRadius: BorderRadius.circular(12),
        elevation: 6,
        menuMaxHeight: 320,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: textColor,
          size: 20,
        ),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
        hint: hint != null
            ? Text(
                hint!,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9CA3AF),
                ),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        decoration: InputDecoration(
          isDense: isDense,
          contentPadding: contentPadding,
          filled: true,
          fillColor: Colors.transparent,
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
            borderSide: BorderSide(color: activeColor, width: 1.5),
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
        selectedItemBuilder: (BuildContext context) {
          return items.map<Widget>((item) {
            return Row(
              children: [
                if (item.icon != null) ...[
                  IconTheme(
                    data: const IconThemeData(
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                    child: item.icon!,
                  ),
                  const Gap(8),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
                if (item.subtitle != null) ...[
                  const Gap(6),
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            );
          }).toList();
        },
        items: items.map((item) {
          final isSelected = item.value == value;
          return DropdownMenuItem<T>(
            value: item.value,
            child: buildMenuItemChild(
              label: item.label,
              isSelected: isSelected,
              icon: item.icon,
              subtitle: item.subtitle,
              activeColor: activeColor,
              textColor: textColor,
            ),
          );
        }).toList(),
      ),
    ),
  );

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const Gap(6),
          dropdownWidget,
        ],
      );
    }

    return dropdownWidget;
  }
}
