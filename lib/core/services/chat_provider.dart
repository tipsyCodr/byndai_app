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

  // Future<bool> sendConnectionRequest(int receiverId) async {
  //   _isLoading = true;
  //   notifyListeners();

  //   try {
  //     final response = await ChatService.sendConnectionRequest(receiverId);

  //     if (response != null && response['status'] == true) {
  //       debugPrint('✅ Connection request sent');
  //       return true;
  //     } else {
  //       debugPrint('⚠️ Connection request failed: ${response?['message']}');
  //       return false;
  //     }
  //   } catch (e) {
  //     debugPrint('🚨 Error in ChatProvider.sendConnectionRequest: $e');
  //     return false;
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  // Add this helper function in chat_provider.dart
// Future<bool> sendConnectionRequest(BuildContext context, int receiverId) async {
//   _isLoading = true;
//   notifyListeners();

//   try {
//     final response = await ChatService.sendConnectionRequest(receiverId);

//     debugPrint('📱 Provider received: $response');

//     if (response != null) {
//       final status = response['status'];
//       final message = response['message'] ?? 'Unknown response';
      
//       if (status == true || status == 'true' || status == 1) {
//         debugPrint('✅ Connection request sent: $message');
//         await fetchConnections();
//         return true;
//       } else {
//         debugPrint('⚠️ Connection request failed: $message');
        
//         // Use provided context
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed: $message'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return false;
//       }
//     }
//     return false;
//   } catch (e) {
//     debugPrint('🚨 Exception: $e');
//     return false;
//   } finally {
//     _isLoading = false;
//     notifyListeners();
//   }
// }

Future<bool> sendConnectionRequest(
    BuildContext context, int receiverId) async {
  _isLoading = true;
  notifyListeners();

  try {
    final response =
        await ChatService.sendConnectionRequest(receiverId);

    debugPrint('📱 Provider Response: $response');

    if (response['status'] == true) {
      await fetchConnections();
      return true;
    }

    // ❌ API error → popup dikhao
    // _showApiErrorDialog(context, response);
    return false;
  } catch (e) {
    // _showApiErrorDialog(context, {
    //   'exception': e.toString(),
    // });
    debugPrint('🚨 Exception: $e');
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}




  
}
