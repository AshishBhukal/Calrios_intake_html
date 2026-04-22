import 'package:flutter/material.dart';
import 'package:fitness2/global/common/toast.dart';
import 'package:fitness2/my_account_widgets/add_friends.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/services/friend_service.dart';
import 'dart:ui';

class FriendListScreen extends StatefulWidget {
  const FriendListScreen({super.key});

  @override
  _FriendListScreenState createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  final FriendService _friendService = FriendService();
  List<Map<String, dynamic>> _friendsList = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriendsList();
    _loadPendingRequests();
    _loadSentRequests();
  }

  Future<void> _loadFriendsList() async {
    try {
      final friends = await _friendService.getFriendsList();
      if (!mounted) return;
      setState(() {
        _friendsList = friends;
        _isLoading = false;
      });
    } catch (e) {
      showToast(message: "Failed to load friends. Please try again.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requests = await _friendService.getPendingRequests();
      if (!mounted) return;
      setState(() => _pendingRequests = requests);
    } catch (e) {
      if (mounted) setState(() => _pendingRequests = []);
      showToast(message: "Could not load friend requests. Pull down to retry.");
    }
  }

  Future<void> _loadSentRequests() async {
    try {
      final requests = await _friendService.getSentRequests();
      if (!mounted) return;
      setState(() => _sentRequests = requests);
    } catch (e) {
      if (mounted) setState(() => _sentRequests = []);
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final requestId = request['requestId'] as String?;
    final fromUserId = request['fromUserId'] as String?;
    if (requestId == null || fromUserId == null) return;

    final error = await _friendService.acceptRequest(fromUserId, requestId);
    if (error != null) {
      showToast(message: error);
    } else {
      showToast(message: "Friend added");
      _loadFriendsList();
      _loadPendingRequests();
    }
  }

  Future<void> _declineRequest(String requestId) async {
    final error = await _friendService.declineRequest(requestId);
    if (error != null) {
      showToast(message: error);
    } else {
      showToast(message: "Request declined");
      _loadPendingRequests();
    }
  }

  Future<void> _cancelSentRequest(String toUserId) async {
    final error = await _friendService.cancelSentRequest(toUserId);
    if (error != null) {
      showToast(message: error);
    } else {
      showToast(message: "Request cancelled");
      _loadSentRequests();
    }
  }

  Future<void> _removeFriend(String friendId, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _buildRemoveDialog(friendName),
    );

    if (confirmed != true) return;

    final error = await _friendService.removeFriend(friendId);
    if (error != null) {
      showToast(message: error);
    } else {
      showToast(message: "Friend removed");
      _loadFriendsList();
    }
  }

  Widget _buildRemoveDialog(String friendName) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0f2a4f), DesignSystem.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Remove Friend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.rh),
            Text(
              'Are you sure you want to remove $friendName from your friends list?',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.rh),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.rw,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.rw),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.rw,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background_1.png'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Glassmorphic App Header
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.rw, vertical: 16.rh),
                    decoration: BoxDecoration(
                      color: DesignSystem.dark.withOpacity(0.9),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Friends",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddFriendScreen(
                                onChanged: () {
                                  _loadFriendsList();
                                  _loadPendingRequests();
                                },
                              ),
                            ),
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: DesignSystem.glassmorphicButton,
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 4,
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const CircularProgressIndicator(
              color: DesignSystem.primary,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16.rh),
          const Text(
            "Loading friends...",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadFriendsList();
        await _loadPendingRequests();
        await _loadSentRequests();
      },
      color: DesignSystem.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20.r),
        children: [
          _buildPendingRequestsSection(),
          SizedBox(height: 24.rh),
          _buildSentRequestsSection(),
          SizedBox(height: 24.rh),
          _buildFriendsListSection(),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "REQUESTS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.rh),
        if (_pendingRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 20.rh),
            decoration: DesignSystem.glassmorphicCard,
            child: Text(
              "No pending requests. Pull down to refresh.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._pendingRequests.map((request) {
          final displayName = request['displayName'] ?? 'Unknown';
          final username = request['username'] ?? 'unknown';
          return Container(
            margin: EdgeInsets.only(bottom: 12.rh),
            decoration: DesignSystem.glassmorphicCard,
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: request['photoUrl'] != null
                          ? null
                          : DesignSystem.primaryGradient,
                      borderRadius: BorderRadius.circular(50),
                      image: request['photoUrl'] != null
                          ? DecorationImage(
                              image: NetworkImage(request['photoUrl']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: request['photoUrl'] == null
                        ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
                        : null,
                  ),
                  SizedBox(width: 16.rw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@$username',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _acceptRequest(request),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DesignSystem.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: DesignSystem.success,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _declineRequest(request['requestId'] as String),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: DesignSystem.glassmorphicButton,
                      child: const Icon(
                        Icons.close_rounded,
                        color: DesignSystem.danger,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSentRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "SENT REQUESTS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.rh),
        if (_sentRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.rh),
            decoration: DesignSystem.glassmorphicCard,
            child: Text(
              "No sent requests.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._sentRequests.map((request) {
            final displayName = request['displayName'] ?? 'Unknown';
            final username = request['username'] ?? 'unknown';
            final toUserId = request['toUserId'] as String?;
            if (toUserId == null) return const SizedBox.shrink();
            return Container(
              margin: EdgeInsets.only(bottom: 12.rh),
              decoration: DesignSystem.glassmorphicCard,
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: request['photoUrl'] != null
                            ? null
                            : DesignSystem.primaryGradient,
                        borderRadius: BorderRadius.circular(50),
                        image: request['photoUrl'] != null
                            ? DecorationImage(
                                image: NetworkImage(request['photoUrl']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: request['photoUrl'] == null
                          ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
                          : null,
                    ),
                    SizedBox(width: 16.rw),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@$username',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.rh),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 14, color: DesignSystem.mediumGray),
                              SizedBox(width: 4.rw),
                              Text(
                                'Request sent',
                                style: TextStyle(
                                  color: DesignSystem.mediumGray,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _cancelSentRequest(toUserId),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: DesignSystem.glassmorphicButton,
                        child: const Icon(
                          Icons.close_rounded,
                          color: DesignSystem.danger,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFriendsListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "FRIENDS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.rh),
        if (_friendsList.isEmpty)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddFriendScreen(
                  onChanged: () {
                    _loadFriendsList();
                    _loadPendingRequests();
                  },
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 24.rh),
              decoration: DesignSystem.glassmorphicCard,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  SizedBox(height: 12.rh),
                  Text(
                    "You haven't added any friends yet",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.rh),
                  Text(
                    "Tap to add a friend",
                    style: TextStyle(
                      color: DesignSystem.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._friendsList.map((friend) => _buildFriendTile(friend)),
      ],
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    final String displayName = friend['displayName'];
    final String username = friend['username'];
    return Container(
      margin: EdgeInsets.only(bottom: 12.rh),
      decoration: DesignSystem.glassmorphicCard,
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: friend['photoUrl'] != null
                    ? null
                    : DesignSystem.primaryGradient,
                borderRadius: BorderRadius.circular(50),
                image: friend['photoUrl'] != null
                    ? DecorationImage(
                        image: NetworkImage(friend['photoUrl']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: friend['photoUrl'] == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
            SizedBox(width: 16.rw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _removeFriend(
                friend['userId'],
                displayName,
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: DesignSystem.glassmorphicButton,
                child: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: DesignSystem.danger,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}