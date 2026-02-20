import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// Make sure these match your actual folder structure
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/p2p_provider.dart';
import '../models/message.dart';
import '../services/notification_service.dart';

// If you created badge_icon.dart separately, import it here:
// import '../widgets/badge_icon.dart';
// If not, I have included the class at the bottom of this file for convenience.

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _onlineUsers = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final p2p = Provider.of<P2PProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    await p2p.startServer(auth.username!);

    // Handle Incoming Messages
    p2p.onMessageReceived = (data) {
      final msg = Message.fromJson(data);
      chat.addMessage(msg);

      // AUTOMATIC: Send "Delivered" or "Read"
      if (!msg.isSelf) {
        if (chat.currentRoom == msg.room) {
          // If we are looking at the chat, mark as read immediately
          p2p.sendStatusUpdate(msg.id, 'read', msg.room, targetUser: msg.sender);
          chat.updateMessageStatus(msg.id, MessageStatus.read);
        } else {
          // If we are NOT looking at the chat:
          // 1. Send "Delivered" status back to sender
          p2p.sendStatusUpdate(msg.id, 'delivered', msg.room, targetUser: msg.sender);
          chat.updateMessageStatus(msg.id, MessageStatus.delivered);

          // 2. TRIGGER NOTIFICATION (Heads-up banner)
          NotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: msg.sender,
            body: msg.type == MessageType.file ? '📷 Sent a photo' : msg.content,
          );
        }
      }
    };

    // Handle Status Updates (Ticks)
    p2p.onMessageStatusUpdated = (msgId, statusStr) {
      MessageStatus status;
      switch (statusStr) {
        case 'read': status = MessageStatus.read; break;
        case 'delivered': status = MessageStatus.delivered; break;
        default: status = MessageStatus.sent;
      }
      chat.updateMessageStatus(msgId, status);
    };

    p2p.onUserStatusChanged = (username, status) {
      _loadOnlineUsers();
    };

    _loadOnlineUsers();

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 20));
      if (mounted) {
        _loadOnlineUsers();
        return true;
      }
      return false;
    });
  }

  Future<void> _loadOnlineUsers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final users = await auth.getOnlineUsers();
    if (mounted) {
      setState(() => _onlineUsers = users);
    }
  }

  Future<void> _connectToUser(String username, String ip, int port) async {
    final p2p = Provider.of<P2PProvider>(context, listen: false);
    await p2p.connectToPeer(ip, port, username);
    if (!mounted) return;
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final p2p = Provider.of<P2PProvider>(context, listen: false);

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = Message(
      id: messageId,
      sender: auth.username!,
      content: _messageController.text,
      room: chat.currentRoom,
      isSelf: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    chat.addMessage(message);

    final targetUser = chat.currentRoom.startsWith('dm_')
        ? chat.getRoomDisplayName(chat.currentRoom, auth.username!)
        : null;

    p2p.sendMessage(message.content, chat.currentRoom, messageId, targetUser: targetUser);

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    final bytes = await File(image.path).readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final p2p = Provider.of<P2PProvider>(context, listen: false);

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = Message(
      id: messageId,
      sender: auth.username!,
      content: '',
      room: chat.currentRoom,
      isSelf: true,
      timestamp: DateTime.now(),
      type: MessageType.file,
      filePath: base64Image,
      fileName: image.name,
      status: MessageStatus.sent,
    );

    chat.addMessage(message);

    final targetUser = chat.currentRoom.startsWith('dm_')
        ? chat.getRoomDisplayName(chat.currentRoom, auth.username!)
        : null;

    p2p.sendFile(image.name, base64Image, 'image/jpeg', chat.currentRoom, messageId, targetUser: targetUser);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _markRoomAsRead(String roomId) {
    final p2p = Provider.of<P2PProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    final messages = chat.getRoomMessages(roomId);
    for (var msg in messages) {
      if (!msg.isSelf && msg.status != MessageStatus.read) {
        p2p.sendStatusUpdate(msg.id, 'read', roomId, targetUser: msg.sender);
        chat.updateMessageStatus(msg.id, MessageStatus.read);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chat = Provider.of<ChatProvider>(context);
    final p2p = Provider.of<P2PProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    // --- NEW LOGIC: Calculate Total Unread Messages ---
    int totalUnreadCount = 0;
    for (var room in chat.rooms) {
      // We only count unread messages that are NOT from us
      final roomMsgs = chat.getRoomMessages(room);
      totalUnreadCount += roomMsgs.where((m) => !m.isSelf && m.status != MessageStatus.read).length;
    }
    // ------------------------------------------------

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chat.currentRoom == 'group' ? 'Group Chat' : chat.getRoomDisplayName(chat.currentRoom, auth.username!),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                chat.currentRoom == 'group' ? 'All connected users' : 'Private conversation',
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ],
          ),
          leading: Builder(builder: (c) => IconButton(
            icon: const Icon(Icons.people, color: Color(0xff667eea)),
            onPressed: () => Scaffold.of(c).openDrawer(),
          )),
          actions: [
            // --- NEW: BadgeIcon Implementation ---
            Builder(builder: (c) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: BadgeIcon(
                icon: Icons.chat_bubble,
                // Color matches your theme (0xff667eea) inside the BadgeIcon class logic or passed manually if modified
                // Since my BadgeIcon defaults to black, let's just use it, or you can edit BadgeIcon color.
                notificationCount: totalUnreadCount,
                onTap: () => Scaffold.of(c).openEndDrawer(),
              ),
            )),
          ],
        ),
        drawer: Drawer(width: 280, child: _buildUsersSidebar(auth, p2p, isMobile: true)),
        endDrawer: Drawer(width: 280, child: _buildRoomsSidebar(chat, auth, isMobile: true)),
        body: _buildChatArea(chat, auth, isMobile: true),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 280, child: _buildUsersSidebar(auth, p2p, isMobile: false)),
          Expanded(child: _buildChatArea(chat, auth, isMobile: false)),
          SizedBox(width: 250, child: _buildRoomsSidebar(chat, auth, isMobile: false)),
        ],
      ),
    );
  }

  Widget _buildUsersSidebar(AuthProvider auth, P2PProvider p2p, {required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[100], border: isMobile ? null : Border(right: BorderSide(color: Colors.grey[300]!))),
      child: Column(children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, isMobile ? 50 : 20, 20, 20),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xff667eea), Color(0xff764ba2)])),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Users', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Row(children: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadOnlineUsers),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async {
                await auth.logout();
                if(!mounted) return;
                Provider.of<ChatProvider>(context, listen:false).clearHistory();
              }),
            ]),
          ]),
        ),
        Expanded(child: ListView.builder(
            itemCount: _onlineUsers.length,
            itemBuilder: (context, index) {
              final user = _onlineUsers[index];
              final isConnected = p2p.peers.containsKey(user['username']);
              return ListTile(
                leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: isConnected ? Colors.green : Colors.orange, shape: BoxShape.circle)),
                title: Text(user['username']),
                subtitle: Text(isConnected ? 'connected' : 'online'),
                trailing: !isConnected ? IconButton(icon: const Icon(Icons.link), onPressed: () => _connectToUser(user['username'], user['ip'], user['port'])) : null,
                onTap: () {
                  final chat = Provider.of<ChatProvider>(context, listen: false);
                  chat.createPrivateRoom(user['username'], auth.username!);
                  _markRoomAsRead(chat.currentRoom);
                  if(isMobile) Navigator.pop(context);
                },
              );
            }
        )),
      ]),
    );
  }

  Widget _buildRoomsSidebar(ChatProvider chat, AuthProvider auth, {required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[100], border: isMobile ? null : Border(left: BorderSide(color: Colors.grey[300]!))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.fromLTRB(20, isMobile?50:20, 20, 20), child: const Text('Chats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(
          itemCount: chat.rooms.length,
          itemBuilder: (context, index) {
            final room = chat.rooms[index];

            // --- NEW: Count Unread per Room for Badge ---
            final unreadCount = chat.getRoomMessages(room).where((m) => !m.isSelf && m.status != MessageStatus.read).length;

            return ListTile(
              title: Text(chat.getRoomDisplayName(room, auth.username!)),
              selected: chat.currentRoom == room,
              selectedTileColor: const Color(0xff667eea).withValues(alpha: 0.1),
              // Optional: Show count in sidebar too
              trailing: unreadCount > 0
                  ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10))
              )
                  : null,
              onTap: () {
                chat.switchRoom(room);
                _markRoomAsRead(room);
                if(isMobile) Navigator.pop(context);
              },
            );
          },
        ))
      ]),
    );
  }

  Widget _buildChatArea(ChatProvider chat, AuthProvider auth, {required bool isMobile}) {
    return Column(children: [
      if(!isMobile) Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
        child: Text(chat.getRoomDisplayName(chat.currentRoom, auth.username!), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      Expanded(child: Container(color: Colors.grey[50], child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: chat.currentMessages.length,
        itemBuilder: (context, index) => _buildMessageBubble(chat.currentMessages[index]),
      ))),
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickImage),
          Expanded(child: TextField(
            controller: _messageController,
            decoration: InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(25))),
            onSubmitted: (_) => _sendMessage(),
          )),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _sendMessage, style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(16), backgroundColor: const Color(0xff667eea)), child: const Icon(Icons.send, color: Colors.white)),
        ]),
      ),
    ]);
  }

  Widget _buildMessageBubble(Message message) {
    final isImage = message.type == MessageType.file && message.filePath != null;
    return Align(
      alignment: message.isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isSelf ? const Color(0xff667eea) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if(!message.isSelf) Text(message.sender, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          if(isImage) Image.memory(base64Decode(message.filePath!.split(',')[1]), width: 200)
          else Text(message.content, style: TextStyle(color: message.isSelf ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(DateFormat('HH:mm').format(message.timestamp), style: TextStyle(fontSize: 10, color: message.isSelf ? Colors.white60 : Colors.grey)),
            if(message.isSelf) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(message.status),
            ]
          ]),
        ]),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.lightBlueAccent);
      default:
        return const Icon(Icons.access_time, size: 12, color: Colors.white70);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// --- BADGE ICON WIDGET (Included here for ease of copy/paste) ---
class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int notificationCount;
  final VoidCallback? onTap;

  const BadgeIcon({
    super.key,
    required this.icon,
    this.notificationCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            // Updated color to match your app theme (0xff667eea)
            child: Icon(icon, size: 28, color: const Color(0xff667eea)),
          ),
          if (notificationCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    notificationCount > 99 ? '99+' : '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}