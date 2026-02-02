import 'package:flutter/material.dart';
import 'package:gridcard/core/services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  List<dynamic> _connections = [];
  bool _isLoading = false;

  List<dynamic> get connections => _connections;
  bool get isLoading => _isLoading;

  Future<void> fetchConnections() async {
    _isLoading = true;
    notifyListeners();

    try {
      _connections = await ChatService.fetchConnections();
    } catch (e) {
      debugPrint('🚨 Error in ChatProvider.fetchConnections: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createConnection(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await ChatService.createConnection(userId);
      if (success) {
        await fetchConnections();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 Error in ChatProvider.createConnection: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(int chatId, String message) async {
    try {
      final success = await ChatService.sendMessage(chatId, message);
      return success;
    } catch (e) {
      debugPrint('🚨 Error in ChatProvider.sendMessage: $e');
      return false;
    }
  }

  //amit code start

  Future<bool> sendConnectionRequest(int receiverId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ChatService.sendConnectionRequest(receiverId);

      if (response != null && response['status'] == true) {
        debugPrint('✅ Connection request sent');
        return true;
      } else {
        debugPrint('⚠️ Connection request failed: ${response?['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('🚨 Error in ChatProvider.sendConnectionRequest: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
