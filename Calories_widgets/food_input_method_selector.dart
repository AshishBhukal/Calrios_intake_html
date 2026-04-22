import 'package:flutter/material.dart';
import '../features/extra/constants.dart';

/// Unified food input method selector: barcode, text AI, image AI (later), recipe.
/// Shown as a bottom sheet from the plus button in Calories In tab.
class FoodInputMethodSelector extends StatelessWidget {
  final VoidCallback onScanFoodPhoto;
  final VoidCallback onScanBarcode;
  final VoidCallback onDescribeFood;
  final VoidCallback onFromRecipe;

  const FoodInputMethodSelector({
    super.key,
    required this.onScanFoodPhoto,
    required this.onScanBarcode,
    required this.onDescribeFood,
    required this.onFromRecipe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A192F), Colors.black],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 16.rh, bottom: 8),
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF4361EE).withOpacity(0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(24.rw, 16.rh, 24.rw, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Food',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Input method options
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.rw),
            child: Column(
              children: [
                _buildMethodOption(
                  context: context,
                  icon: Icons.photo_camera_outlined,
                  title: 'Scan Food Photo',
                  subtitle: 'AI analyzes your meal from a picture',
                  iconColor: const Color(0xFF4361EE),
                  onTap: onScanFoodPhoto,
                ),
                SizedBox(height: 12.rh),
                _buildMethodOption(
                  context: context,
                  icon: Icons.qr_code_scanner,
                  title: 'Scan Barcode',
                  subtitle: 'Quick nutrition from product barcode',
                  iconColor: const Color(0xFF4CC9F0),
                  onTap: onScanBarcode,
                ),
                SizedBox(height: 12.rh),
                _buildMethodOption(
                  context: context,
                  icon: Icons.edit_note_outlined,
                  title: 'Describe Food',
                  subtitle: 'Type or speak what you ate',
                  iconColor: const Color(0xFF4895EF),
                  onTap: onDescribeFood,
                ),
                SizedBox(height: 12.rh),
                _buildMethodOption(
                  context: context,
                  icon: Icons.restaurant_menu_outlined,
                  title: 'From Recipe',
                  subtitle: 'Select from saved recipes',
                  iconColor: const Color(0xFF38B000),
                  onTap: onFromRecipe,
                ),
              ],
            ),
          ),
          SizedBox(height: 32.rh),
        ],
      ),
    );
  }

  Widget _buildMethodOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool comingSoon = false,
  }) {
    return Semantics(
      label: comingSoon ? '$title (coming soon)' : title,
      hint: subtitle,
      button: true,
      child: GestureDetector(
      onTap: comingSoon
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('AI Image Scanner coming soon!'),
                  backgroundColor: Color(0xFF4895EF),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : onTap,
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(comingSoon ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(comingSoon ? 0.03 : 0.1),
          ),
          boxShadow: comingSoon
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(comingSoon ? 0.05 : 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: comingSoon ? iconColor.withOpacity(0.4) : iconColor,
                  size: 28,
                ),
              ),
            ),
            SizedBox(width: 16.rw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: comingSoon ? Colors.white.withOpacity(0.4) : Colors.white,
                        ),
                      ),
                      if (comingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4895EF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF4895EF).withOpacity(0.3)),
                          ),
                          child: Text(
                            'SOON',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4895EF).withOpacity(0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(comingSoon ? 0.3 : 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(comingSoon ? 0.2 : 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    ),
    );
  }
}
