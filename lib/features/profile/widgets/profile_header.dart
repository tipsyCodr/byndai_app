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
        _buildCover(context),

        // Profile Image Section
        Positioned(
          bottom: -50,
          left: 0,
          right: 0,
          child: Center(
            child: _buildProfileImage(context),
          ),
        ),

        // Navigation (Back) Button
        if (widget.onBack != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.3),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: widget.onBack,
              ),
            ),
          ),

        // Edit Button
        if (widget.onEdit != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.3),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
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
        height: 500,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
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
    final outerShadow = isDark ? Colors.black54 : Colors.black26;

    return Container(
      padding: const EdgeInsets.all(4),
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
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          const BoxShadow(
            color: Color(0x66D4AF37),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        width: 150,
        height: 150,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
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
