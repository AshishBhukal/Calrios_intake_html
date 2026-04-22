import 'package:flutter/material.dart';
import 'friends_calories_dashboard.dart';

class SocialCalories extends StatelessWidget {
  const SocialCalories({super.key});

  @override
  Widget build(BuildContext context) {
    // No wrapping Scaffold - parent already provides one.
    // Nested Scaffolds cause unexpected gesture/layout conflicts.
    return const FriendsCaloriesDashboard();
  }
}
