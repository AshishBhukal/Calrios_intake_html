import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';

/// Model for a calorie reaction
class CalorieReaction {
  final String fromUserId;
  final String fromUserFirstName;
  final String fromUserLastName;
  final String fromUserProfileUrl;
  final String emoji;
  final DateTime timestamp;

  const CalorieReaction({
    required this.fromUserId,
    required this.fromUserFirstName,
    required this.fromUserLastName,
    required this.fromUserProfileUrl,
    required this.emoji,
    required this.timestamp,
  });

  factory CalorieReaction.fromMap(Map<String, dynamic> map) {
    return CalorieReaction(
      fromUserId: map['fromUserId'] ?? '',
      fromUserFirstName: map['fromUserFirstName'] ?? '',
      fromUserLastName: map['fromUserLastName'] ?? '',
      fromUserProfileUrl: map['fromUserProfileUrl'] ?? '',
      emoji: map['emoji'] ?? '',
      timestamp:
          (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'fromUserFirstName': fromUserFirstName,
      'fromUserLastName': fromUserLastName,
      'fromUserProfileUrl': fromUserProfileUrl,
      'emoji': emoji,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

/// Service for managing calorie reactions
class CalorieReactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Preset emojis for the reaction picker
  static const List<String> presetEmojis = [
    '\u{1F525}',
    '\u{1F4AA}',
    '\u2B50',
    '\u{1F44F}',
    '\u{1F3AF}',
  ];

  /// Validate if an emoji is supported.
  ///
  /// Ensures the input is exactly one grapheme cluster and matches
  /// common emoji Unicode ranges.
  bool isValidEmoji(String emoji) {
    if (emoji.isEmpty) return false;

    final graphemes = emoji.characters;

    // Must be exactly one user-perceived character
    if (graphemes.length != 1) return false;

    // Standard emoji regex pattern covering most common emojis
    final emojiRegex = RegExp(
      r'^('
      r'[\u{1F600}-\u{1F64F}]|' // Emoticons
      r'[\u{1F300}-\u{1F5FF}]|' // Misc Symbols and Pictographs
      r'[\u{1F680}-\u{1F6FF}]|' // Transport and Map
      r'[\u{1F700}-\u{1F77F}]|' // Alchemical Symbols
      r'[\u{1F780}-\u{1F7FF}]|' // Geometric Shapes Extended
      r'[\u{1F800}-\u{1F8FF}]|' // Supplemental Arrows-C
      r'[\u{1F900}-\u{1F9FF}]|' // Supplemental Symbols and Pictographs
      r'[\u{1FA00}-\u{1FA6F}]|' // Chess Symbols
      r'[\u{1FA70}-\u{1FAFF}]|' // Symbols and Pictographs Extended-A
      r'[\u{2600}-\u{26FF}]|' // Misc symbols
      r'[\u{2700}-\u{27BF}]|' // Dingbats
      r'[\u{231A}-\u{231B}]|' // Watch, Hourglass
      r'[\u{23E9}-\u{23F3}]|' // Various symbols
      r'[\u{23F8}-\u{23FA}]|' // Various symbols
      r'[\u{25AA}-\u{25AB}]|' // Squares
      r'[\u{25B6}]|' // Play button
      r'[\u{25C0}]|' // Reverse button
      r'[\u{25FB}-\u{25FE}]|' // Squares
      r'[\u{2614}-\u{2615}]|' // Umbrella, Hot beverage
      r'[\u{2648}-\u{2653}]|' // Zodiac
      r'[\u{267F}]|' // Wheelchair
      r'[\u{2693}]|' // Anchor
      r'[\u{26A1}]|' // High voltage
      r'[\u{26AA}-\u{26AB}]|' // Circles
      r'[\u{26BD}-\u{26BE}]|' // Sports
      r'[\u{26C4}-\u{26C5}]|' // Weather
      r'[\u{26CE}]|' // Ophiuchus
      r'[\u{26D4}]|' // No entry
      r'[\u{26EA}]|' // Church
      r'[\u{26F2}-\u{26F3}]|' // Fountain, Golf
      r'[\u{26F5}]|' // Sailboat
      r'[\u{26FA}]|' // Tent
      r'[\u{26FD}]|' // Fuel pump
      r'[\u{2702}]|' // Scissors
      r'[\u{2705}]|' // Check mark
      r'[\u{2708}-\u{270D}]|' // Various
      r'[\u{270F}]|' // Pencil
      r'[\u{2712}]|' // Black nib
      r'[\u{2714}]|' // Check mark
      r'[\u{2716}]|' // X mark
      r'[\u{271D}]|' // Cross
      r'[\u{2721}]|' // Star of David
      r'[\u{2728}]|' // Sparkles
      r'[\u{2733}-\u{2734}]|' // Symbols
      r'[\u{2744}]|' // Snowflake
      r'[\u{2747}]|' // Sparkle
      r'[\u{274C}]|' // Cross mark
      r'[\u{274E}]|' // Cross mark
      r'[\u{2753}-\u{2755}]|' // Question marks
      r'[\u{2757}]|' // Exclamation
      r'[\u{2763}-\u{2764}]|' // Hearts
      r'[\u{2795}-\u{2797}]|' // Math symbols
      r'[\u{27A1}]|' // Arrow
      r'[\u{27B0}]|' // Curly loop
      r'[\u{27BF}]|' // Double curly loop
      r'[\u{2934}-\u{2935}]|' // Arrows
      r'[\u{2B05}-\u{2B07}]|' // Arrows
      r'[\u{2B1B}-\u{2B1C}]|' // Squares
      r'[\u{2B50}]|' // Star
      r'[\u{2B55}]|' // Circle
      r'[\u{3030}]|' // Wavy dash
      r'[\u{303D}]|' // Part alternation mark
      r'[\u{3297}]|' // Circled Ideograph Congratulation
      r'[\u{3299}]|' // Circled Ideograph Secret
      r'[\u{00A9}]|' // Copyright
      r'[\u{00AE}]|' // Registered
      r'[\u{203C}]|' // Double exclamation
      r'[\u{2049}]|' // Exclamation question
      r'[\u{2122}]|' // Trademark
      r'[\u{2139}]|' // Information
      r'[\u{2194}-\u{2199}]|' // Arrows
      r'[\u{21A9}-\u{21AA}]|' // Arrows
      r'[\u{23CF}]|' // Eject
      r'[\u{24C2}]|' // M circled
      r'[\u{2660}]|' // Spade
      r'[\u{2663}]|' // Club
      r'[\u{2665}-\u{2666}]|' // Heart, Diamond
      r'[\u{2668}]|' // Hot springs
      r'[\u{267B}]|' // Recycle
      r'[\u{26A0}]|' // Warning
      r'[\u{26C8}]|' // Thunder cloud
      r'[\u{26CF}]|' // Pick
      r'[\u{26D1}]|' // Helmet
      r'[\u{26D3}]|' // Chains
      r'[\u{26E9}]|' // Shinto shrine
      r'[\u{26F0}-\u{26F1}]|' // Mountain, Beach
      r'[\u{26F4}]|' // Ferry
      r'[\u{26F7}-\u{26F9}]|' // Skier, etc
      r'[\u{2709}]|' // Envelope
      r'[\u{270A}-\u{270B}]|' // Fists
      r'[\u{270C}-\u{270D}]|' // Victory, Writing hand
      r'[\u{FE0F}]?' // Variation selector (optional)
      r')+$',
      unicode: true,
    );

    return emojiRegex.hasMatch(emoji);
  }

  /// Get reactions that a user has received for a specific week
  Future<List<CalorieReaction>> getReceivedReactions(
    String userId,
    String weekKey,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('calorie_reactions_received')
          .doc(weekKey)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CalorieReaction.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting received reactions: $e');
      return [];
    }
  }

  /// Get the reaction that current user gave to a specific target user
  Future<String?> getGivenReaction(
    String toUserId,
    String weekKey,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('calorie_reactions_given')
          .doc(weekKey)
          .get();

      if (doc.exists) {
        return doc.data()?[toUserId] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting given reaction: $e');
      return null;
    }
  }

  /// Get all reactions given by current user for a specific week
  Future<Map<String, String>> getAllGivenReactions(
      String weekKey) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return {};

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('calorie_reactions_given')
          .doc(weekKey)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        return Map<String, String>.from(
          data.map((key, value) => MapEntry(key, value.toString())),
        );
      }
      return {};
    } catch (e) {
      debugPrint('Error getting all given reactions: $e');
      return {};
    }
  }

  /// Add or update a reaction
  Future<bool> addOrUpdateReaction({
    required String toUserId,
    required String emoji,
    required String weekKey,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    if (!isValidEmoji(emoji)) {
      debugPrint('Invalid emoji rejected');
      return false;
    }

    try {
      // Get current user's profile info for denormalization
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final currentUserData = currentUserDoc.data() ?? {};

      // Use a batch to update both collections atomically
      final batch = _firestore.batch();

      // 1. Update the receiver's reactions_received collection
      final receiverReactionRef = _firestore
          .collection('users')
          .doc(toUserId)
          .collection('calorie_reactions_received')
          .doc(weekKey)
          .collection('items')
          .doc(currentUser.uid);

      batch.set(receiverReactionRef, {
        'fromUserId': currentUser.uid,
        'fromUserFirstName': currentUserData['firstName'] ?? '',
        'fromUserLastName': currentUserData['lastName'] ?? '',
        'fromUserProfileUrl':
            currentUserData['profileImageUrl'] ?? '',
        'emoji': emoji,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update the sender's reactions_given collection
      final senderGivenRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('calorie_reactions_given')
          .doc(weekKey);

      batch.set(
          senderGivenRef, {toUserId: emoji}, SetOptions(merge: true));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error adding reaction: $e');
      return false;
    }
  }

  /// Remove a reaction
  Future<bool> removeReaction({
    required String toUserId,
    required String weekKey,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // 1. Remove from receiver's reactions_received
      final receiverReactionRef = _firestore
          .collection('users')
          .doc(toUserId)
          .collection('calorie_reactions_received')
          .doc(weekKey)
          .collection('items')
          .doc(currentUser.uid);

      batch.delete(receiverReactionRef);

      // 2. Remove from sender's reactions_given
      final senderGivenRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('calorie_reactions_given')
          .doc(weekKey);

      batch.update(senderGivenRef, {
        toUserId: FieldValue.delete(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error removing reaction: $e');
      return false;
    }
  }

  /// Group reactions by emoji for display.
  static Map<String, int> groupReactionsByEmoji(
      List<CalorieReaction> reactions) {
    final Map<String, int> grouped = {};
    for (final reaction in reactions) {
      grouped[reaction.emoji] =
          (grouped[reaction.emoji] ?? 0) + 1;
    }
    return grouped;
  }
}
