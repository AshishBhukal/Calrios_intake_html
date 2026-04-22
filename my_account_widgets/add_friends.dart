import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/services/friend_service.dart';

class AddFriendScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const AddFriendScreen({super.key, required this.onChanged});

  @override
  _AddFriendScreenState createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendService _friendService = FriendService();
  Map<String, dynamic>? _searchedUser;
  bool _isLoading = false;
  bool _isSearchFocused = false;
  FriendRelationship _requestState = FriendRelationship.none;
  String? _receivedRequestId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    setState(() {
      _isLoading = true;
      _searchedUser = null;
    });

    String username = _searchController.text.trim();

    if (username.isEmpty) {
      _showToast("Please enter a username");
      setState(() => _isLoading = false);
      return;
    }

    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('userName', isEqualTo: username)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
        var documentId = querySnapshot.docs.first.id;

        if (!userData.containsKey('userId')) {
          userData['userId'] = documentId;
        }

        setState(() {
          _searchedUser = userData;
          _requestState = FriendRelationship.none;
          _receivedRequestId = null;
        });
        await _checkFriendRequestState();
      } else {
        _showToast("No user found with this username");
      }
    } catch (e) {
      _showToast("Failed to search for user. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFriendRequestState() async {
    final friendId = _searchedUser?['userId'] as String?;
    if (friendId == null || friendId.isEmpty) return;

    final result = await _friendService.checkRelationship(friendId);
    if (!mounted) return;
    setState(() {
      _requestState = result.relationship;
      _receivedRequestId = result.requestId;
    });
  }

  Future<void> _sendFriendRequest() async {
    final friendId = _searchedUser?['userId'] as String?;
    if (friendId == null || friendId.isEmpty) {
      _showToast("Invalid user");
      return;
    }

    setState(() => _isLoading = true);
    final error = await _friendService.sendRequest(friendId);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      _showToast(error);
      // Refresh relationship in case state changed (e.g. they sent us a request)
      await _checkFriendRequestState();
    } else {
      setState(() => _requestState = FriendRelationship.requestSent);
      _showToast("Friend request sent!");
      widget.onChanged();
    }
  }

  Future<void> _acceptRequest() async {
    if (_receivedRequestId == null || _searchedUser == null) return;

    final friendId = _searchedUser!['userId'] as String?;
    if (friendId == null || friendId.isEmpty) return;

    setState(() => _isLoading = true);
    final error = await _friendService.acceptRequest(friendId, _receivedRequestId!);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      _showToast(error);
    } else {
      setState(() {
        _requestState = FriendRelationship.friends;
        _receivedRequestId = null;
      });
      _showToast("You are now friends!");
      widget.onChanged();
    }
  }

  Future<void> _cancelFriendRequest() async {
    final friendId = _searchedUser?['userId'] as String?;
    if (friendId == null || friendId.isEmpty) return;

    setState(() => _isLoading = true);
    final error = await _friendService.cancelSentRequest(friendId);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      _showToast(error);
    } else {
      setState(() => _requestState = FriendRelationship.none);
      _showToast("Friend request cancelled");
      widget.onChanged();
    }
  }

  Future<void> _declineRequest() async {
    if (_receivedRequestId == null) return;

    setState(() => _isLoading = true);
    final error = await _friendService.declineRequest(_receivedRequestId!);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      _showToast(error);
    } else {
      setState(() {
        _requestState = FriendRelationship.none;
        _receivedRequestId = null;
      });
      _showToast("Request declined");
      widget.onChanged();
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.smallRadius),
        ),
        margin: EdgeInsets.all(DesignSystem.spacing16.r),
      ),
    );
  }

  // Polished theme: glass-style back button, bold title
  Widget _buildModernAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: DesignSystem.spacing24.rw,
            vertical: DesignSystem.spacing16.rh,
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DesignSystem.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: DesignSystem.glassBorder,
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: DesignSystem.light,
                      size: 20,
                    ),
                  ),
                ),
              ),
              SizedBox(width: DesignSystem.spacing16.rw),
              Text(
                'Add Friend',
                style: DesignSystem.titleMedium.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Polished theme: label above, separate input + search button, rounded-2xl, placeholder e.g. #JOHN2024
  Widget _buildSearchCard() {
    return Container(
      margin: EdgeInsets.only(bottom: DesignSystem.spacing32.rh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: DesignSystem.spacing12.rh),
            child: Text(
              'Search by Username',
              style: DesignSystem.labelMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: DesignSystem.mediumGray,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _isSearchFocused = hasFocus;
                    });
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: DesignSystem.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isSearchFocused
                            ? DesignSystem.primary.withOpacity(0.5)
                            : DesignSystem.glassBorder,
                        width: _isSearchFocused ? 2.0 : 1.0,
                      ),
                      boxShadow: _isSearchFocused
                          ? [
                              BoxShadow(
                                color: DesignSystem.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: DesignSystem.bodyMedium.copyWith(
                        color: DesignSystem.light,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. john_doe',
                        hintStyle: DesignSystem.labelMedium.copyWith(
                          color: DesignSystem.mediumGray,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.rw,
                          vertical: 18.rh,
                        ),
                      ),
                      onSubmitted: (_) => _searchUser(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: DesignSystem.spacing12.rw),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _searchUser,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: DesignSystem.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: DesignSystem.primary.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: DesignSystem.light,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(DesignSystem.spacing20.r),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: DesignSystem.primary,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  // Polished theme: section header, glass card, avatar with initials gradient, add button primary/20
  String _getInitials(Map<String, dynamic> user) {
    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    final username = (user['userName'] ?? '').toString().trim();
    if (username.length >= 2) return username.substring(0, 2).toUpperCase();
    if (username.isNotEmpty) return username[0].toUpperCase();
    return '?';
  }

  Widget _buildUserCard() {
    if (_searchedUser == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: DesignSystem.spacing16.rh),
          child: Text(
            'SEARCH RESULTS',
            style: DesignSystem.labelSmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DesignSystem.mediumGray,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.all(DesignSystem.spacing16.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: _requestState == FriendRelationship.requestSent
                  ? _buildUserCardWithSentRow()
                  : Row(
                      children: [
                        _buildUserCardAvatar(),
                        SizedBox(width: DesignSystem.spacing16.rw),
                        Expanded(child: _buildUserCardNameBlock()),
                        _buildRequestStateActions(),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCardAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DesignSystem.primary, Color(0xFF4A7FE9)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getInitials(_searchedUser!),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: DesignSystem.light,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCardNameBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${_searchedUser!['firstName'] ?? ''} ${_searchedUser!['lastName'] ?? ''}".trim(),
          style: DesignSystem.bodyLarge.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DesignSystem.light,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '@${_searchedUser!['userName'] ?? ''}',
          style: DesignSystem.labelMedium.copyWith(
            fontSize: 14,
            color: DesignSystem.light.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCardWithSentRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserCardAvatar(),
        SizedBox(width: DesignSystem.spacing16.rw),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUserCardNameBlock(),
              SizedBox(height: 12.rh),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: DesignSystem.mediumGray, size: 16),
                  SizedBox(width: 6.rw),
                  Text(
                    'Request sent',
                    style: DesignSystem.labelMedium.copyWith(
                      color: DesignSystem.mediumGray,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  _buildActionButton(
                    icon: Icons.close_rounded,
                    onTap: _isLoading ? () {} : _cancelFriendRequest,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestStateActions() {
    switch (_requestState) {
      case FriendRelationship.friends:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 8),
          decoration: BoxDecoration(
            color: DesignSystem.success.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: DesignSystem.success, size: 20),
              const SizedBox(width: 6),
              Text(
                'Friends',
                style: DesignSystem.labelMedium.copyWith(
                  color: DesignSystem.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case FriendRelationship.requestSent:
        return const SizedBox.shrink();
      case FriendRelationship.requestReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(
              icon: Icons.check_rounded,
              onTap: _isLoading ? () {} : _acceptRequest,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              icon: Icons.close_rounded,
              onTap: _isLoading ? () {} : _declineRequest,
            ),
          ],
        );
      case FriendRelationship.none:
        return _buildActionButton(
          icon: Icons.person_add_rounded,
          onTap: _isLoading ? () {} : _sendFriendRequest,
        );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DesignSystem.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: DesignSystem.primary,
            size: 22,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.dark,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        DesignSystem.spacing24.rw,
                        DesignSystem.spacing24.rh,
                        DesignSystem.spacing24.rw,
                        DesignSystem.spacing16.rh,
                      ),
                      child: Column(
                        children: [
                          _buildSearchCard(),
                          if (_isLoading) _buildLoadingIndicator(),
                          _buildUserCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}