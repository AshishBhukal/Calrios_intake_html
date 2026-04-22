import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitness2/features/extra/yt_video_widget.dart';
import 'package:fitness2/services/proof_state_manager.dart';
import 'package:fitness2/services/proof_version_service.dart';
import 'dart:io';
import 'constants.dart';

class AddProofScreen extends StatefulWidget {
  final String compositeKey;

  const AddProofScreen({super.key, required this.compositeKey});

  @override
  _AddProofScreenState createState() => _AddProofScreenState();
}

class _AddProofScreenState extends State<AddProofScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  XFile? _selectedVideo;
  String? _currentVideoUrl;
  bool _isVideoLoaded = false;
  double _uploadProgress = 0.0;
  UploadTask? _currentUploadTask;
  String? _currentEntryId;
  String? _currentVersionId;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Pick video from gallery or camera
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // Max 10 minutes
      );

      if (video != null) {
        // Check file size (soft limit: 100MB)
        final file = File(video.path);
        final fileSize = await file.length();
        const maxSize = 100 * 1024 * 1024; // 100MB

        if (fileSize > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video file is too large. Maximum size is 100MB.'),
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedVideo = video;
          _currentVideoUrl = video.path;
          _isVideoLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: ${e.toString()}')),
        );
      }
    }
  }

  // Record video using camera
  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10), // Max 10 minutes
      );

      if (video != null) {
        setState(() {
          _selectedVideo = video;
          _currentVideoUrl = video.path;
          _isVideoLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording video: ${e.toString()}')),
        );
      }
    }
  }

  // Upload video proof to Firebase Storage (Versioned System)
  Future<void> _uploadProof() async {
    if (_isUploading || _selectedVideo == null) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add proof')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final comment = _commentController.text.trim();
    final userId = user.uid;
    String? entryId;
    String? versionId;

    try {
      // Step 1: Get or create proof entry
      final proofsRef = _firestore
          .collection('leaderboardProofs')
          .doc(widget.compositeKey)
          .collection('proofs');

      final existingProofQuery = await proofsRef
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingProofQuery.docs.isNotEmpty) {
        entryId = existingProofQuery.docs.first.id;
      } else {
        // Create new proof document with proofStatus to satisfy Firestore rules
        // The rules require either a video URL OR proofStatus to be present (line 320)
        // We'll set a temporary proofStatus, then initializeProofUpload will set the proper one
        final newDoc = await proofsRef.add({
          'userId': userId,
          'comment': comment,
          'timestamp': FieldValue.serverTimestamp(),
          'upvotes': 0,
          'downvotes': 0,
          'proofStatus': 'uploading', // Required by Firestore rules
        });
        entryId = newDoc.id;
      }

      // Step 2: Initialize proof upload (generates version ID and sets state to "uploading")
      // This will update the document with all required state machine fields
      versionId = await ProofStateManager.initializeProofUpload(
        widget.compositeKey,
        entryId,
      );

      // Step 3: Validate video file
      final videoFile = File(_selectedVideo!.path);
      
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }
      
      final fileSize = await videoFile.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }
      
      const maxSize = 100 * 1024 * 1024; // 100MB
      if (fileSize > maxSize) {
        throw Exception('Video file is too large. Maximum size is 100MB.');
      }

      // Step 4: Build versioned storage path
      final rawPath = ProofVersionService.buildRawPath(userId, entryId, versionId);
      debugPrint('Uploading to path: $rawPath');
      debugPrint('User ID: $userId');
      debugPrint('Entry ID: $entryId');
      debugPrint('Version ID: $versionId');
      final storageRef = _storage.ref().child(rawPath);

      // Step 5: Create upload task with version metadata
      UploadTask uploadTask;
      try {
        uploadTask = storageRef.putFile(
          videoFile,
          SettableMetadata(
            contentType: 'video/mp4',
            customMetadata: {
              'userId': userId,
              'entryId': entryId,
              'compositeKey': widget.compositeKey,
              'versionId': versionId, // CRITICAL: Include version ID for function validation
            },
          ),
        );
        // Store upload task and entry info for cancellation
        _currentUploadTask = uploadTask;
        _currentEntryId = entryId;
        _currentVersionId = versionId;
      } catch (e) {
        throw Exception('Failed to create upload task: ${e.toString()}');
      }

      // Step 6: Track upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (mounted) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
        onError: (error) {
          debugPrint('Upload progress error: $error');
        },
      );

      // Step 7: Wait for upload to complete with timeout (30 minutes for large files)
      try {
        await uploadTask.timeout(
          const Duration(minutes: 30),
          onTimeout: () {
            throw Exception('Upload timeout. Please check your internet connection and try again.');
          },
        );
      } catch (e) {
        final snapshot = uploadTask.snapshot;
        if (snapshot.state == TaskState.error) {
          throw Exception('Upload failed: ${e.toString()}');
        }
        rethrow;
      }

      // Step 8: Verify upload completed successfully
      final snapshot = uploadTask.snapshot;
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload did not complete successfully. State: ${snapshot.state}');
      }

      // Step 9: Update Firestore with rawPath
      // Cloud Function will detect the upload and update state to "processing", then "ready"
      await ProofStateManager.updateRawPath(
        widget.compositeKey,
        entryId,
        rawPath,
      );

      // Step 10: Update comment if provided
      if (comment.isNotEmpty) {
        await proofsRef.doc(entryId).update({
          'comment': comment,
        });
      }

      // Clear upload task reference
      _currentUploadTask = null;
      _currentEntryId = null;
      _currentVersionId = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof uploaded successfully! Video is being processed...'),
          ),
        );
        Navigator.pop(context); // Go back to the previous screen
      }
    } catch (e) {
      debugPrint('Upload error details: $e');
      if (mounted) {
        // Clean up: Cancel the upload state if it was initialized
        if (entryId != null) {
          try {
            await ProofStateManager.cancelProofUpload(
              widget.compositeKey,
              entryId,
            );
          } catch (cancelError) {
            debugPrint('Error canceling proof upload: $cancelError');
          }
        }
        
        String errorMessage = 'Failed to upload proof';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Upload timeout. Please check your internet connection and try again.';
        } else if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
          errorMessage = 'Permission denied. Please check your account permissions.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
        } else {
          errorMessage = 'Failed to upload proof: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // Cancel ongoing upload
  Future<void> _cancelUpload() async {
    if (!_isUploading || _currentUploadTask == null) return;

    try {
      // Cancel the upload task
      await _currentUploadTask!.cancel();
      
      // Clean up Firestore state if entry was created
      if (_currentEntryId != null) {
        try {
          await ProofStateManager.cancelProofUpload(
            widget.compositeKey,
            _currentEntryId!,
          );
        } catch (e) {
          debugPrint('Error canceling proof state: $e');
        }
      }

      // Delete the partial upload from Storage if it exists
      if (_currentEntryId != null && _currentVersionId != null) {
        try {
          final userId = _auth.currentUser?.uid;
          if (userId != null) {
            final rawPath = ProofVersionService.buildRawPath(
              userId,
              _currentEntryId!,
              _currentVersionId!,
            );
            await _storage.ref().child(rawPath).delete();
          }
        } catch (e) {
          debugPrint('Error deleting partial upload: $e');
          // Ignore errors - file may not exist yet
        }
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _currentUploadTask = null;
          _currentEntryId = null;
          _currentVersionId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error canceling upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error canceling upload: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          top: false, // Allow content behind Dynamic Island
          child: Padding(
            padding: EdgeInsets.only(top: topPadding), // Minimal padding for status bar
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24.rw,
                right: 24.rw,
                top: 24.rh,
                bottom: 24.rh + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  // Professional App Bar
                  _buildProfessionalAppBar(),
                  SizedBox(height: 32.rh),
                  
                  // Video Upload Card
                  _buildVideoCard(),
                  SizedBox(height: 20.rh),
                  
                  // Comment Card
                  _buildCommentCard(),
                  SizedBox(height: 32.rh),
                  
                  // Upload Button
                  _buildUploadButton(),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalAppBar() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 16.rw),
          Expanded(
            child: Text(
              'Upload Proof',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Text(
                'Video Proof',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showInfoDialog(),
                child: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline,
                    color: Color(0xFF4895ef),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          
          // Video Selection Buttons
          Row(
            children: [
              Expanded(
                child: _buildVideoButton(
                  icon: Icons.video_library,
                  label: 'Choose Video',
                  onTap: _pickVideo,
                ),
              ),
              SizedBox(width: 12.rw),
              Expanded(
                child: _buildVideoButton(
                  icon: Icons.videocam,
                  label: 'Record Video',
                  onTap: _recordVideo,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          
          // Upload Progress
          if (_isUploading) ...[
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4895ef)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: _cancelUpload,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 8),
                      minimumSize: Size(0, 0),
                    ),
                    child: Text(
                      'Cancel Upload',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.rh),
          ],
          
          // Video Preview
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: _isVideoLoaded && _currentVideoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        YTVideoWidget(videoUrl: _currentVideoUrl),
                        if (_selectedVideo != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedVideo = null;
                                  _currentVideoUrl = null;
                                  _isVideoLoaded = false;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_filled,
                          size: 48,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Select or record a video',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Max 10 minutes, 100MB',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
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

  Widget _buildVideoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.rh, horizontal: 12.rw),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add a Comment (Optional)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.rh),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.rw, vertical: 16.rh),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _commentController,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your comment here',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4361ee), Color(0xFF3a0ca3)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_isUploading || _selectedVideo == null) ? null : _uploadProof,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.rw),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isUploading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12.rw),
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.cloud_upload,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _selectedVideo == null ? 'Select Video First' : 'Upload Proof',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'How to Add Proof',
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
              Container(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    '1. Select or record a video proof (max 10 minutes)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  Text(
                    '2. Video will be automatically compressed for storage',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  Text(
                    '3. Add an optional comment',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  Text(
                    '4. Upload your proof',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 12.rh),
                  Text(
                    'Your video will be processed and compressed automatically. Maximum file size is 100MB.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  ],
                ),
              ),
              SizedBox(height: 16.rh),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.rw, vertical: 12.rh),
                    decoration: BoxDecoration(
                      color: Color(0xFF4361ee),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
