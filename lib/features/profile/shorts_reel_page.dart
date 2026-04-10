import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ShortsReelPage extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;

  const ShortsReelPage({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<ShortsReelPage> createState() => _ShortsReelPageState();
}

class _ShortsReelPageState extends State<ShortsReelPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: widget.videos.length,
            itemBuilder: (context, index) {
              return ShortsPlayerItem(
                video: widget.videos[index],
              );
            },
          ),
          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.3),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShortsPlayerItem extends StatefulWidget {
  final Map<String, dynamic> video;

  const ShortsPlayerItem({
    super.key,
    required this.video,
  });

  @override
  State<ShortsPlayerItem> createState() => _ShortsPlayerItemState();
}

class _ShortsPlayerItemState extends State<ShortsPlayerItem> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    final videoUrl = (widget.video['video_url'] ?? widget.video['url'] ?? '').toString();
    final videoId = YoutubePlayer.convertUrlToId(videoUrl) ?? '';
    debugPrint('[SHORTS] Native Player Loading ID: $videoId');

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
        isLive: false,
        forceHD: false,
        enableCaption: false,
        hideControls: true, // Immersive experience
      ),
    )..addListener(_onPlayerStateChange);
  }

  void _onPlayerStateChange() {
    if (mounted && _controller.value.isReady && !_isPlayerReady) {
      setState(() => _isPlayerReady = true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key((widget.video['video_url'] ?? widget.video['url']).toString()),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0.5) {
          if (_controller.value.isReady) {
            _controller.play();
          }
        } else {
          if (_controller.value.isReady) {
            _controller.pause();
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: YoutubePlayer(
              controller: _controller,
              aspectRatio: 9 / 16, // Force Portrait Aspect Ratio
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              onReady: () {
                debugPrint('[SHORTS] Native Player Ready');
              },
            ),
          ),
          
          // Immersive Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                    ],
                    stops: const [0.0, 0.25, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),
          
          // Video Info
          Positioned(
            bottom: 40,
            left: 20,
            right: 80,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.video['title']?.toString() ?? 'Short Video',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 10, color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Swipe up for more',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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
}
