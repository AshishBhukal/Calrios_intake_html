/// Service for building versioned storage paths for proof videos
class ProofVersionService {
  /// Build the raw storage path for a proof video
  /// Format: proofs/raw/{userId}/{entryId}/{versionId}.mp4
  static String buildRawPath(String userId, String entryId, String versionId) {
    return 'proofs/raw/$userId/$entryId/$versionId.mp4';
  }

  /// Build the optimized storage path for a proof video
  /// Format: proofs/optimized/{userId}/{entryId}/{versionId}.mp4
  static String buildOptimizedPath(String userId, String entryId, String versionId) {
    return 'proofs/optimized/$userId/$entryId/$versionId.mp4';
  }
}

