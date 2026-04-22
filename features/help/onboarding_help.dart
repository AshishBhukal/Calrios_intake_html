import 'package:flutter/material.dart';
import '../extra/constants.dart';

/// Help system for the conversational onboarding flow
class OnboardingHelp extends StatelessWidget {
  const OnboardingHelp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF050c1a),
              Color(0xFF0A192F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),
              
              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24.r),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 16.rw),
          const Text(
            'Onboarding Help',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.rw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpSection(
            title: 'Getting Started',
            icon: Icons.play_circle_outline,
            content: [
              'Welcome to your personalized fitness journey!',
              'This onboarding process will take about 2-3 minutes.',
              'We\'ll ask you some questions to create your custom nutrition plan.',
              'All information is kept private and secure.',
            ],
          ),
          
          SizedBox(height: 24.rh),
          
          _buildHelpSection(
            title: 'What We\'ll Ask',
            icon: Icons.quiz_outlined,
            content: [
              'Your name and basic information',
              'Date of birth and preferred units (kg/lb, cm/ft)',
              'Current weight and height',
              'Activity level and fitness goals',
              'Optional: target weight and timeline',
              'Account credentials for saving your progress',
            ],
          ),
          
          SizedBox(height: 24.rh),
          
          _buildHelpSection(
            title: 'AI-Powered Goals',
            icon: Icons.psychology_outlined,
            content: [
              'Our AI analyzes your information to create personalized goals.',
              'We calculate your daily calorie and macro targets.',
              'Timeline adjustments ensure safe, sustainable progress.',
              'All recommendations are based on scientific research.',
            ],
          ),
          
          SizedBox(height: 24.rh),
          
          _buildHelpSection(
            title: 'Privacy & Security',
            icon: Icons.security_outlined,
            content: [
              'Your data is encrypted and stored securely.',
              'We never share your personal information.',
              'You can delete your account anytime.',
              'All AI processing is done securely.',
            ],
          ),
          
          SizedBox(height: 24.rh),
          
          _buildHelpSection(
            title: 'Need Help?',
            icon: Icons.help_outline,
            content: [
              'You can skip optional questions if unsure.',
              'Use the "Back" button to review previous answers.',
              'Contact support if you encounter any issues.',
              'Your progress is saved automatically.',
            ],
          ),
          
          SizedBox(height: 32.rh),
          
          _buildTipCard(),
          
          SizedBox(height: 32.rh),
        ],
      ),
    );
  }

  Widget _buildHelpSection({
    required String title,
    required IconData icon,
    required List<String> content,
  }) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF4361EE),
                size: 24,
              ),
              SizedBox(width: 12.rw),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          ...content.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(top: 6, right: 12.rw),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4361EE),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 12.rw),
              const Text(
                'Pro Tip',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.rh),
          const Text(
            'Be as accurate as possible with your measurements. This helps our AI create the most personalized and effective nutrition plan for your goals.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
