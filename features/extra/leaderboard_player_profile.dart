import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness2/features/extra/yt_video_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:fitness2/utils/input_sanitizer.dart';
import 'constants.dart';

class CommentsProvider extends ChangeNotifier {
  List<QueryDocumentSnapshot> _comments = [];
  List<QueryDocumentSnapshot> get comments => _comments;

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_features.txt ID f_2b3c4d_features
  Future<void> loadComments(String compositeKey) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .get();
    _comments = snapshot.docs;
    notifyListeners();
  }

  Future<void> addComment(String compositeKey, String text, String? parentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // SECURITY FIX: Sanitize user input to prevent XSS attacks
    final sanitizedText = InputSanitizer.sanitizeComment(text);
    if (sanitizedText.isEmpty) {
      throw Exception('Comment cannot be empty after sanitization');
    }

    await FirebaseFirestore.instance
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('comments')
        .add({
      'text': sanitizedText,
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'upvotes': 0,
      'downvotes': 0,
      'parentId': parentId,
    });

    await loadComments(compositeKey);
  }

  Future<void> deleteComment(String compositeKey, String commentId) async {
    await FirebaseFirestore.instance
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('comments')
        .doc(commentId)
        .delete();

    await loadComments(compositeKey);
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_features.txt ID f_3c4d5e_features
  Future<void> voteOnComment(String compositeKey, String commentId, bool isUpvote) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final voteDoc = FirebaseFirestore.instance
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('votes')
        .doc('${user.uid}_$commentId');

    final doc = await voteDoc.get();
    final commentRef = FirebaseFirestore.instance
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('comments')
        .doc(commentId);

    if (doc.exists) {
      final currentVote = doc.data()?['vote'] ?? 0;
      if (currentVote == (isUpvote ? 1 : -1)) {
        await voteDoc.delete();
        await commentRef.update({
          isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(-1),
        });
      } else {
        await voteDoc.set({'vote': isUpvote ? 1 : -1});
        await commentRef.update({
          'upvotes': FieldValue.increment(isUpvote ? 1 : -1),
          'downvotes': FieldValue.increment(isUpvote ? -1 : 1),
        });
      }
    } else {
      await voteDoc.set({'vote': isUpvote ? 1 : -1});
      await commentRef.update({
        isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(1),
      });
    }

    await loadComments(compositeKey);
  }
}

class LeaderboardPlayerProfile extends StatefulWidget {
  final String userId;
  final int exerciseId;
  final String monthKey;
  final String ageGroup;
  final String gender;

  const LeaderboardPlayerProfile({
    super.key,
    required this.userId,
    required this.exerciseId,
    required this.monthKey,
    required this.ageGroup,
    required this.gender,
  });

  @override
  _LeaderboardPlayerProfileState createState() => _LeaderboardPlayerProfileState();
  
  // Generate composite key for proof/comment storage
  String get compositeKey => '${exerciseId}_${monthKey}_$userId';
}

class _LeaderboardPlayerProfileState extends State<LeaderboardPlayerProfile> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _reportReasonController = TextEditingController();
  final Set<String> _expandedComments = {}; // Track expanded threads for readability
  String? _replyingToCommentId;
  final int _maxReplyDepth = 3;

  late Future<DocumentSnapshot> _leaderboardEntryFuture;
  late Future<QuerySnapshot> _proofsFuture;
  late Future<DocumentSnapshot> _proofsDataFuture;
  late CommentsProvider _commentsProvider;
  late String _compositeKey;
  
  // Local state for instant UI updates
  int _localUpvotes = 0;
  int _localDownvotes = 0;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _compositeKey = widget.compositeKey;
    _commentsProvider = CommentsProvider();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      // Fetch entry from new leaderboard structure
      final categoryId = '${widget.ageGroup}_${widget.gender}';
      final entryPath = 'leaderboards/${widget.exerciseId}/months/${widget.monthKey}/categories/$categoryId/entries/${widget.userId}';
      _leaderboardEntryFuture = _firestore.doc(entryPath).get();

      // Fetch proofs and voting data from composite key storage
      _proofsDataFuture = _firestore
          .collection('leaderboardProofs')
          .doc(_compositeKey)
          .get();

      _proofsFuture = _firestore
          .collection('leaderboardProofs')
          .doc(_compositeKey)
          .collection('proofs')
          .orderBy('timestamp', descending: true)
          .get();
    });

    await _commentsProvider.loadComments(_compositeKey);
    
    // Sync local state with server data after refresh
    final proofsData = await _proofsDataFuture;
    if (proofsData.exists && mounted) {
      final data = proofsData.data() as Map<String, dynamic>?;
      setState(() {
        _localUpvotes = data?['upvotes'] ?? 0;
        _localDownvotes = data?['downvotes'] ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _reportReasonController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;
    await _commentsProvider.addComment(
      _compositeKey,
      _commentController.text,
      null,
    );
    _commentController.clear();
  }

  Future<void> _addReply(String parentId) async {
    if (_replyController.text.isEmpty) return;
    await _commentsProvider.addComment(
      _compositeKey,
      _replyController.text,
      parentId,
    );
    _replyController.clear();
    setState(() {
      _replyingToCommentId = null;
    });
  }

  Future<void> _deleteComment(String commentId) async {
    await _commentsProvider.deleteComment(_compositeKey, commentId);
  }

  Future<void> _voteOnComment(String commentId, bool isUpvote) async {
    await _commentsProvider.voteOnComment(_compositeKey, commentId, isUpvote);
  }

  Future<void> _voteOnProof(bool isUpvote) async {
    final user = _auth.currentUser;
    if (user == null || _isVoting) return;

    setState(() {
      _isVoting = true;
    });

    final voteDoc = _firestore
        .collection('leaderboardProofs')
        .doc(_compositeKey)
        .collection('votes')
        .doc('${user.uid}_proof');

    final proofsDataRef = _firestore
        .collection('leaderboardProofs')
        .doc(_compositeKey);

    // Get current vote state
    final doc = await voteDoc.get();
    final currentVote = doc.exists ? (doc.data()?['vote'] ?? 0) : 0;
    
    // Calculate new vote counts optimistically
    int newUpvotes = _localUpvotes;
    int newDownvotes = _localDownvotes;
    
    if (currentVote == (isUpvote ? 1 : -1)) {
      // Removing vote
      if (isUpvote) {
        newUpvotes = (_localUpvotes - 1).clamp(0, double.infinity).toInt();
      } else {
        newDownvotes = (_localDownvotes - 1).clamp(0, double.infinity).toInt();
      }
    } else if (currentVote == (isUpvote ? -1 : 1)) {
      // Changing vote
      if (isUpvote) {
        newUpvotes = _localUpvotes + 1;
        newDownvotes = (_localDownvotes - 1).clamp(0, double.infinity).toInt();
      } else {
        newDownvotes = _localDownvotes + 1;
        newUpvotes = (_localUpvotes - 1).clamp(0, double.infinity).toInt();
      }
    } else {
      // Adding new vote
      if (isUpvote) {
        newUpvotes = _localUpvotes + 1;
      } else {
        newDownvotes = _localDownvotes + 1;
      }
    }

    // Update UI immediately
    setState(() {
      _localUpvotes = newUpvotes;
      _localDownvotes = newDownvotes;
    });

    // Save to Firestore in background (don't await to block UI)
    _saveVoteToFirestore(voteDoc, proofsDataRef, currentVote, isUpvote).then((_) {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }).catchError((error) {
      // Revert on error
      if (mounted) {
        setState(() {
          _localUpvotes = _localUpvotes; // Will be refreshed from server
          _localDownvotes = _localDownvotes;
          _isVoting = false;
        });
        // Silently refresh to get correct values
        _refreshData();
      }
    });
  }

  Future<void> _saveVoteToFirestore(
    DocumentReference voteDoc,
    DocumentReference proofsDataRef,
    int currentVote,
    bool isUpvote,
  ) async {
    if (currentVote == (isUpvote ? 1 : -1)) {
      // Remove vote
      await voteDoc.delete();
      final currentData = await proofsDataRef.get();
      if (currentData.exists) {
        await proofsDataRef.update({
          isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(-1),
        });
      }
    } else {
      // Add or change vote
      await voteDoc.set({'vote': isUpvote ? 1 : -1});
      final currentData = await proofsDataRef.get();
      if (currentData.exists) {
        if (currentVote == (isUpvote ? -1 : 1)) {
          // Changing vote
          await proofsDataRef.update({
            'upvotes': FieldValue.increment(isUpvote ? 1 : -1),
            'downvotes': FieldValue.increment(isUpvote ? -1 : 1),
          });
        } else {
          // Adding new vote
          await proofsDataRef.update({
            isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(1),
          });
        }
      } else {
        await proofsDataRef.set({
          'upvotes': isUpvote ? 1 : 0,
          'downvotes': isUpvote ? 0 : 1,
        });
      }
    }
  }

  // MIGRATION_SUGGESTION: See cloud_migration/firebase_migration_plan_features.txt ID f_4d5e6f_features
  Future<void> _reportProof() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if user has already reported this proof
    final existingReport = await _firestore
        .collection('leaderboardProofs')
        .doc(_compositeKey)
        .collection('reports')
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'proof')
        .get();

    if (existingReport.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already reported this proof.'),
          backgroundColor: Color(0xFFf72585),
        ),
      );
      return;
    }

    _showReportDialog();
  }

  void _showReportDialog() {
    String selectedReason = 'Inappropriate content';
    final List<String> reportReasons = [
      'Inappropriate content',
      'Fake or misleading proof',
      'Violence or harmful content',
      'Spam or irrelevant content',
      'Copyright violation',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF101225).withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4361ee).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: (screenHeight * 0.7) - keyboardHeight,
              ),
              padding: EdgeInsets.only(
                left: 24.rw,
                right: 24.rw,
                top: 24.rh,
                bottom: 24.rh + keyboardHeight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Report Proof',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.6),
                        size: 24,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.rh),
                
                Text(
                  'Please select a reason for reporting this proof:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 16.rh),
                
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF121c36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      items: reportReasons.map((String reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 12.rh),
                            child: Text(
                              reason,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value!;
                        });
                      },
                      dropdownColor: Color(0xFF121c36),
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 16.rh),
              
              if (selectedReason == 'Other') ...[
                Text(
                  'Please provide additional details:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF121c36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _reportReasonController,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter additional details...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16.r),
                    ),
                    maxLines: 3,
                  ),
                ),
                SizedBox(height: 16.rh),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.rh),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.rw),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _submitReport(selectedReason);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.rh),
                        decoration: BoxDecoration(
                          color: Color(0xFFf72585),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Submit Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitReport(String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('leaderboardProofs')
          .doc(_compositeKey)
          .collection('reports')
          .add({
        'userId': user.uid,
        'type': 'proof',
        'reason': reason,
        'additionalDetails': _reportReasonController.text.isNotEmpty 
            ? _reportReasonController.text 
            : null,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _reportReasonController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Report submitted successfully. Thank you for helping keep our community safe.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF38b000),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Failed to submit report. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFFf72585),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _reportComment(String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if user has already reported this comment
    final existingReport = await _firestore
        .collection('leaderboardProofs')
        .doc(_compositeKey)
        .collection('reports')
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'comment')
        .where('commentId', isEqualTo: commentId)
        .get();

    if (existingReport.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already reported this comment.'),
          backgroundColor: Color(0xFFf72585),
        ),
      );
      return;
    }

    _showCommentReportDialog(commentId);
  }

  void _showCommentReportDialog(String commentId) {
    String selectedReason = 'Inappropriate content';
    final List<String> reportReasons = [
      'Inappropriate content',
      'Harassment or bullying',
      'Spam or irrelevant content',
      'False information',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF101225).withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4361ee).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: (screenHeight * 0.7) - keyboardHeight,
              ),
              padding: EdgeInsets.only(
                left: 24.rw,
                right: 24.rw,
                top: 24.rh,
                bottom: 24.rh + keyboardHeight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Report Comment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.6),
                        size: 24,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.rh),
                
                Text(
                  'Please select a reason for reporting this comment:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 16.rh),
                
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF121c36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      items: reportReasons.map((String reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 12.rh),
                            child: Text(
                              reason,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value!;
                        });
                      },
                      dropdownColor: Color(0xFF121c36),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.rh),
              
              if (selectedReason == 'Other') ...[
                Text(
                  'Please provide additional details:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF121c36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _reportReasonController,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter additional details...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16.r),
                    ),
                    maxLines: 3,
                  ),
                ),
                SizedBox(height: 16.rh),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.rh),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.rw),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _submitCommentReport(commentId, selectedReason);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.rh),
                        decoration: BoxDecoration(
                          color: Color(0xFFf72585),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Submit Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitCommentReport(String commentId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('leaderboardProofs')
          .doc(_compositeKey)
          .collection('reports')
          .add({
        'userId': user.uid,
        'type': 'comment',
        'commentId': commentId,
        'reason': reason,
        'additionalDetails': _reportReasonController.text.isNotEmpty 
            ? _reportReasonController.text 
            : null,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _reportReasonController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Comment report submitted successfully.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF38b000),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Failed to submit report. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFFf72585),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _commentsProvider,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background_1.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: FutureBuilder<DocumentSnapshot>(
              key: const ValueKey('leaderboard_entry'),
              future: _leaderboardEntryFuture,
              builder: (context, entrySnapshot) {
                if (entrySnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.all(32.r),
                      child: const CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                } else if (!entrySnapshot.hasData || !entrySnapshot.data!.exists) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.all(32.r),
                      child: Text(
                        'No leaderboard data found',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                  );
                } else {
                  // Get voting data from composite key storage
                  return FutureBuilder<DocumentSnapshot>(
                    key: const ValueKey('proofs_data'),
                    future: _proofsDataFuture,
                    builder: (context, proofsDataSnapshot) {
                      final proofsData = proofsDataSnapshot.hasData && proofsDataSnapshot.data!.exists 
                          ? proofsDataSnapshot.data!.data() as Map<String, dynamic>?
                          : null;
                      
                      // Initialize local state from server data on first load
                      if (proofsDataSnapshot.hasData && proofsDataSnapshot.connectionState == ConnectionState.done) {
                        final serverUpvotes = proofsData?['upvotes'] ?? 0;
                        final serverDownvotes = proofsData?['downvotes'] ?? 0;
                        
                        // Only update if local state hasn't been modified (i.e., still matches initial state or is 0)
                        if ((_localUpvotes == 0 && _localDownvotes == 0) || 
                            (_localUpvotes == serverUpvotes && _localDownvotes == serverDownvotes)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _localUpvotes = serverUpvotes;
                                _localDownvotes = serverDownvotes;
                              });
                            }
                          });
                        }
                      }
                      
                      // Use local state (which is updated optimistically) or fall back to server data
                      final upvotes = proofsDataSnapshot.hasData 
                          ? _localUpvotes 
                          : (proofsData?['upvotes'] ?? 0);
                      final downvotes = proofsDataSnapshot.hasData 
                          ? _localDownvotes 
                          : (proofsData?['downvotes'] ?? 0);

                      return FutureBuilder<QuerySnapshot>(
                        key: const ValueKey('proofs_list'),
                        future: _proofsFuture,
                        builder: (context, proofsSnapshot) {
                          if (proofsSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: Container(
                                padding: EdgeInsets.all(32.r),
                                child: const CircularProgressIndicator(color: Colors.white),
                              ),
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                              return SingleChildScrollView(
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.only(
                                  left: 24.rw,
                                  right: 24.rw,
                                  top: 24.rh,
                                  bottom: 24.rh + keyboardHeight,
                                ),
                                child: Column(
                                  children: [
                                    // App Bar
                                    _buildAppBar(),
                                    SizedBox(height: 24.rh),
                                    
                                    // Always show proof interface (with or without actual proof)
                                    if (proofsSnapshot.hasData && proofsSnapshot.data!.docs.isNotEmpty)
                                      // Video Proof Card
                                      _buildProofCard(proofsSnapshot.data!.docs.first, upvotes, downvotes)
                                    else
                                      // Placeholder Proof Card (no video but with voting/commenting)
                                      _buildPlaceholderProofCard(upvotes, downvotes),
                                    
                                    SizedBox(height: 16.rh),
                                    
                                    // Anonymous Disclaimer
                                    _buildAnonymousDisclaimer(),
                                    SizedBox(height: 32.rh),
                                    
                                    // Comments Section
                                    _buildCommentsSection(),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        SizedBox(width: 16.rw),
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Color(0xFF4895ef), Color(0xFF4cc9f0)],
            ).createShader(bounds),
            child: Text(
              'Player Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofCard(QueryDocumentSnapshot proof, int upvotes, int downvotes) {
    final proofData = proof.data() as Map<String, dynamic>?;
    final videoUrl = proofData?['proofVideoUrl']; // Only use Firebase Storage proofs
    final comment = proofData?['comment'];
    final proofStatus = proofData?['proofStatus'] ?? 'ready'; // Default to ready for legacy proofs
    
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF101225).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4361ee).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
                                      child: Column(
                                        children: [
          // Video Container
                                          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: _buildProofVideoWidget(videoUrl, proofStatus, proofData),
            ),
          ),
          
          // Proof Actions
          Container(
            padding: EdgeInsets.all(16.r),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                _buildVoteButton(
                  icon: Icons.thumb_up,
                  count: upvotes,
                                                  onPressed: () => _voteOnProof(true),
                  isActive: upvotes > 0,
                ),
                SizedBox(width: 24.rw),
                _buildVoteButton(
                  icon: Icons.thumb_down,
                  count: downvotes,
                                                  onPressed: () => _voteOnProof(false),
                  isActive: downvotes > 0,
                                                ),
                SizedBox(width: 24.rw),
                _buildReportButton(),
                                              ],
                                            ),
                                          ),
          
          // Proof Comment
          if (comment != null && comment.toString().isNotEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(16.rw, 0, 16.rw, 16.rh),
                                              child: Text(
                comment.toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
                                              ),
                                            ),
                                        ],
                                      ),
    );
  }

  Widget _buildPlaceholderProofCard(int upvotes, int downvotes) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF101225).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4361ee).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Placeholder Video Container
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  SizedBox(height: 12.rh),
                  Text(
                    'No Proof Video Available',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This user hasn\'t uploaded a proof video yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Proof Actions (same as normal proof)
          Container(
            padding: EdgeInsets.all(16.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildVoteButton(
                  icon: Icons.thumb_up,
                  count: upvotes,
                  onPressed: () => _voteOnProof(true),
                  isActive: upvotes > 0,
                ),
                SizedBox(width: 24.rw),
                _buildVoteButton(
                  icon: Icons.thumb_down,
                  count: downvotes,
                  onPressed: () => _voteOnProof(false),
                  isActive: downvotes > 0,
                ),
                SizedBox(width: 24.rw),
                _buildReportButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required int count,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: _isVoting ? null : onPressed,
      child: Opacity(
        opacity: _isVoting ? 0.6 : 1.0,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isVoting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isActive ? Color(0xFF38b000) : Colors.white,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  color: isActive ? Color(0xFF38b000) : Colors.white,
                  size: 20,
                ),
              SizedBox(width: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  color: isActive ? Color(0xFF38b000) : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportButton() {
    return GestureDetector(
      onTap: _reportProof,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 8),
                                      child: Row(
          mainAxisSize: MainAxisSize.min,
                                        children: [
            Icon(
              Icons.flag,
              color: Color(0xFFf72585),
              size: 20,
            ),
            SizedBox(width: 8),
                                          Text(
              'Report',
                                            style: TextStyle(
                color: Color(0xFFf72585),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
                                        ],
                                      ),
                                    ),
    );
  }

  Widget _buildAnonymousDisclaimer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.rw),
      child: Text(
        'All comments are anonymous to ensure unbiased and honest feedback.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
        // Section Header
        Row(
          children: [
            Text(
              'Comments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.comment,
              color: Color(0xFF4895ef),
              size: 20,
                                              ),
                                            ],
                                          ),
        SizedBox(height: 16.rh),
        
        // Add Comment
        _buildAddComment(),
        SizedBox(height: 16.rh),

                                    // Comments List
                                    Consumer<CommentsProvider>(
                                      builder: (context, commentsProvider, child) {
                                        final topLevelComments = commentsProvider.comments
                                            .where((doc) => doc['parentId'] == null)
                                            .toList();

                                        return ListView.separated(
                                          separatorBuilder: (_, __) => SizedBox(height: 12.rh),
                                          shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
                                          itemCount: topLevelComments.length,
                                          itemBuilder: (context, index) {
                                            final comment = topLevelComments[index];
                                            final commentId = comment.id;
                                            final replies = commentsProvider.comments
                                                .where((doc) => doc['parentId'] == commentId)
                                                .toList();

                                            final isExpanded = _expandedComments.contains(commentId);
                                            final visibleReplies = isExpanded ? replies : replies.take(2).toList();

                                            return _buildComment(
                                              comment,
                                              visibleReplies,
                                              commentsProvider.comments,
                                              context,
                                              0,
                                              isExpanded,
                                              replies.length,
                                              () {
                                                setState(() {
                                                  if (isExpanded) {
                                                    _expandedComments.remove(commentId);
                                                  } else {
                                                    _expandedComments.add(commentId);
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
    );
  }

  Widget _buildAddComment() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF101225).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(16.r),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _addComment,
            child: Container(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.send,
                color: Color(0xFF4895ef),
                size: 20,
              ),
                              ),
                            ),
                        ],
      ),
    );
  }


  Widget _buildComment(
    QueryDocumentSnapshot comment,
    List<QueryDocumentSnapshot> replies,
    List<QueryDocumentSnapshot> allComments,
    BuildContext context,
    int currentDepth,
    bool isExpanded,
    int totalReplies,
    VoidCallback onToggleReplies,
  ) {
    final commentId = comment.id;
    final commentText = comment['text'];
    final upvotes = comment['upvotes'] ?? 0;
    final downvotes = comment['downvotes'] ?? 0;
    final isReplying = _replyingToCommentId == commentId;
    final isCommentOwner = comment['userId'] == _auth.currentUser?.uid;

    return Container(
      margin: EdgeInsets.only(bottom: 16.rh),
      child: Column(
        children: [
          // Main Comment Card
          Container(
            margin: EdgeInsets.only(left: (currentDepth * 12.0).rw),
            decoration: BoxDecoration(
              color: Color(0xFF101225).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
        child: Padding(
              padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Comment text
              Text(
                commentText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.5,
              ),
                  ),
                  SizedBox(height: 16.rh),

                  // Comment actions
              Row(
                children: [
                      // Upvote
                      _buildCommentVoteButton(
                    icon: Icons.arrow_upward,
                    count: upvotes,
                    onPressed: () => _voteOnComment(commentId, true),
                    isActive: upvotes > 0,
                  ),
                      SizedBox(width: 16.rw),

                      // Downvote
                      _buildCommentVoteButton(
                    icon: Icons.arrow_downward,
                    count: downvotes,
                    onPressed: () => _voteOnComment(commentId, false),
                    isActive: downvotes > 0,
                  ),
                      SizedBox(width: 16.rw),

                      // Reply button
                  if (currentDepth < _maxReplyDepth)
                        GestureDetector(
                          onTap: () {
                        setState(() {
                          _replyingToCommentId = commentId;
                        });
                      },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply,
                                color: Color(0xFF4895ef),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  color: Color(0xFF4895ef),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      Spacer(),

                      // Delete button
                  if (isCommentOwner)
                        GestureDetector(
                          onTap: () => _deleteComment(commentId),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete,
                                color: Color(0xFFf72585),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Color(0xFFf72585),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Report button (show for all comments except user's own)
                      if (!isCommentOwner) ...[
                        SizedBox(width: 16.rw),
                        GestureDetector(
                          onTap: () => _reportComment(commentId),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag,
                                color: Color(0xFFf72585),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Report',
                                style: TextStyle(
                                  color: Color(0xFFf72585),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Reply input field
              if (isReplying && currentDepth < _maxReplyDepth)
                    Container(
                      margin: EdgeInsets.only(top: 16.rh),
                      decoration: BoxDecoration(
                        color: Color(0xFF121c36),
                      borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      padding: EdgeInsets.all(12.r),
                      child: Column(
                        children: [
                          TextField(
                              controller: _replyController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                              decoration: InputDecoration(
                                hintText: 'Write a reply...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                                border: InputBorder.none,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _replyingToCommentId = null;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.6),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _addReply(commentId),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF4361ee),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Reply',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                        ],
                      ),
                    ),
                ],
                    ),
                  ),
                ),

              // Nested replies
              if (replies.isNotEmpty && currentDepth < _maxReplyDepth)
            Container(
              margin: EdgeInsets.only(left: 8),
              child: Column(
                  children: replies.map((reply) {
                    final replyReplies = allComments
                        .where((doc) => doc['parentId'] == reply.id)
                        .toList();
                    return _buildComment(
                      reply,
                      replyReplies,
                      allComments,
                      context,
                      currentDepth + 1,
                      true,
                      replyReplies.length,
                      () {},
                    );
                  }).toList(),
              ),
                ),
          if (totalReplies > replies.length && currentDepth < _maxReplyDepth)
            GestureDetector(
              onTap: onToggleReplies,
              child: Container(
                margin: const EdgeInsets.only(left: 8, top: 8),
                padding: EdgeInsets.symmetric(horizontal: 12.rw, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExpanded
                          ? 'Hide replies'
                          : 'View remaining replies ($totalReplies)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
      ),
    );
  }

  /// Builds the appropriate widget based on proof status
  Widget _buildProofVideoWidget(String? videoUrl, String proofStatus, Map<String, dynamic>? proofData) {
    switch (proofStatus) {
      case 'uploading':
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF4361ee),
                  strokeWidth: 2,
                ),
                SizedBox(height: 12.rh),
                const Text(
                  'Uploading video...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      case 'processing':
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF4361ee),
                  strokeWidth: 2,
                ),
                SizedBox(height: 12.rh),
                const Text(
                  'Optimizing video...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This may take a few minutes',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      case 'failed':
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                SizedBox(height: 12.rh),
                const Text(
                  'Processing failed',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (proofData?['errorMessage'] != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.rw),
                    child: Text(
                      proofData!['errorMessage'],
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case 'ready':
      default:
        // Show video if ready or for legacy proofs (no status field)
        if (videoUrl != null && videoUrl.isNotEmpty) {
          return YTVideoWidget(videoUrl: videoUrl);
        } else {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videocam_off,
                    color: Colors.white38,
                    size: 48,
                  ),
                  SizedBox(height: 12.rh),
                  const Text(
                    'Video not available',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    }
  }

  Widget _buildCommentVoteButton({
    required IconData icon,
    required int count,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
        icon,
            color: isActive ? Color(0xFF4895ef) : Colors.white.withOpacity(0.6),
            size: 16,
      ),
          SizedBox(width: 4),
          Text(
        count.toString(),
        style: TextStyle(
              color: isActive ? Color(0xFF4895ef) : Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }


}