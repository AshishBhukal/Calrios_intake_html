import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness2/services/friend_service.dart';
import 'constants.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String userId;

  const PlayerProfileScreen({super.key, required this.userId});

  @override
  _PlayerProfileScreenState createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendService _friendService = FriendService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  FriendRelationship _relationship = FriendRelationship.none;
  String? _requestId;
  List<Map<String, dynamic>> _friendsList = [];
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _checkRelationship();
    _fetchFriends();
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_features.txt ID f_5e6f7g_features
  Future<void> _fetchUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data()!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkRelationship() async {
    final result = await _friendService.checkRelationship(widget.userId);
    if (!mounted) return;

    setState(() {
      _relationship = result.relationship;
      _requestId = result.requestId;
    });
  }

  Future<void> _fetchFriends() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .get();

      if (!mounted) return;
      setState(() {
        _friendsList = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (_) {}
  }

  String get _friendActionLabel {
    switch (_relationship) {
      case FriendRelationship.none:
        return 'Add Friend';
      case FriendRelationship.requestSent:
        return 'Cancel Request';
      case FriendRelationship.requestReceived:
        return 'Accept Request';
      case FriendRelationship.friends:
        return 'Remove Friend';
    }
  }

  Future<void> _handleFriendAction() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);

    String? error;

    switch (_relationship) {
      case FriendRelationship.none:
        error = await _friendService.sendRequest(widget.userId);
        break;
      case FriendRelationship.requestSent:
        error = await _friendService.cancelSentRequest(widget.userId);
        break;
      case FriendRelationship.requestReceived:
        if (_requestId != null) {
          error = await _friendService.acceptRequest(widget.userId, _requestId!);
        }
        break;
      case FriendRelationship.friends:
        error = await _friendService.removeFriend(widget.userId);
        break;
    }

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      final messages = {
        FriendRelationship.none: 'Friend request sent!',
        FriendRelationship.requestSent: 'Request cancelled',
        FriendRelationship.requestReceived: 'Friend added!',
        FriendRelationship.friends: 'Friend removed',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messages[_relationship] ?? 'Done'),
          backgroundColor: Colors.green,
        ),
      );
    }

    await _checkRelationship();
  }

  void _showFriendsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(16.r),
        child: Column(
          children: [
            Text(
              'Friends List',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16.rh),
            Expanded(
              child: _friendsList.isEmpty
                  ? const Center(
                child: Text(
                  'No friends yet',
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : ListView.builder(
                itemCount: _friendsList.length,
                itemBuilder: (context, index) {
                  final friend = _friendsList[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.2),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      friend['displayName'] ?? 'Unknown',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '@${friend['username'] ?? 'unknown'}',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      margin: EdgeInsets.all(16.r),
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.withOpacity(0.2),
              backgroundImage: _userData!['photoUrl'] != null
                  ? NetworkImage(_userData!['photoUrl'])
                  : null,
              child: _userData!['photoUrl'] == null
                  ? Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            SizedBox(height: 16.rh),
            Text(
              '${_userData!['firstName'] ?? ''} ${_userData!['lastName'] ?? ''}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '@${_userData!['username'] ?? 'unknown'}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 16.rh),
            if (_userData!['dateOfBirth'] != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cake, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Born ${_userData!['dateOfBirth']}',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16.rh),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _actionLoading ? null : _handleFriendAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _relationship == FriendRelationship.friends
                        ? Colors.red
                        : _relationship == FriendRelationship.requestSent
                            ? Colors.grey
                            : Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 12.rh),
                  ),
                  child: _actionLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : Text(
                          _friendActionLabel,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
                OutlinedButton(
                  onPressed: _showFriendsList,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,  // Changed from primary to foregroundColor
                    side: BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 12.rh),
                  ),
                  child: Text(
                    'View Friends',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingSection() {
    return Card(
      margin: EdgeInsets.all(16.r),
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ranking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16.rh),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Global Rank',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  '#${_userData?['rank']?.toString() ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey[700]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Points',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  _userData?['points']?.toString() ?? '0',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
    // Get status bar height for Dynamic Island devices
    final statusBarHeight = MediaQuery.of(context).padding.top;
    // Use minimal padding (8px) for status bar, allowing content behind Dynamic Island
    final topPadding = statusBarHeight > 0 ? 8.0 : 0.0;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A192F), Colors.black],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: topPadding), // Minimal padding for status bar
          child: _isLoading
              ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : _userData == null
              ? Center(
            child: Text(
              'User not found',
              style: TextStyle(color: Colors.white),
            ),
          )
              : SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileSection(),
                _buildRankingSection(),
                SizedBox(height: 32.rh),
              ],
            ),
          ),
        ),
      ),
    );
  }
}