import 'package:flutter/foundation.dart';
import '../models/message.dart';


class ChatRoom {
  final String id;
  final String name;
  final bool isPrivate;
  final List<Message> messages;

  ChatRoom({
    required this.id,
    required this.name,
    required this.isPrivate,
    this.messages = const [],
  });
}

class ChatProvider with ChangeNotifier {
  final Map<String, List<Message>> _messageHistory = {
    'group': [],
  };

  String _currentRoom = 'group';
  final List<String> _rooms = ['group'];

  String get currentRoom => _currentRoom;
  List<String> get rooms => _rooms;
  List<Message> get currentMessages => _messageHistory[_currentRoom] ?? [];

  void addMessage(Message message) {
    if (!_messageHistory.containsKey(message.room)) {
      _messageHistory[message.room] = [];
    }
    _messageHistory[message.room]!.add(message);
    notifyListeners();
  }

  void addMessages(String room, List<Message> messages) {
    if (!_messageHistory.containsKey(room)) {
      _messageHistory[room] = [];
    }
    _messageHistory[room]!.addAll(messages);
    notifyListeners();
  }

  // Update status of a specific message
  void updateMessageStatus(String messageId, MessageStatus newStatus) {
    bool found = false;
    _messageHistory.forEach((room, messages) {
      if (found) return;
      for (var msg in messages) {
        if (msg.id == messageId) {
          msg.status = newStatus;
          found = true;
          break;
        }
      }
    });

    if (found) {
      notifyListeners();
    }
  }

  void switchRoom(String roomId) {
    _currentRoom = roomId;
    if (!_rooms.contains(roomId)) {
      _rooms.add(roomId);
    }
    notifyListeners();
  }

  void createPrivateRoom(String username, String myUsername) {
    final users = [username, myUsername]..sort();
    final roomId = 'dm_${users.join('_')}';

    if (!_rooms.contains(roomId)) {
      _rooms.add(roomId);
    }
    switchRoom(roomId);
  }

  String getRoomDisplayName(String roomId, String myUsername) {
    if (roomId == 'group') return 'Group Chat';
    return roomId
        .replaceAll('dm_', '')
        .replaceAll(myUsername, '')
        .replaceAll('_', '')
        .trim();
  }

  void clearHistory() {
    _messageHistory.clear();
    _messageHistory['group'] = [];
    _rooms.clear();
    _rooms.add('group');
    _currentRoom = 'group';
    notifyListeners();
  }

  List<Message> getRoomMessages(String roomId) {
    return _messageHistory[roomId] ?? [];
  }
}