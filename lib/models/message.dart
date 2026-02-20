enum MessageType { text, file }

// Enum to track the state of the message (Sent -> Delivered -> Read)
enum MessageStatus { sent, delivered, read }

class Message {
  final String id;
  final String sender;
  final String content;
  final String room;
  final bool isSelf;
  final DateTime timestamp;
  final MessageType type;
  final String? filePath;
  final String? fileName;

  // Status is not final because we update it when we get a "read receipt"
  MessageStatus status;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.room,
    required this.isSelf,
    required this.timestamp,
    this.type = MessageType.text,
    this.filePath,
    this.fileName,
    this.status = MessageStatus.sent, // Default new messages to 'sent'
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: json['sender'] ?? '',
      content: json['msg'] ?? json['content'] ?? '',
      room: json['room'] ?? 'group',
      isSelf: json['self'] ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] * 1000).toInt())
          : DateTime.now(),
      type: json['type'] == 'file' ? MessageType.file : MessageType.text,
      filePath: json['data'],
      fileName: json['filename'],
      // When we receive a message, we start tracking it as 'sent' (or delivered)
      status: MessageStatus.sent,
    );
  }
}