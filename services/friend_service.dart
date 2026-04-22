import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum FriendRelationship {
  none,
  friends,
  requestSent,
  requestReceived,
}

class FriendRelationshipResult {
  final FriendRelationship relationship;
  final String? requestId;

  const FriendRelationshipResult({
    required this.relationship,
    this.requestId,
  });
}

class FriendService {
  static final FriendService _instance = FriendService._();
  factory FriendService() => _instance;
  FriendService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Determine the relationship between the current user and [otherUserId].
  Future<FriendRelationshipResult> checkRelationship(String otherUserId) async {
    final uid = _currentUserId;
    if (uid == null) {
      return const FriendRelationshipResult(relationship: FriendRelationship.none);
    }

    try {
      final friendDoc = await _firestore
          .collection('users').doc(uid)
          .collection('friends').doc(otherUserId)
          .get();

      if (friendDoc.exists) {
        return const FriendRelationshipResult(relationship: FriendRelationship.friends);
      }

      final sentQuery = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: uid)
          .where('toUserId', isEqualTo: otherUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (sentQuery.docs.isNotEmpty) {
        return FriendRelationshipResult(
          relationship: FriendRelationship.requestSent,
          requestId: sentQuery.docs.first.id,
        );
      }

      final receivedQuery = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: otherUserId)
          .where('toUserId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (receivedQuery.docs.isNotEmpty) {
        return FriendRelationshipResult(
          relationship: FriendRelationship.requestReceived,
          requestId: receivedQuery.docs.first.id,
        );
      }

      return const FriendRelationshipResult(relationship: FriendRelationship.none);
    } catch (e) {
      debugPrint('FriendService.checkRelationship error: $e');
      return const FriendRelationshipResult(relationship: FriendRelationship.none);
    }
  }

  /// Send a friend request. Returns error message on failure, null on success.
  Future<String?> sendRequest(String toUserId) async {
    final uid = _currentUserId;
    if (uid == null) return 'Not logged in';
    if (uid == toUserId) return 'You cannot add yourself as a friend';

    try {
      final friendDoc = await _firestore
          .collection('users').doc(uid)
          .collection('friends').doc(toUserId)
          .get();
      if (friendDoc.exists) return 'Already friends';

      final sentQuery = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: uid)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (sentQuery.docs.isNotEmpty) return 'Request already sent';

      final receivedQuery = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: toUserId)
          .where('toUserId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (receivedQuery.docs.isNotEmpty) {
        return 'This user already sent you a request. Accept it instead.';
      }

      // Remove stale accepted/declined request docs so re-adding is possible
      await _cleanupOldRequests(uid, toUserId);

      final requestId = '${uid}_$toUserId';
      await _firestore.collection('friend_requests').doc(requestId).set({
        'fromUserId': uid,
        'toUserId': toUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      debugPrint('FriendService.sendRequest error: $e');
      return 'Failed to send request. Please try again.';
    }
  }

  /// Cancel a pending request the current user sent.
  Future<String?> cancelSentRequest(String toUserId) async {
    final uid = _currentUserId;
    if (uid == null) return 'Not logged in';

    try {
      final requestId = '${uid}_$toUserId';
      await _firestore.collection('friend_requests').doc(requestId).delete();
      return null;
    } catch (e) {
      debugPrint('FriendService.cancelSentRequest error: $e');
      return 'Failed to cancel request. Please try again.';
    }
  }

  /// Accept a received friend request. Creates mutual friendship.
  ///
  /// Two-step write: the request must be marked 'accepted' before
  /// the friend docs are created, because Firestore security rules
  /// check the request status when the acceptor writes to the
  /// requester's friends subcollection.
  Future<String?> acceptRequest(String fromUserId, String requestId) async {
    final uid = _currentUserId;
    if (uid == null) return 'Not logged in';

    try {
      // Step 1 – mark request accepted (required by security rules before step 2)
      await _firestore
          .collection('friend_requests').doc(requestId)
          .update({'status': 'accepted'});

      // Fetch both profiles in parallel for the friend documents
      final profiles = await Future.wait([
        _firestore.collection('users').doc(uid).get(),
        _firestore.collection('users').doc(fromUserId).get(),
      ]);

      final myData = profiles[0].data() ?? {};
      final theirData = profiles[1].data() ?? {};

      // Step 2 – create mutual friend docs atomically
      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('users').doc(uid)
            .collection('friends').doc(fromUserId),
        _buildFriendDoc(fromUserId, theirData),
      );

      batch.set(
        _firestore.collection('users').doc(fromUserId)
            .collection('friends').doc(uid),
        _buildFriendDoc(uid, myData),
      );

      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('FriendService.acceptRequest error: $e');
      return 'Failed to accept request. Please try again.';
    }
  }

  /// Decline a received friend request.
  Future<String?> declineRequest(String requestId) async {
    if (_currentUserId == null) return 'Not logged in';

    try {
      await _firestore.collection('friend_requests').doc(requestId).delete();
      return null;
    } catch (e) {
      debugPrint('FriendService.declineRequest error: $e');
      return 'Failed to decline request. Please try again.';
    }
  }

  /// Remove a friend (mutual unfriend) and clean up related request docs.
  Future<String?> removeFriend(String friendId) async {
    final uid = _currentUserId;
    if (uid == null) return 'Not logged in';

    try {
      final batch = _firestore.batch();

      batch.delete(
        _firestore.collection('users').doc(uid)
            .collection('friends').doc(friendId),
      );
      batch.delete(
        _firestore.collection('users').doc(friendId)
            .collection('friends').doc(uid),
      );

      await batch.commit();

      // Non-critical cleanup – remove stale request docs so they can re-add
      await _cleanupOldRequests(uid, friendId);

      return null;
    } catch (e) {
      debugPrint('FriendService.removeFriend error: $e');
      return 'Failed to remove friend. Please try again.';
    }
  }

  /// Load the current user's friends list.
  Future<List<Map<String, dynamic>>> getFriendsList() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users').doc(uid)
          .collection('friends')
          .get();

      final uniqueFriends = <String, Map<String, dynamic>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final friendId = data['friendId']?.toString() ?? doc.id;

        if (!uniqueFriends.containsKey(friendId)) {
          final display = data['displayName']?.toString().trim();
          final first = (data['firstName'] ?? '').toString().trim();
          final last = (data['lastName'] ?? '').toString().trim();
          final fallback =
              display?.isNotEmpty == true ? display! : '$first $last'.trim();
          final displayName = fallback.isNotEmpty
              ? fallback
              : (data['username'] ?? 'No name').toString();

          uniqueFriends[friendId] = {
            'userId': friendId,
            'displayName': displayName,
            'username': data['username'] ?? 'unknown',
            'photoUrl': data['photoUrl'],
            'docId': doc.id,
          };
        }
      }

      return uniqueFriends.values.toList();
    } catch (e) {
      debugPrint('FriendService.getFriendsList error: $e');
      return [];
    }
  }

  /// Load incoming pending friend requests with sender profile info.
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      final List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final fromUserId = data['fromUserId'] as String?;
        if (fromUserId == null) continue;

        final userDoc =
            await _firestore.collection('users').doc(fromUserId).get();
        final userData = userDoc.data() ?? {};

        requests.add({
          'requestId': doc.id,
          'fromUserId': fromUserId,
          'displayName': _buildDisplayName(userData),
          'username': userData['userName'] ?? 'unknown',
          'photoUrl': userData['photoUrl'],
        });
      }

      return requests;
    } catch (e) {
      debugPrint('FriendService.getPendingRequests error: $e');
      return [];
    }
  }

  /// Load outgoing (sent) pending friend requests with recipient profile info.
  Future<List<Map<String, dynamic>>> getSentRequests() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      final List<Map<String, dynamic>> requests = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'] as String?;
        if (toUserId == null) continue;

        final userDoc =
            await _firestore.collection('users').doc(toUserId).get();
        final userData = userDoc.data() ?? {};

        requests.add({
          'requestId': doc.id,
          'toUserId': toUserId,
          'displayName': _buildDisplayName(userData),
          'username': userData['userName'] ?? 'unknown',
          'photoUrl': userData['photoUrl'],
        });
      }

      return requests;
    } catch (e) {
      debugPrint('FriendService.getSentRequests error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _buildDisplayName(Map<String, dynamic> userData) {
    final first = (userData['firstName'] ?? '').toString().trim();
    final last = (userData['lastName'] ?? '').toString().trim();
    final display = '$first $last'.trim();
    return display.isNotEmpty
        ? display
        : (userData['userName'] ?? 'Friend').toString();
  }

  Map<String, dynamic> _buildFriendDoc(
      String friendId, Map<String, dynamic> userData) {
    return {
      'friendId': friendId,
      'displayName': _buildDisplayName(userData),
      'username': userData['userName'],
      'firstName': userData['firstName'],
      'lastName': userData['lastName'],
      'uniqueID': userData['uniqueID'],
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  /// Delete non-pending request docs between two users so they can interact
  /// again after unfriending.
  Future<void> _cleanupOldRequests(String userId1, String userId2) async {
    try {
      final query1 = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId1)
          .where('toUserId', isEqualTo: userId2)
          .get();

      final query2 = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId2)
          .where('toUserId', isEqualTo: userId1)
          .get();

      final batch = _firestore.batch();
      bool hasDeletes = false;

      for (var doc in query1.docs) {
        if (doc.data()['status'] != 'pending') {
          batch.delete(doc.reference);
          hasDeletes = true;
        }
      }

      for (var doc in query2.docs) {
        if (doc.data()['status'] != 'pending') {
          batch.delete(doc.reference);
          hasDeletes = true;
        }
      }

      if (hasDeletes) await batch.commit();
    } catch (e) {
      debugPrint('FriendService._cleanupOldRequests error: $e');
    }
  }
}
