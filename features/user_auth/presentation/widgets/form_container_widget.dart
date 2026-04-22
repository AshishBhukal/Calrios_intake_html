import 'package:flutter/material.dart';
import 'package:fitness2/features/extra/constants.dart';

class FormContainerWidget extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final bool isPasswordField;
  final TextStyle hintStyle;
  final TextStyle textStyle;
  final TextInputType? keyboardType;
  final double? height;
  final double? width;
  final String? errorText;
  final Widget? prefixIcon;
  final bool isEnabled;
  final VoidCallback? onTap;
  final bool readOnly;
  /// Optional border radius; when null uses [DesignSystem.smallRadius].
  final double? borderRadius;
  /// Optional background when unfocused (e.g. glass style); when null uses transparent.
  final Color? filledColor;
  /// Optional border color when unfocused; when null uses transparent.
  final Color? borderColor;
  /// Optional callback when text changes.
  final ValueChanged<String>? onChanged;

  const FormContainerWidget({
    super.key,
    this.controller,
    this.hintText,
    this.isPasswordField = false,
    required this.hintStyle,
    required this.textStyle,
    this.keyboardType,
    this.height = 56.0,
    this.width,
    this.errorText,
    this.prefixIcon,
    this.isEnabled = true,
    this.onTap,
    this.readOnly = false,
    this.borderRadius,
    this.filledColor,
    this.borderColor,
    this.onChanged,
  });

  @override
  _FormContainerWidgetState createState() => _FormContainerWidgetState();
}

class _FormContainerWidgetState extends State<FormContainerWidget> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() {
            _isFocused = hasFocus;
          });
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: _isFocused 
                ? DesignSystem.glassBg.withOpacity(0.3)
                : (widget.filledColor ?? Colors.transparent),
            borderRadius: BorderRadius.circular(widget.borderRadius ?? DesignSystem.smallRadius),
            border: Border.all(
              color: _isFocused 
                  ? DesignSystem.primaryLight
                  : widget.errorText != null
                      ? DesignSystem.danger
                      : (widget.borderColor ?? Colors.transparent),
              width: (_isFocused || widget.errorText != null) ? 2.0 : (widget.borderColor != null ? 1.0 : 2.0),
            ),
            boxShadow: _isFocused 
                ? [
                    BoxShadow(
                      color: DesignSystem.primaryLight.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? DesignSystem.smallRadius),
            child: TextField(
              controller: widget.controller,
              obscureText: widget.isPasswordField ? _obscureText : false,
              keyboardType: widget.keyboardType,
              enabled: widget.isEnabled,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              onChanged: widget.onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: widget.textStyle.copyWith(
                color: widget.isEnabled ? DesignSystem.light : DesignSystem.mediumGray,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: widget.hintStyle.copyWith(
                  color: DesignSystem.mediumGray,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DesignSystem.spacing16,
                  vertical: DesignSystem.spacing16,
                ),
                isDense: false,
                  errorText: widget.errorText,
                  errorStyle: TextStyle(
                    color: DesignSystem.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: widget.prefixIcon != null
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: DesignSystem.spacing12,
                            right: DesignSystem.spacing8,
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              color: _isFocused 
                                  ? DesignSystem.primaryLight
                                  : DesignSystem.mediumGray,
                              size: 20,
                            ),
                            child: widget.prefixIcon!,
                          ),
                        )
                      : null,
                  suffixIcon: widget.isPasswordField
                      ? Padding(
                          padding: const EdgeInsets.only(right: DesignSystem.spacing8),
                          child: IconButton(
                            icon: Icon(
                              _obscureText 
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: _isFocused 
                                  ? DesignSystem.primaryLight
                                  : DesignSystem.mediumGray,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}