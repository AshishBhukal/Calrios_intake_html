import 'dart:io';
import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../features/extra/constants.dart';

class WatchSetupScreen extends StatefulWidget {
  const WatchSetupScreen({super.key});

  @override
  State<WatchSetupScreen> createState() => _WatchSetupScreenState();
}

class _WatchSetupScreenState extends State<WatchSetupScreen> {
  bool _isLoading = true;
  bool _isAvailable = false;
  bool _hasPermissions = false;
  bool _isConnecting = false;

  // Data types that will be synced
  static const List<_HealthDataInfo> _dataTypes = [
    _HealthDataInfo(
      name: 'Workouts',
      description: 'Exercise sessions with type, duration, and calories',
      icon: Icons.fitness_center,
    ),
    _HealthDataInfo(
      name: 'Calories Burned',
      description: 'Active energy expenditure during activities',
      icon: Icons.local_fire_department,
    ),
    _HealthDataInfo(
      name: 'Distance',
      description: 'Walking, running, and cycling distance',
      icon: Icons.straighten,
    ),
    _HealthDataInfo(
      name: 'Heart Rate',
      description: 'Average heart rate during workouts',
      icon: Icons.favorite,
    ),
    _HealthDataInfo(
      name: 'Steps',
      description: 'Step count for walking and running activities',
      icon: Icons.directions_walk,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    try {
      final available = await HealthService.isAvailable();
      final hasPerms = await HealthService.hasPermissions();

      if (mounted) {
        setState(() {
          _isAvailable = available;
          _hasPermissions = hasPerms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final granted = await HealthService.requestPermissions();
      if (mounted) {
        setState(() {
          _hasPermissions = granted;
          _isConnecting = false;
        });
        if (granted) {
          _showSnackBar('Connected successfully!');
        } else {
          _showSnackBar('Permission not granted. Please allow access in your device settings.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _showSnackBar('Connection error. Please try again.');
      }
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121c36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Disconnect Health Data?',
          style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
        ),
        content: Text(
          'This will revoke health data access. Your existing activity logs will not be deleted.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.redAccent, fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HealthService.revokePermissions();
      if (mounted) {
        setState(() => _hasPermissions = false);
        _showSnackBar('Disconnected from health data.');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Connect Health Device',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4895ef)))
          : ListView(
              padding: EdgeInsets.fromLTRB(20.rw, 12.rh, 20.rw, 40.rh),
              children: [
                _buildPlatformCard(),
                SizedBox(height: 24.rh),
                _buildConnectionButton(),
                SizedBox(height: 28.rh),
                _buildDataTypesSection(),
                SizedBox(height: 28.rh),
                _buildPrivacyNotice(),
              ],
            ),
    );
  }

  // ============================================================================
  // PLATFORM CARD
  // ============================================================================

  Widget _buildPlatformCard() {
    final isIOS = Platform.isIOS;
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF121c36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasPermissions
              ? const Color(0xFF4895ef).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Platform icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _hasPermissions
                  ? const Color(0xFF4361EE).withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isIOS ? Icons.watch : Icons.watch,
              color: _hasPermissions
                  ? const Color(0xFF4cc9f0)
                  : Colors.white.withOpacity(0.3),
              size: 28,
            ),
          ),
          SizedBox(width: 16.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIOS ? 'Apple Watch' : 'Wear OS Watch',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isIOS ? 'via Apple HealthKit' : 'via Health Connect',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          // Status indicator
          Column(
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.rw, vertical: 6),
                decoration: BoxDecoration(
                  color: _hasPermissions
                      ? const Color(0xFF4895ef).withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hasPermissions
                        ? const Color(0xFF4895ef).withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _hasPermissions
                            ? const Color(0xFF4cc9f0)
                            : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hasPermissions ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        color: _hasPermissions
                            ? const Color(0xFF4cc9f0)
                            : Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // CONNECTION BUTTON
  // ============================================================================

  Widget _buildConnectionButton() {
    if (!_isAvailable) {
      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber,
                color: Colors.orange.withOpacity(0.7), size: 24),
            SizedBox(width: 12.rw),
            Expanded(
              child: Text(
                Platform.isAndroid
                    ? 'Health Connect is not installed. Please install it from the Play Store.'
                    : 'HealthKit is not available on this device.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasPermissions) {
      return GestureDetector(
        onTap: _disconnect,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.rh),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_off, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Disconnect',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _isConnecting ? null : _connect,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.rh),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4895ef), Color(0xFF4cc9f0)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4895ef).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isConnecting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              const Icon(Icons.link, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              _isConnecting ? 'Connecting...' : 'Connect',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DATA TYPES
  // ============================================================================

  Widget _buildDataTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATA WE READ',
          style: TextStyle(
            color: const Color(0xFF4895ef).withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontFamily: 'Inter',
          ),
        ),
        SizedBox(height: 12.rh),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121c36),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: _dataTypes.asMap().entries.map((entry) {
              final idx = entry.key;
              final info = entry.value;
              return Column(
                children: [
                  _buildDataTypeRow(info),
                  if (idx < _dataTypes.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.04),
                      indent: 56,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTypeRow(_HealthDataInfo info) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 14.rh),
      child: Row(
        children: [
          Icon(info.icon,
              color: const Color(0xFF4895ef).withOpacity(0.6), size: 20),
          SizedBox(width: 14.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _hasPermissions ? Icons.check_circle : Icons.radio_button_unchecked,
            color: _hasPermissions
                ? const Color(0xFF4cc9f0)
                : Colors.white.withOpacity(0.15),
            size: 20,
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // PRIVACY NOTICE
  // ============================================================================

  Widget _buildPrivacyNotice() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined,
              color: Colors.white.withOpacity(0.3), size: 20),
          SizedBox(width: 12.rw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We only read workout and activity data from your health platform. '
                  'Data is stored securely in your account and is never shared with third parties. '
                  'You can disconnect at any time.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthDataInfo {
  final String name;
  final String description;
  final IconData icon;

  const _HealthDataInfo({
    required this.name,
    required this.description,
    required this.icon,
  });
}
