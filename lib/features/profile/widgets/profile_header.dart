import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:gridcard/config/app_config.dart';
import 'dart:async';

class ProfileHeader extends StatefulWidget {
  final String? coverUrl;
  final String? profilePicUrl;
  final String? videoUrl;
  final String name;
  final String? designation;
  final String? department;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  const ProfileHeader({
    super.key,
    this.coverUrl,
    this.profilePicUrl,
    this.videoUrl,
    required this.name,
    this.designation,
    this.department,
    this.onBack,
    this.onEdit,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showVideo = false;
  bool _isVideoInitStarted = false;
  bool _isCoverVisible = false;

  @override
  void initState() {
    super.initState();
    // Init lazily on visibility; we still prewarm if URL exists.
    if ((widget.videoUrl ?? '').trim().isNotEmpty) _initVideo();
  }

  @override
  void didUpdateWidget(covariant ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = (oldWidget.videoUrl ?? '').trim();
    final newUrl = (widget.videoUrl ?? '').trim();
    if (oldUrl != newUrl) {
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
      _showVideo = false;
      _isVideoInitStarted = false;
      if (newUrl.isNotEmpty) {
        _initVideo();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (_isVideoInitStarted) return;
    _isVideoInitStarted = true;

    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    try {
      final finalUrl = AppConfig.getFullUrl(widget.videoUrl);
      if (finalUrl == null) return;

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse("$finalUrl?t=${DateTime.now().millisecondsSinceEpoch}"),
      );

      await _videoController!.initialize();
      if (!mounted) return;

      _videoController!.setLooping(true);
      _videoController!.setVolume(0);

      setState(() {
        _isVideoInitialized = true;
        _showVideo = true;
      });

      if (_isCoverVisible) {
        _videoController?.play();
      }
    } catch (e) {
      debugPrint("ProfileHeader: Video error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Section
        ClipPath(
          clipper: ConcaveClipper(),
          child: _buildCover(context),
        ),

        // Profile Image Section with Status Indicator
        Positioned(
          bottom: -45,
          left: 0,
          right: 0,
          child: Center(
            child: Stack(
              children: [
                _buildProfileImage(context),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Navigation (Back) Button
        if (widget.onBack != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.black, size: 18),
                onPressed: widget.onBack,
              ),
            ),
          ),

        // Edit Button
        if (widget.onEdit != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 15,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon:
                    const Icon(Icons.more_vert, color: Colors.black, size: 22),
                onPressed: widget.onEdit,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCover(BuildContext context) {
    return VisibilityDetector(
      key: const Key('profile-cover-video'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.5;
        _isCoverVisible = visible;
        if (visible) {
          if (!_isVideoInitStarted &&
              (widget.videoUrl ?? '').trim().isNotEmpty) {
            _initVideo();
          } else if (_showVideo &&
              _isVideoInitialized &&
              _videoController != null &&
              !_videoController!.value.isPlaying) {
            _videoController?.play();
          }
        } else {
          if (_videoController != null && _videoController!.value.isPlaying) {
            _videoController?.pause();
          }
        }
      },
      child: Container(
        height: 450,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[300],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder image (shown until video is ready)
            AppNetworkImage(
              imageUrl: widget.coverUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
            if (_showVideo && _isVideoInitialized && _videoController != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outerShadow = isDark ? Colors.black54 : Colors.black12;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8E7A1),
            Color(0xFFD4AF37),
            Color(0xFFB8860B),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: outerShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        width: 105,
        height: 105,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: AppNetworkImage(
          imageUrl: widget.profilePicUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class ConcaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height);
    path.quadraticBezierTo(
        size.width / 2, size.height - 45, size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
