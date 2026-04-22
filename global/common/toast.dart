import 'package:flutter/material.dart'; // Import Material Design package
import 'package:fluttertoast/fluttertoast.dart';
import '../../features/extra/constants.dart';

/// Simple toast notification (uses Fluttertoast plugin)
/// Use for quick messages that don't need user interaction
void showToast({required String message}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: Colors.black, // Now recognized
    textColor: Colors.white, // Now recognized
  );
}

/// PHASE 4: Unified snackbar for error/info messages
/// Use for errors and important notifications that need more visibility
/// Requires BuildContext - use when ScaffoldMessenger is available
void showAppMessage({
  required BuildContext context,
  required String message,
  bool isError = true,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: 12.rw),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isError ? Colors.red.shade600 : Colors.blue.shade600,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.all(16.r),
    ),
  );
}

/// Show success message (green snackbar)
void showSuccessMessage({
  required BuildContext context,
  required String message,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: 12.rw),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.all(16.r),
    ),
  );
}