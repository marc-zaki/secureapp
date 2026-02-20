# 🔒 Secure P2P Chat Application

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/Python-3.8+-green.svg)](https://www.python.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![MongoDB](https://img.shields.io/badge/MongoDB-4.4+-green.svg)](https://www.mongodb.com/)

A privacy-focused, end-to-end encrypted messaging platform with peer-to-peer architecture. Messages are encrypted on the sender's device and can only be decrypted by the intended recipient—no server or third party can access your conversations.

---

## ✨ Features

### 🔐 Security & Privacy
- **End-to-End Encryption**: RSA-2048 for key exchange, AES-256 for message content
- **Zero Knowledge Architecture**: Server never has access to private keys or message content
- **Email Verification**: 6-digit OTP codes for account security
- **Secure Authentication**: JWT tokens with bcrypt password hashing
- **Perfect Forward Secrecy**: Each message encrypted with unique session key

### 💬 Messaging
- **Group Chat**: Encrypted messages to all connected users
- **Private DMs**: One-on-one encrypted conversations
- **File Sharing**: Send encrypted images and documents
- **Message History**: Persistent chat history per room
- **Real-time Delivery**: Instant message delivery via TCP sockets

### 🌐 Connectivity
- **P2P Architecture**: Direct TCP connections between peers
- **Online Presence**: Real-time online/offline status tracking
- **Automatic Reconnection**: Handles network interruptions gracefully
- **Heartbeat Mechanism**: Keeps connections alive with 15-second heartbeats

### 📱 Cross-Platform
- **Mobile**: Native Android & iOS apps (Flutter)
- **Desktop**: Windows, macOS, Linux support (Flutter)
- **Web**: Responsive browser-based interface (React)
- **Consistent UX**: Unified experience across all platforms


## 📁 Project Structure

```
secure-chat/
├── 📄 server.py                 # Authentication server (Flask)
├── 📄 app.py                    # Client application (Flask + SocketIO)
├── 📄 crypto_utils.py           # Encryption utilities (RSA + AES)
├── 📄 requirements.txt          # Python dependencies
│
├── 📁 templates/
│   ├── login.html              # Login/Registration page
│   └── index.html              # Chat interface
│
├── 📁 static/
│   ├── style.css               # Styling
│   └── script.js               # Client-side JavaScript
│
├── 📁 flutter_app/             # Mobile application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── services/
│   └── pubspec.yaml
│
└── 📁 docs/
    ├── EMAIL_SETUP.md          # Email configuration guide
    ├── FLUTTER_OTP_SETUP.md    # Flutter OTP guide
    └── ARCHITECTURE.md         # Technical architecture
```

---


## 🛠️ Technology Stack

### Backend
- **Python 3.8+**: Core application logic
- **Flask**: Web framework and REST API
- **Flask-SocketIO**: Real-time WebSocket communication
- **MongoDB**: User database and OTP storage
- **PyJWT**: JSON Web Token authentication
- **bcrypt**: Password hashing
- **cryptography**: RSA/AES encryption implementation


### Frontend - Mobile
- **Flutter 3.0+**: Cross-platform framework
- **Dart**: Programming language
- **Provider**: State management
- **pointycastle**: Cryptography for Dart
- **http**: REST API client

### Infrastructure
- **TCP Sockets**: Direct P2P connections
- **WebSocket**: Real-time presence
- **SMTP**: Email delivery
- **JSON**: Data serialization

---

## 📚 Documentation

- **[Email Setup Guide](docs/EMAIL_SETUP.md)** - Configure Gmail/SMTP for OTP
- **[Flutter Setup Guide](docs/FLUTTER_OTP_SETUP.md)** - Mobile app configuration
- **[Architecture Deep Dive](docs/ARCHITECTURE.md)** - Technical implementation details
- **[API Documentation](docs/API.md)** - REST endpoints and WebSocket events
---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[Full MIT License text...]
```

---

## 👤 Author

**[Marc]**

- GitHub: [@yourusername](https://github.com/marc-zaki)
- LinkedIn: [Your LinkedIn](https://www.linkedin.com/in/marc-zakii/)
- Email: sherifmark759@gmail.co

---

<div align="center">

**Built with ❤️ for privacy and security**

[⬆ Back to Top](#-secure-p2p-chat-application)

</div>