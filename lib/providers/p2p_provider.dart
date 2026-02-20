import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/crypto_service.dart';
import 'package:pointycastle/asymmetric/api.dart' show RSAPublicKey;

class PeerInfo {
  final Socket socket;
  final RSAPublicKey publicKey;
  final String username;
  final String ip;
  final int port;

  PeerInfo({
    required this.socket,
    required this.publicKey,
    required this.username,
    required this.ip,
    required this.port,
  });
}

class P2PProvider with ChangeNotifier {
  final Map<String, PeerInfo> _peers = {};
  final CryptoService _crypto = CryptoService();
  ServerSocket? _serverSocket;

  String? _myUsername;
  int _p2pPort = 6001;

  Function(Map<String, dynamic>)? onMessageReceived;
  Function(String, String)? onUserStatusChanged;

  // 1. New Callback for status updates
  Function(String msgId, String status)? onMessageStatusUpdated;

  Map<String, PeerInfo> get peers => _peers;
  int get p2pPort => _p2pPort;

  Future<void> startServer(String username, {int port = 6001}) async {
    _myUsername = username;
    _p2pPort = port;

    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      debugPrint('[P2P] Server listening on port $port');

      _serverSocket!.listen((socket) {
        _handlePeer(socket);
      });
    } catch (e) {
      debugPrint('[P2P] Failed to start server: $e');
    }
  }

  Future<bool> connectToPeer(String ip, int port, String username) async {
    if (_peers.containsKey(username)) return false;

    try {
      final socket = await Socket.connect(ip, port);
      _handlePeer(socket);
      return true;
    } catch (e) {
      debugPrint('[P2P] Connection failed: $e');
      return false;
    }
  }

  void _handlePeer(Socket socket) {
    _sendHandshake(socket);

    String buffer = '';
    socket.listen(
          (data) {
        buffer += utf8.decode(data);
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final message = buffer.substring(0, newlineIndex);
          buffer = buffer.substring(newlineIndex + 1);
          _processPacket(socket, message);
        }
      },
      onDone: () => _removePeer(socket),
      onError: (e) => _removePeer(socket),
    );
  }

  void _sendHandshake(Socket socket) {
    final handshake = {
      'type': 'HANDSHAKE',
      'pub_key': _crypto.getPublicKeyPem(),
      'username': _myUsername,
    };
    _sendPacket(socket, handshake);
  }

  void _sendPacket(Socket socket, Map<String, dynamic> packet) {
    try {
      final data = '${json.encode(packet)}\n';
      socket.write(data);
    } catch (e) {
      debugPrint('[P2P] Send failed: $e');
    }
  }

  void _processPacket(Socket socket, String rawJson) {
    try {
      final data = json.decode(rawJson);

      switch (data['type']) {
        case 'HANDSHAKE':
          final publicKey = _crypto.loadPublicKey(data['pub_key']);
          final username = data['username'];
          _peers[username] = PeerInfo(
            socket: socket,
            publicKey: publicKey,
            username: username,
            ip: socket.remoteAddress.address,
            port: socket.remotePort,
          );
          onUserStatusChanged?.call(username, 'online');
          notifyListeners();
          break;

        case 'MESSAGE':
          final decrypted = _crypto.decryptMessage(data);
          final peerInfo = _peers.values.firstWhere((p) => p.socket == socket);

          onMessageReceived?.call({
            'type': 'message',
            'msg': decrypted,
            'id': data['id'], // Pass ID
            'sender': peerInfo.username,
            'room': data['room'] ?? 'group',
            'self': false,
            'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
          });
          break;

        case 'FILE':
          final decrypted = _crypto.decryptMessage(data);
          final fileData = json.decode(decrypted);
          final peerInfo = _peers.values.firstWhere((p) => p.socket == socket);

          onMessageReceived?.call({
            'type': 'file',
            'id': data['id'], // Pass ID
            'sender': peerInfo.username,
            'filename': fileData['filename'],
            'data': fileData['data'],
            'mimetype': fileData['mimetype'],
            'room': data['room'] ?? 'group',
            'self': false,
            'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
          });
          break;

      // 2. Handle incoming status updates
        case 'STATUS':
          final decrypted = _crypto.decryptMessage(data);
          final statusData = json.decode(decrypted);
          onMessageStatusUpdated?.call(statusData['msgId'], statusData['status']);
          break;
      }
    } catch (e) {
      debugPrint('[P2P] Packet processing error: $e');
    }
  }

  // 3. Updated sendMessage to require messageId
  void sendMessage(String message, String room, String messageId, {String? targetUser}) {
    void sendToPeer(PeerInfo peer) {
      final encrypted = _crypto.encryptMessage(message, peer.publicKey);
      encrypted['type'] = 'MESSAGE';
      encrypted['room'] = room;
      encrypted['id'] = messageId;
      _sendPacket(peer.socket, encrypted);
    }

    if (room == 'group') {
      for (final peer in _peers.values) sendToPeer(peer);
    } else if (targetUser != null && _peers.containsKey(targetUser)) {
      sendToPeer(_peers[targetUser]!);
    }
  }

  // 4. Updated sendFile to require messageId
  void sendFile(String filename, String data, String mimetype, String room, String messageId, {String? targetUser}) {
    final fileData = json.encode({
      'filename': filename,
      'data': data,
      'mimetype': mimetype,
    });

    void sendToPeer(PeerInfo peer) {
      final encrypted = _crypto.encryptMessage(fileData, peer.publicKey);
      encrypted['type'] = 'FILE';
      encrypted['room'] = room;
      encrypted['id'] = messageId;
      _sendPacket(peer.socket, encrypted);
    }

    if (room == 'group') {
      for (final peer in _peers.values) sendToPeer(peer);
    } else if (targetUser != null && _peers.containsKey(targetUser)) {
      sendToPeer(_peers[targetUser]!);
    }
  }

  // 5. New function to send status updates (delivered/read)
  void sendStatusUpdate(String messageId, String status, String room, {String? targetUser}) {
    final statusPayload = json.encode({
      'msgId': messageId,
      'status': status,
    });

    void sendToPeer(PeerInfo peer) {
      final encrypted = _crypto.encryptMessage(statusPayload, peer.publicKey);
      encrypted['type'] = 'STATUS';
      encrypted['room'] = room;
      _sendPacket(peer.socket, encrypted);
    }

    if (room == 'group') {
      // In groups, sending status to everyone is simple but can be noisy.
      // For now, this is acceptable for a prototype.
      for (final peer in _peers.values) sendToPeer(peer);
    } else if (targetUser != null && _peers.containsKey(targetUser)) {
      sendToPeer(_peers[targetUser]!);
    }
  }

  void _removePeer(Socket socket) {
    try {
      final username = _peers.entries
          .firstWhere((e) => e.value.socket == socket)
          .key;
      _peers.remove(username);
      onUserStatusChanged?.call(username, 'offline');
      notifyListeners();
    } catch(e) {
      // socket already gone
    }
    socket.close();
  }

  @override
  void dispose() {
    for (final peer in _peers.values) peer.socket.close();
    _serverSocket?.close();
    super.dispose();
  }
}