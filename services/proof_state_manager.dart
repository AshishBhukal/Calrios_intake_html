import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages the state machine for proof uploads
/// 
/// States: uploading -> processing -> ready/failed
class ProofStateManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize a proof upload by generating a version ID and setting state to "uploading"
  /// Returns the generated version ID
  static Future<String> initializeProofUpload(
    String compositeKey,
    String entryId,
  ) async {
    // Generate a unique version ID (timestamp-based UUID)
    final versionId = DateTime.now().millisecondsSinceEpoch.toString() +
        '_' +
        entryId.substring(0, 8);

    final proofRef = _firestore
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('proofs')
        .doc(entryId);

    // Update with version ID and state
    await proofRef.update({
      'proofVersionId': versionId,
      'proofStatus': 'uploading',
      'uploadStartedAt': FieldValue.serverTimestamp(),
    });

    return versionId;
  }

  /// Update the rawPath field after upload completes
  static Future<void> updateRawPath(
    String compositeKey,
    String entryId,
    String rawPath,
  ) async {
    final proofRef = _firestore
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('proofs')
        .doc(entryId);

    await proofRef.update({
      'rawPath': rawPath,
    });
  }

  /// Cancel a proof upload and clean up state
  static Future<void> cancelProofUpload(
    String compositeKey,
    String entryId,
  ) async {
    final proofRef = _firestore
        .collection('leaderboardProofs')
        .doc(compositeKey)
        .collection('proofs')
        .doc(entryId);

    // Update status to cancelled
    await proofRef.update({
      'proofStatus': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}

