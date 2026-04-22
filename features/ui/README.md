# Glassmorphism Widget

A reusable Flutter widget that provides a beautiful glassmorphism effect with semi-transparent dark layers and frosted glass appearance.

## Features

- **Performance Optimized**: Uses blur intensity of 10-20 for optimal performance
- **Customizable**: Adjustable opacity, blur, border radius, and colors
- **Predefined Styles**: Ready-to-use styles for dialogs, cards, and bottom sheets
- **Extension Methods**: Easy-to-use extension methods for quick implementation
- **Modern Design**: Clean, modern look perfect for contemporary apps

## Usage

### Basic Usage

```dart
import 'package:your_app/features/ui/glassmorphism_widget.dart';

GlassmorphismWidget(
  child: Text('Hello Glassmorphism!'),
  blurIntensity: 15.0,
  opacity: 0.2,
  borderRadius: 16.0,
)
```

### Predefined Styles

```dart
// Dialog style
GlassmorphismStyles.dialog(
  child: YourDialogContent(),
)

// Card style
GlassmorphismStyles.card(
  child: YourCardContent(),
)

// Bottom sheet style
GlassmorphismStyles.bottomSheet(
  child: YourBottomSheetContent(),
)
```

### Extension Methods

```dart
// Quick glassmorphism
Text('Hello').withGlassmorphism()

// Predefined styles
Text('Hello').withDialogGlassmorphism()
Text('Hello').withCardGlassmorphism()
Text('Hello').withBottomSheetGlassmorphism()
```

### Custom Parameters

```dart
GlassmorphismWidget(
  child: YourContent(),
  blurIntensity: 18.0,        // Blur strength (10-20 recommended)
  opacity: 0.25,              // Transparency (0.15-0.25 recommended)
  borderRadius: 20.0,         // Corner radius
  borderWidth: 2.0,           // Border thickness
  borderColor: Color(0x50FFFFFF), // Border color
  backgroundColor: Color(0x25FFFFFF), // Background color
  padding: EdgeInsets.all(24.0), // Internal padding
  margin: EdgeInsets.all(16.0),  // External margin
)
```

## Best Practices

1. **Performance**: Keep blur intensity between 10-20 for optimal performance
2. **Opacity**: Use low opacity (0.15-0.25) for subtle background visibility
3. **Rounded Corners**: Use rounded corners with light borders for modern look
4. **Consistency**: Use predefined styles for consistent design across your app
5. **Background**: Works best over colorful or gradient backgrounds

## Examples

See `glassmorphism_examples.dart` for complete implementation examples including:
- Dialog with glassmorphism effect
- Bottom sheet with glassmorphism effect
- Card with glassmorphism effect
- Extension method usage
- Complete example page

## Integration

To integrate into your app's design system:

1. Import the widget in your app's style/theme files
2. Create custom styles that match your app's design language
3. Use consistently across dialogs, cards, and overlays
4. Consider adding to your app's component library

## Performance Notes

- The widget uses `BackdropFilter` which can be performance-intensive
- Avoid using on large areas or in scrollable lists with many instances
- Test performance on lower-end devices
- Consider using `RepaintBoundary` for complex child widgets
