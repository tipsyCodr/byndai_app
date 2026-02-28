import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:provider/provider.dart';

class LinksManagementPage extends StatefulWidget {
  const LinksManagementPage({super.key});

  @override
  State<LinksManagementPage> createState() => _LinksManagementPageState();
}

class _LinksManagementPageState extends State<LinksManagementPage> {
  void _showLinkDialog({Map<String, dynamic>? link}) {
    final titleController =
        TextEditingController(text: link?['title'] ?? link?['link_name'] ?? '');
    final urlController =
        TextEditingController(text: link?['link_data'] ?? link?['url'] ?? '');
    final bool isEditing = link != null;

    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(isEditing ? 'Edit Link' : 'Add Link',
            style: TextStyle(color: colorScheme.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Title (e.g., Instagram)',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'URL',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                hintText: 'https://...',
                hintStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (titleController.text.isEmpty || urlController.text.isEmpty) {
                return;
              }

              final provider = context.read<ProfileProvider>();
              bool success;
              if (isEditing) {
                success =
                    await provider.updateLink(link['link_id'] ?? link['id'], {
                  'title': titleController.text,
                  'link_data': urlController.text,
                });
              } else {
                success = await provider.createLink({
                  'title': titleController.text,
                  'link_data': urlController.text,
                });
              }

              if (mounted && success) Navigator.pop(context);
            },
            child: Text(isEditing ? 'Update' : 'Add',
                style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int linkId) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title:
            Text('Delete Link', style: TextStyle(color: colorScheme.primary)),
        content: Text('Are you sure you want to delete this link?',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final success =
                  await context.read<ProfileProvider>().deleteLink(linkId);
              if (mounted && success) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final links = provider.links;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text('Manage Social Links',
            style: TextStyle(color: colorScheme.primary)),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        onPressed: () => _showLinkDialog(),
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : links.isEmpty
              ? Center(
                  child: Text('No links added yet',
                      style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.3))))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: links.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final link = links[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(CupertinoIcons.link,
                            color: colorScheme.primary),
                        title: Text(
                            link['title'] ?? link['link_name'] ?? 'Link',
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(link['link_data'] ?? link['url'] ?? '',
                            style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color: colorScheme.onSurface.withOpacity(0.4),
                                  size: 20),
                              onPressed: () => _showLinkDialog(link: link),
                            ),
                            IconButton(
                              icon: const Icon(CupertinoIcons.trash,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () =>
                                  _confirmDelete(link['link_id'] ?? link['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
