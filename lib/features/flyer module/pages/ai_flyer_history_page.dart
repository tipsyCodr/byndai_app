import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gridcard/core/services/ai_flyer_service.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'ai_flyer_preview_page.dart';
import 'ai_flyer_progress_sheet.dart';

class AiFlyerHistoryPage extends StatefulWidget {
  const AiFlyerHistoryPage({super.key});

  @override
  State<AiFlyerHistoryPage> createState() => _AiFlyerHistoryPageState();
}

class _AiFlyerHistoryPageState extends State<AiFlyerHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _flyers = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({int page = 1}) async {
    setState(() => _isLoading = true);
    try {
      final res = await AiFlyerService.fetchHistory(page: page);
      final List data = res['data'] ?? [];

      setState(() {
        _flyers = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) TopAlert.show(context, 'Failed to load flyers: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFlyer(Map<String, dynamic> flyer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Flyer?'),
        content: const Text('Are you sure you want to delete this flyer? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await AiFlyerService.deleteFlyer(flyer['id']);
      if (success) {
        setState(() {
          _flyers.removeWhere((f) => f['id'] == flyer['id']);
        });
        if (mounted) TopAlert.show(context, 'Flyer deleted', isSuccess: true);
      }
    } catch (e) {
      if (mounted) TopAlert.show(context, 'Failed to delete flyer', isError: true);
    }
  }

  void _onFlyerTap(Map<String, dynamic> flyer) async {
    final status = flyer['status'];
    if (status == 'pending' || status == 'processing') {
      final updated = await AiFlyerProgressSheet.show(
        context,
        generationId: flyer['id'],
        title: flyer['occasion']?['name'] ?? flyer['category'] ?? 'Flyer',
      );
      if (updated != null) {
        _loadHistory();
      }
    } else if (status == 'completed') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiFlyerPreviewPage(flyer: flyer),
        ),
      );
      if (result != null) {
        _loadHistory();
      }
    } else {
      TopAlert.show(context, 'Generation failed: ${flyer['error_message'] ?? 'Unknown error'}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My AI Flyers', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadHistory(page: 1),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _flyers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadHistory(page: 1),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: theme.colorScheme.primary.withValues(alpha: 0.06),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Flyers are saved securely on cloud. Oldest flyers auto-archive when limit is reached.',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _flyers.length,
                          itemBuilder: (context, index) {
                            final flyer = _flyers[index];
                            return _buildFlyerCard(flyer);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 72, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              'No AI Flyers Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate business flyers for today\'s occasions or custom promotions in seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Create a Flyer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlyerCard(Map<String, dynamic> flyer) {
    final theme = Theme.of(context);
    final status = flyer['status'] ?? 'pending';
    final isDone = status == 'completed';
    final imageUrl = flyer['image_url'];
    final title = flyer['occasion']?['name'] ?? flyer['category'] ?? 'Flyer';
    final dateStr = flyer['created_at'] != null
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(flyer['created_at']).toLocal())
        : '';

    return GestureDetector(
      onTap: () => _onFlyerTap(flyer),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isDone && imageUrl != null)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image)),
                    )
                  else if (status == 'failed')
                    Container(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      child: Center(
                        child: Icon(Icons.error_outline, color: theme.colorScheme.error, size: 36),
                      ),
                    )
                  else
                    Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),

                  // Status Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'completed'
                            ? Colors.green.shade700
                            : status == 'failed'
                                ? Colors.red.shade700
                                : Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Delete button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _deleteFlyer(flyer),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(color: theme.disabledColor, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
