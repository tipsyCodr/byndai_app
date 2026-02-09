


import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import './image_viewer_screen.dart';

class EventCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final String baseImageUrl;

  const EventCard({
    super.key,
    required this.event,
    required this.baseImageUrl,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _showFullDescription = false;
  bool _isExpanded = false;

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

  // Get industry icon (FontAwesome icon class से icon बनाने के लिए)
  IconData? _getIndustryIcon() {
    final industry = widget.event['industry'];
    if (industry != null && industry['icons'] != null) {
      final iconClass = industry['icons'] as String;
      // FontAwesome icons को Flutter icons में convert करें
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
      return images.map<String>((img) {
        final path = img['event_img_path'] as String?;
        if (path != null) {
          // Remove any leading slash and encode URL
          String cleanPath = path.startsWith('/') ? path.substring(1) : path;
          // Spaces को %20 में convert करें
          cleanPath = cleanPath.replaceAll(' ', '%20');
          return '${widget.baseImageUrl}/$cleanPath';
        }
        return '';
      }).where((url) => url.isNotEmpty).toList();
    }
    return [];
  }

  // Launch URL function
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
          backgroundColor: Colors.red,
        ),
      );
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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