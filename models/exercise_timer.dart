/// Timer for tracking exercise workout time modes (normal, rest, pause).
class ExerciseTimer {
  int normalTime = 0;
  int restTime = 0;
  int pauseTime = 0;
  DateTime? normalStartTime;
  DateTime? restStartTime;
  DateTime? pauseStartTime;
  String currentMode = 'none'; // 'none', 'normal', 'rest', 'pause'

  void startNormal() {
    if (currentMode != 'normal') {
      stopCurrent();
      currentMode = 'normal';
      normalStartTime = DateTime.now();
    }
  }

  void startRest() {
    if (currentMode != 'rest') {
      stopCurrent();
      currentMode = 'rest';
      restStartTime = DateTime.now();
    }
  }

  void startPause() {
    if (currentMode != 'pause') {
      stopCurrent();
      currentMode = 'pause';
      pauseStartTime = DateTime.now();
    }
  }

  void stopCurrent() {
    final now = DateTime.now();
    if (currentMode == 'normal' && normalStartTime != null) {
      normalTime += now.difference(normalStartTime!).inSeconds;
      normalStartTime = null;
    } else if (currentMode == 'rest' && restStartTime != null) {
      restTime += now.difference(restStartTime!).inSeconds;
      restStartTime = null;
    } else if (currentMode == 'pause' && pauseStartTime != null) {
      pauseTime += now.difference(pauseStartTime!).inSeconds;
      pauseStartTime = null;
    }
    currentMode = 'none';
  }

  /// Resume the timer from its current mode (used when loading from saved state)
  void resumeFromSavedState() {
    if (currentMode == 'normal') {
      startNormal();
    } else if (currentMode == 'rest') {
      startRest();
    } else if (currentMode == 'pause') {
      startPause();
    }
  }

  String getCurrentNormalTime() {
    int total = normalTime;
    if (currentMode == 'normal' && normalStartTime != null) {
      total += DateTime.now().difference(normalStartTime!).inSeconds;
    }
    return _formatTime(total);
  }

  String getCurrentRestTime() {
    int total = restTime;
    if (currentMode == 'rest' && restStartTime != null) {
      total += DateTime.now().difference(restStartTime!).inSeconds;
    }
    return _formatTime(total);
  }

  String getCurrentPauseTime() {
    int total = pauseTime;
    if (currentMode == 'pause' && pauseStartTime != null) {
      total += DateTime.now().difference(pauseStartTime!).inSeconds;
    }
    return _formatTime(total);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
