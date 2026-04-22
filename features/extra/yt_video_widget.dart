// yt_video_widget.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'constants.dart';

class YTVideoWidget extends StatefulWidget {
  final String? videoUrl;

  const YTVideoWidget({super.key, this.videoUrl});

  @override
  _YTVideoWidgetState createState() => _YTVideoWidgetState();
}

class _YTVideoWidgetState extends State<YTVideoWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  InAppWebViewController? _webViewController;
  bool _isVideoInitialized = false;
  bool _isYoutube = false;
  String? _youtubeId;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;
  double _currentRate = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      setState(() => _isVideoInitialized = true);
      return;
    }

    // Check for YouTube URL
    final youtubeRegex = RegExp(
      r'^.*(youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
    );
    final youtubeMatch = youtubeRegex.firstMatch(widget.videoUrl!);

    if (youtubeMatch != null && youtubeMatch.group(2) != null) {
      final youtubeId = youtubeMatch.group(2);
      if (youtubeId != null && youtubeId.length == 11) {
        setState(() {
          _isYoutube = true;
          _youtubeId = youtubeId;
          _isVideoInitialized = true;
        });
        return;
      }
    }

    // Regular video (Firebase Storage or other direct video URLs)
    try {
      _videoController = VideoPlayerController.network(widget.videoUrl!)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoController!,
                autoPlay: false,
                looping: false,
                allowFullScreen: true,
                allowMuting: true,
                showControls: true,
                errorBuilder: (context, errorMessage) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white70,
                          size: 48,
                        ),
                        SizedBox(height: 12.rh),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              );
              _isVideoInitialized = true;
            });
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Failed to load video: ${error.toString()}';
              _isVideoInitialized = true;
            });
          }
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize video player: ${e.toString()}';
          _isVideoInitialized = true;
        });
      }
    }
  }

  bool _playerReady = false;

  Future<void> _executeJS(String script) async {
    if (_webViewController != null && _playerReady) {
      try {
        await _webViewController!.evaluateJavascript(source: script);
      } catch (e) {
        print('JS execution error: $e');
      }
    }
  }

  Future<void> _playPause() async {
    if (!_playerReady) return;
    if (_isPlaying) {
      await _executeJS('if (window.pauseVideo) window.pauseVideo();');
    } else {
      await _executeJS('if (window.playVideo) window.playVideo();');
    }
  }

  Future<void> _seekBy(int seconds) async {
    if (!_playerReady) return;
    await _executeJS('if (window.seekBy) window.seekBy($seconds);');
  }

  Future<void> _setPlaybackRate(double rate) async {
    if (!_playerReady) return;
    await _executeJS('if (window.setPlaybackRate) window.setPlaybackRate($rate);');
    setState(() => _currentRate = rate);
  }

  String _getYouTubeEmbedHtml(String videoId) {
    // Use a valid origin for YouTube embed (required for enablejsapi)
    // Using a generic origin that works for mobile apps
    final origin = 'https://localhost';
    
    final embedUrl = 'https://www.youtube-nocookie.com/embed/$videoId?'
        'playsinline=1&'
        'controls=1&'
        'modestbranding=1&'
        'rel=0&'
        'fs=1&'
        'cc_load_policy=0&'
        'iv_load_policy=3&'
        'enablejsapi=1&'
        'origin=$origin&'
        'widget_referrer=$origin';
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <meta name="referrer" content="no-referrer-when-downgrade">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #000;
    }
    #player-container {
      width: 100%;
      height: 100%;
      position: relative;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: none;
    }
  </style>
</head>
<body>
  <div id="player-container">
    <iframe
      id="ytplayer"
      src="$embedUrl"
      frameborder="0"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen
      referrerpolicy="no-referrer-when-downgrade"
    ></iframe>
  </div>
  <script>
    var iframe = document.getElementById('ytplayer');
    var playerReady = false;
    var isPlaying = false;
    
    // Listen for messages from YouTube iframe
    window.addEventListener('message', function(event) {
      // YouTube sends messages from youtube.com or youtube-nocookie.com
      if (event.origin.indexOf('youtube') === -1) return;
      
      try {
        var data = JSON.parse(event.data);
        
        if (data.event === 'onReady') {
          playerReady = true;
          window.flutter_inappwebview.callHandler('onPlayerReady');
        } else if (data.event === 'onStateChange') {
          isPlaying = data.info === 1; // 1 = playing
          window.flutter_inappwebview.callHandler('onPlayerStateChange', isPlaying);
        } else if (data.event === 'onError') {
          window.flutter_inappwebview.callHandler('onPlayerError', data.info);
        }
      } catch (e) {
        // Ignore non-JSON messages
      }
    });
    
    // Functions to control player via postMessage
    window.playVideo = function() {
      iframe.contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
    };
    
    window.pauseVideo = function() {
      iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
    };
    
    var currentTime = 0;
    
    // Update current time from player messages
    window.addEventListener('message', function(event) {
      if (event.origin.indexOf('youtube') === -1) return;
      try {
        var data = JSON.parse(event.data);
        if (data.info && typeof data.info === 'number') {
          currentTime = data.info;
        }
      } catch (e) {}
    });
    
    window.seekBy = function(seconds) {
      // Request current time first
      iframe.contentWindow.postMessage('{"event":"command","func":"getCurrentTime","args":""}', '*');
      // Then seek after a short delay
      setTimeout(function() {
        var newTime = Math.max(0, currentTime + seconds);
        iframe.contentWindow.postMessage('{"event":"command","func":"seekTo","args":[' + newTime + ',true]}', '*');
      }, 200);
    };
    
    window.setPlaybackRate = function(rate) {
      iframe.contentWindow.postMessage('{"event":"command","func":"setPlaybackRate","args":[' + rate + ']}', '*');
    };
    
    // Mark as ready after a short delay (iframe loads)
    setTimeout(function() {
      if (!playerReady) {
        playerReady = true;
        window.flutter_inappwebview.callHandler('onPlayerReady');
      }
    }, 2000);
  </script>
</body>
</html>
    ''';
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVideoInitialized) {
      return Container(
        height: 200,
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey[300],
        child: const Center(child: Text('No video available')),
      );
    }

    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white70,
                size: 48,
              ),
              SizedBox(height: 12.rh),
              Text(
                _errorMessage ?? 'Unable to load video',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_isYoutube && _youtubeId != null) {
      return SizedBox(
        height: 280,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: _getYouTubeEmbedHtml(_youtubeId!),
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    iframeAllow: "camera; microphone; fullscreen",
                    useHybridComposition: true,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'onPlayerReady',
                      callback: (args) {
                        if (mounted) {
                          setState(() {
                            _playerReady = true;
                          });
                        }
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: 'onPlayerStateChange',
                      callback: (args) {
                        if (mounted) {
                          setState(() {
                            _isPlaying = args[0] ?? false;
                          });
                        }
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: 'onPlayerError',
                      callback: (args) {
                        if (mounted) {
                          final errorCode = args.isNotEmpty ? args[0] : null;
                          setState(() {
                            _hasError = true;
                            _errorMessage = 'YouTube error: $errorCode. Video may be restricted or unavailable.';
                            _playerReady = false;
                          });
                        }
                      },
                    );
                  },
                  onLoadError: (controller, url, code, message) {
                    setState(() {
                      _hasError = true;
                      _errorMessage = 'Failed to load video: $message';
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildYoutubeControls(),
          ],
        ),
      );
    }

    if (_chewieController != null) {
      return SizedBox(
        height: 200,
        child: Chewie(controller: _chewieController!),
      );
    }

    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Center(child: Text('Video not supported')),
    );
  }

  Widget _buildYoutubeControls() {
    const rates = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: _playerReady ? () => _seekBy(-10) : null,
            tooltip: 'Rewind 10s',
          ),
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: _playerReady ? Colors.white : Colors.white54,
              size: 32,
            ),
            onPressed: _playerReady ? _playPause : null,
            tooltip: _isPlaying ? 'Pause' : 'Play',
          ),
          IconButton(
            icon: const Icon(Icons.forward_10, color: Colors.white),
            onPressed: _playerReady ? () => _seekBy(10) : null,
            tooltip: 'Forward 10s',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<double>(
              dropdownColor: Colors.black87,
              value: _currentRate,
              icon: const Icon(Icons.speed, color: Colors.white, size: 20),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: rates
                  .map(
                    (r) => DropdownMenuItem<double>(
                      value: r,
                      child: Text(
                        '${r}x',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _playerReady
                  ? (r) {
                      if (r != null) _setPlaybackRate(r);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentWidget extends StatelessWidget {
  final String comment;

  const CommentWidget({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text('Comment: $comment'),
    );
  }
}
