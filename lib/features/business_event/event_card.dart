import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import './image_viewer_screen.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'edit_event_screen.dart'; // ✅ Edit Screen import करें

class EventCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final String baseImageUrl;
  final bool isMyEvent;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated; // ✅ New callback for update

  const EventCard({
    super.key,
    required this.event,
    required this.baseImageUrl,
    this.isMyEvent = false,
    this.onDeleted,
    this.onUpdated, // ✅ Optional update callback
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _showFullDescription = false;
  bool _isExpanded = false;
  static const String _baseUrl = AppConfig.apiBaseUrl;

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
    // Navigator.pop(context); // Close menu if open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditEventScreen(
            eventData: widget.event,
            onEventUpdated: () {
              // Callback when event is updated
              TopAlert.show(context, 'Event updated successfully!',
                  isSuccess: true);

              // Trigger the update callback if provided
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
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Confirm Delete",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Are you sure you want to delete this event? This action cannot be undone.",
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.white),
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

        // ✅ Call the delete callback to refresh UI
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
            final path = img['event_img_path'] as String?;
            if (path != null) {
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

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blueGrey[800],
                  backgroundImage: userAvatar != null
                      ? NetworkImage(userAvatar) as ImageProvider
                      : null,
                  child: userAvatar == null
                      ? Text(
                          userName.isNotEmpty
                              ? userName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // User Name and Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
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
                    color: Colors.blueGrey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      industryIcon ?? Icons.business_center,
                      color: Colors.white,
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
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                            Icon(Icons.edit, color: Colors.blue[300], size: 20),
                            const SizedBox(width: 12),
                            const Text(
                              "Edit Event",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            Icon(Icons.delete,
                                color: Colors.red[300], size: 20),
                            const SizedBox(width: 12),
                            const Text(
                              "Delete Event",
                              style: TextStyle(color: Colors.white),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
                if (description.length > 30)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showFullDescription = !_showFullDescription;
                      });
                    },
                    child: Text(
                      _showFullDescription ? 'Read Less' : 'Read More',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Event Link
            if (eventLink != null && eventLink.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Link:',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _launchUrl(eventLink),
                    child: Text(
                      eventLink.length > 40
                          ? '${eventLink.substring(0, 40)}...'
                          : eventLink,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            // Event Images Carousel
            if (eventImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Event Images:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: eventImages.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _openImageViewer(eventImages, index),
                      child: Container(
                        width: 220,
                        margin: EdgeInsets.only(
                          right: index < eventImages.length - 1 ? 12 : 0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[800],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: eventImages[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blue,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 48,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Failed to load',
                                      style: TextStyle(
                                        color: Colors.grey,
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
                  },
                ),
              ),
            ],
            // Expand/Collapse Button for Event Details
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Event Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            // Event Details (Expandable)
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              _buildEventDetails(event),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetails(Map<String, dynamic> event) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Start Date:', event['start_date']),
          _buildDetailRow('End Date:', event['end_date']),
          _buildDetailRow('Timing:', event['timing']),
          _buildDetailRow('Location:', event['location']),
          _buildDetailRow('Event Type:', event['event_type']),
          _buildDetailRow('Max Attendees:', event['max_attendees'].toString()),
          _buildDetailRow(
            'Online Event:',
            event['is_online'] == "1" ? 'Yes' : 'No',
          ),
          if (event['industry'] != null)
            _buildDetailRow(
              'Industry:',
              event['industry']['title'] ?? 'N/A',
            ),
          if (event['country'] != null)
            _buildDetailRow(
              'Country:',
              event['country']['ctry_name'] ?? 'N/A',
            ),
          if (event['state'] != null)
            _buildDetailRow(
              'State:',
              event['state']['state_name'] ?? 'N/A',
            ),
          if (event['district'] != null)
            _buildDetailRow(
              'District:',
              event['district']['district_name'] ?? 'N/A',
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
