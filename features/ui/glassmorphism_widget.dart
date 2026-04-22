import 'package:flutter/material.dart';
import 'dart:ui';
import '../extra/constants.dart';

/// A reusable Glassmorphism widget that provides a semi-transparent
/// dark layer with frosted glass effect for dialogs, cards, and overlays.
class GlassmorphismWidget extends StatelessWidget {
  /// The child widget to display inside the glassmorphism container
  final Widget child;
  
  /// The blur intensity for the glass effect (default: 15)
  /// Recommended range: 10-20 for optimal performance
  final double blurIntensity;
  
  /// The opacity of the overlay (default: 0.2)
  /// Recommended range: 0.15-0.25 for subtle background visibility
  final double opacity;
  
  /// Border radius for rounded corners (default: 16)
  final double borderRadius;
  
  /// Border width for the frosted glass look (default: 1.5)
  final double borderWidth;
  
  /// Border color for the frosted glass effect (default: white with low opacity)
  final Color borderColor;
  
  /// Background color for the glass effect (default: white with low opacity)
  final Color backgroundColor;
  
  /// Padding inside the glassmorphism container
  final EdgeInsetsGeometry? padding;
  
  /// Margin around the glassmorphism container
  final EdgeInsetsGeometry? margin;
  
  /// Width of the container (optional)
  final double? width;
  
  /// Height of the container (optional)
  final double? height;

  const GlassmorphismWidget({
    super.key,
    required this.child,
    this.blurIntensity = 15.0,
    this.opacity = 0.2,
    this.borderRadius = 16.0,
    this.borderWidth = 1.5,
    this.borderColor = const Color(0x400A1A2F),
    this.backgroundColor = const Color(0x200A1A2F),
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurIntensity,
            sigmaY: blurIntensity,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Predefined glassmorphism styles for common use cases
class GlassmorphismStyles {
  /// Light glassmorphism style for light backgrounds
  static GlassmorphismWidget light({required Widget child}) => GlassmorphismWidget(
    blurIntensity: 15.0,
    opacity: 0.15,
    borderColor: const Color(0x300A1A2F),
    backgroundColor: const Color(0x100A1A2F),
    child: child,
  );

  /// Dark glassmorphism style for dark backgrounds
  static GlassmorphismWidget dark({required Widget child}) => GlassmorphismWidget(
    blurIntensity: 15.0,
    opacity: 0.2,
    borderColor: const Color(0x400A1A2F),
    backgroundColor: const Color(0x200A1A2F),
    child: child,
  );

  /// Dialog glassmorphism style with more padding
  static GlassmorphismWidget dialog({required Widget child}) => GlassmorphismWidget(
    blurIntensity: 18.0,
    opacity: 0.25,
    borderRadius: 20.0,
    borderWidth: 2.0,
    borderColor: const Color(0x500A1A2F),
    backgroundColor: const Color(0x250A1A2F),
    padding: EdgeInsets.all(24.0.r),
    child: child,
  );

  /// Card glassmorphism style for content cards
  static GlassmorphismWidget card({required Widget child}) => GlassmorphismWidget(
    blurIntensity: 12.0,
    opacity: 0.18,
    borderRadius: 12.0,
    borderWidth: 1.0,
    borderColor: const Color(0x350A1A2F),
    backgroundColor: const Color(0x150A1A2F),
    padding: EdgeInsets.all(16.0.r),
    child: child,
  );

  /// Bottom sheet glassmorphism style
  static GlassmorphismWidget bottomSheet({required Widget child}) => GlassmorphismWidget(
    blurIntensity: 20.0,
    opacity: 0.3,
    borderRadius: 24.0,
    borderWidth: 1.5,
    borderColor: const Color(0x450A1A2F),
    backgroundColor: const Color(0x300A1A2F),
    padding: EdgeInsets.all(20.0.r),
    child: child,
  );
}

/// Extension methods for easy glassmorphism application
extension GlassmorphismExtension on Widget {
  /// Wraps the widget with a glassmorphism effect
  Widget withGlassmorphism({
    double blurIntensity = 15.0,
    double opacity = 0.2,
    double borderRadius = 16.0,
    double borderWidth = 1.5,
    Color borderColor = const Color(0x400A1A2F),
    Color backgroundColor = const Color(0x200A1A2F),
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
  }) {
    return GlassmorphismWidget(
      blurIntensity: blurIntensity,
      opacity: opacity,
      borderRadius: borderRadius,
      borderWidth: borderWidth,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      child: this,
    );
  }

  /// Wraps the widget with a dialog glassmorphism effect
  Widget withDialogGlassmorphism() {
    return GlassmorphismStyles.dialog(child: this);
  }

  /// Wraps the widget with a card glassmorphism effect
  Widget withCardGlassmorphism() {
    return GlassmorphismStyles.card(child: this);
  }

  /// Wraps the widget with a bottom sheet glassmorphism effect
  Widget withBottomSheetGlassmorphism() {
    return GlassmorphismStyles.bottomSheet(child: this);
  }
}

/// Extension to create copies of GlassmorphismWidget with different properties
extension GlassmorphismWidgetExtension on GlassmorphismWidget {
  GlassmorphismWidget copyWith({
    Widget? child,
    double? blurIntensity,
    double? opacity,
    double? borderRadius,
    double? borderWidth,
    Color? borderColor,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
  }) {
    return GlassmorphismWidget(
      blurIntensity: blurIntensity ?? this.blurIntensity,
      opacity: opacity ?? this.opacity,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      width: width ?? this.width,
      height: height ?? this.height,
      child: child ?? this.child,
    );
  }
}
