import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import './image_viewer_screen.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'edit_event_screen.dart';
import 'package:gridcard/widgets/core/core_widgets.dart';

class EventCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final String baseImageUrl;
  final bool isMyEvent;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;

  const EventCard({
    super.key,
    required this.event,
    required this.baseImageUrl,
    this.isMyEvent = false,
    this.onDeleted,
    this.onUpdated,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _showFullDescription = false;
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _storageBaseUrl = AppConfig.storageBaseUrl;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= EDIT EVENT NAVIGATION =================
  void _navigateToEditEvent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditEventScreen(
            eventData: widget.event,
            onEventUpdated: () {
              TopAlert.show(context, 'Event updated successfully!',
                  isSuccess: true);
              widget.onUpdated?.call();
            },
          ),
        ),
      );
    });
  }

  // ================= DELETE EVENT =================
  Future<void> _confirmDeleteEvent() async {
    final eventId = widget.event['id'];

    if (eventId == null) {
      TopAlert.show(context, "Event ID not found!", isError: true);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Confirm Delete",
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            "Are you sure you want to delete this event? This action cannot be undone.",
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Delete",
                  style: TextStyle(color: colorScheme.onError),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteEvent(eventId);
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    try {
      final uri = Uri.parse("$_baseUrl/delete-event/$eventId");

      final response = await http.delete(
        uri,
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        TopAlert.show(context, data['message'] ?? "Event deleted successfully",
            isSuccess: true);
        widget.onDeleted?.call();
      } else {
        TopAlert.show(context, data['message'] ?? "Failed to delete event",
            isError: true);
      }
    } catch (e) {
      TopAlert.show(context, "Error: ${e.toString()}", isError: true);
    }
  }

  // Format date and time
  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} $hour:$minute';
    } catch (e) {
      return dateTimeStr;
    }
  }

  // Get user avatar
  String? _getUserAvatar() {
    final masterUser = widget.event['created_by_user']?['master_user'];
    if (masterUser != null && masterUser['profile_pic'] != null) {
      final profilePic = masterUser['profile_pic'] as String;
      if (profilePic.isNotEmpty) {
        final resolved = AppConfig.getFullUrl(profilePic);
        if (resolved != null && resolved.trim().isNotEmpty) {
          return resolved.trim().replaceAll(' ', '%20');
        }
        return '${widget.baseImageUrl}/${profilePic.replaceFirst('/', '')}';
      }
    }
    return null;
  }

  // Get industry icon
  IconData? _getIndustryIcon() {
    final industry = widget.event['industry'];
    if (industry != null && industry['icons'] != null) {
      final iconClass = industry['icons'] as String;
      if (iconClass.contains('fa-piggy-bank')) {
        return Icons.account_balance;
      } else if (iconClass.contains('fa-building')) {
        return Icons.business;
      } else if (iconClass.contains('fa-store')) {
        return Icons.store;
      } else if (iconClass.contains('fa-industry')) {
        return Icons.factory;
      }
    }
    return Icons.business_center;
  }

  // Get event images
  List<String> _getEventImages() {
    final images = widget.event['images'] as List?;
    if (images != null && images.isNotEmpty) {
      return images
          .map<String>((img) {
            if (img is! Map) return '';
            final fullUrl = img['full_url']?.toString();
            if (fullUrl != null && fullUrl.trim().isNotEmpty) {
              return fullUrl.trim().replaceAll(' ', '%20');
            }

            final path = img['event_img_path']?.toString();
            if (path != null && path.trim().isNotEmpty) {
              final directUrl = _buildEventStorageUrl(path);
              if (directUrl != null && directUrl.isNotEmpty) {
                return directUrl;
              }

              final resolvedPath = AppConfig.getFullUrl(path);
              if (resolvedPath != null && resolvedPath.trim().isNotEmpty) {
                return resolvedPath.trim().replaceAll(' ', '%20');
              }
              String cleanPath =
                  path.startsWith('/') ? path.substring(1) : path;
              cleanPath = cleanPath.replaceAll(' ', '%20');
              return '${widget.baseImageUrl}/$cleanPath';
            }
            return '';
          })
          .where((url) => url.isNotEmpty)
          .toList();
    }
    return [];
  }

  String? _buildEventStorageUrl(String rawPath) {
    String path = rawPath.trim();
    if (path.isEmpty) return null;

    if (path.startsWith('http')) {
      return path.replaceAll(' ', '%20');
    }

    path = path.replaceAll('\\', '/');
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Path already contains event/ segment from backend.
    if (path.startsWith('event/')) {
      return '$_storageBaseUrl/$path'.replaceAll(' ', '%20');
    }

    // Build standard URL: /storage/event/{event_name}/{filename}
    final filename = path.split('/').last;
    final eventName =
        (widget.event['event_name'] ?? widget.event['title'] ?? 'event')
            .toString()
            .trim()
            .replaceAll(RegExp(r'\s+'), '_');
    return '$_storageBaseUrl/event/$eventName/$filename'.replaceAll(' ', '%20');
  }

  // Launch URL function
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      TopAlert.show(context, 'Could not launch $url', isError: true);
    }
  }

  // Open image viewer
  void _openImageViewer(List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          images: images,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final event = widget.event;
    final userName = event['created_by_fname'] ?? 'Unknown User';
    final createdAt = event['created_at'] != null
        ? _formatDateTime(event['created_at'])
        : 'N/A';
    final title = event['title'] ?? 'No Title';
    final description = event['description'] ?? 'No Description';
    final displayDescription = _showFullDescription
        ? description
        : (description.length > 30
            ? '${description.substring(0, 30)}...'
            : description);
    final eventLink = event['link'];
    final eventImages = _getEventImages();
    final userAvatar = _getUserAvatar();
    final industryIcon = _getIndustryIcon();

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: colorScheme.onSurface.withOpacity(0.05), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row - User Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: colorScheme.primary.withOpacity(0.1),
                        width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        isDark ? colorScheme.surface : Colors.grey[200],
                    backgroundImage: userAvatar != null
                        ? NetworkImage(userAvatar) as ImageProvider
                        : null,
                    child: userAvatar == null
                        ? Text(
                            userName.isNotEmpty
                                ? userName.substring(0, 1).toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // User Name and Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          color: isDark
                              ? colorScheme.onSurface
                              : colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Industry Icon/Logo
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      industryIcon ?? Icons.business_center,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ),

                if (widget.isMyEvent) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_vert,
                        color: colorScheme.onSurface.withOpacity(0.3),
                        size: 20,
                      ),
                    ),
                    color: isDark
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: colorScheme.primary.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    onSelected: (value) {
                      if (value == "edit") {
                        _navigateToEditEvent();
                      } else if (value == "delete") {
                        _confirmDeleteEvent();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "edit",
                        child: Row(
                          children: [
                            Icon(Icons.edit,
                                color: colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              "Edit Event",
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            Icon(Icons.delete,
                                color: colorScheme.error, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              "Delete Event",
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            // Description with Read More
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayDescription,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.5,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (description.length > 30)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showFullDescription = !_showFullDescription;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _showFullDescription ? 'Read Less' : 'Read More',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Event Images (Full Width)
            if (eventImages.isNotEmpty)
              Column(
                children: List.generate(eventImages.length, (index) {
                  return GestureDetector(
                    onTap: () => _openImageViewer(eventImages, index),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: eventImages[index],
                          fit: BoxFit.fitWidth,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.3),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load',
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.3),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            const SizedBox(height: 16),
            AppButton(
                label: 'More Details',
                onPressed: () => _launchUrl(eventLink.toString())),
            // Event details section hidden by request.
          ],
        ),
      ),
    );
  }
}
