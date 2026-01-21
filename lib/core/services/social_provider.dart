import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/social_service.dart';
import 'package:gridcard/models/feed_item.dart';

class SocialProvider extends ChangeNotifier {
  List<FeedItem> _posts = [];
  Map<int, List<dynamic>> _comments = {};
  bool _isLoading = false;

  List<FeedItem> get posts => _posts;
  bool get isLoading => _isLoading;

  List<dynamic> getComments(int postId) => _comments[postId] ?? [];

  Future<void> fetchPosts(String industryType) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rawPosts = await SocialService.fetchPosts(industryType);
      _posts = rawPosts.map((json) => FeedItem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('🚨 Error in SocialProvider.fetchPosts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPost(
      String description, File? image, String industryType) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await SocialService.createPost(
          description: description, image: image);
      if (success) {
        await fetchPosts(industryType);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 Error in SocialProvider.createPost: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(int postId) async {
    // Optimistic UI update
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index].isLiked = !_posts[index].isLiked;
      _posts[index].isLiked
          ? _posts[index].likesCount++
          : _posts[index].likesCount--;
      notifyListeners();
    }

    try {
      final success = await SocialService.toggleLike(postId);
      if (!success) {
        // Rollback on failure
        if (index != -1) {
          _posts[index].isLiked = !_posts[index].isLiked;
          _posts[index].isLiked
              ? _posts[index].likesCount++
              : _posts[index].likesCount--;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('🚨 Error in SocialProvider.toggleLike: $e');
    }
  }

  Future<void> toggleSave(int postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index].isSaved = !_posts[index].isSaved;
      notifyListeners();
    }

    try {
      await SocialService.toggleSave(postId);
    } catch (e) {
      debugPrint('🚨 Error in SocialProvider.toggleSave: $e');
    }
  }

  Future<void> fetchComments(int postId) async {
    try {
      final data = await SocialService.fetchComments(postId);
      _comments[postId] = data;
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 Error in SocialProvider.fetchComments: $e');
    }
  }

  Future<bool> addComment(int postId, String comment) async {
    try {
      final success = await SocialService.addComment(postId, comment);
      if (success) {
        await fetchComments(postId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 Error in SocialProvider.addComment: $e');
      return false;
    }
  }
}
