import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'local_notification_service.dart';

class ChatBubbleInfo {
  final String chatId;
  final String chatName;
  final String? photoUrl;
  final String? lastMessage;
  final int unreadCount;
  final bool isGroupChat;
  final String? receiverId;

  const ChatBubbleInfo({
    required this.chatId,
    required this.chatName,
    this.photoUrl,
    this.lastMessage,
    this.unreadCount = 0,
    this.isGroupChat = false,
    this.receiverId,
  });

  ChatBubbleInfo copyWith({
    String? chatId,
    String? chatName,
    String? photoUrl,
    String? lastMessage,
    int? unreadCount,
    bool? isGroupChat,
    String? receiverId,
  }) {
    return ChatBubbleInfo(
      chatId: chatId ?? this.chatId,
      chatName: chatName ?? this.chatName,
      photoUrl: photoUrl ?? this.photoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroupChat: isGroupChat ?? this.isGroupChat,
      receiverId: receiverId ?? this.receiverId,
    );
  }
}

class ChatBubbleService {
  static final ChatBubbleService _instance = ChatBubbleService._internal();
  factory ChatBubbleService() => _instance;
  ChatBubbleService._internal();

  final ValueNotifier<ChatBubbleInfo?> activeBubble = ValueNotifier<ChatBubbleInfo?>(null);
  final ValueNotifier<bool> isExpanded = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isSystemOverlayEnabled = ValueNotifier<bool>(false);

  StreamSubscription<QuerySnapshot>? _chatListenerSub;
  String? _currentUserId;
  DateTime _serviceStartTime = DateTime.now();

  static const String _prefKeyEnabled = 'floating_chat_bubble_enabled';
  static const String _prefKeySystemOverlay = 'system_overlay_bubble_enabled';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isEnabled.value = prefs.getBool(_prefKeyEnabled) ?? true;
    isSystemOverlayEnabled.value = prefs.getBool(_prefKeySystemOverlay) ?? false;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _currentUserId = user.uid;
        _startListeningToIncomingMessages(user.uid);
      } else {
        _currentUserId = null;
        _stopListening();
        hideBubble();
      }
    });
  }

  Future<void> setEnabled(bool enabled) async {
    isEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
    if (!enabled) {
      hideBubble();
    }
  }

  Future<void> setSystemOverlayEnabled(bool enabled) async {
    isSystemOverlayEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySystemOverlay, enabled);
    if (!enabled) {
      await stopSystemOverlayBubble();
    }
  }

  Future<bool> hasSystemOverlayPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestSystemOverlayPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final isGranted = await FlutterOverlayWindow.isPermissionGranted();
      if (!isGranted) {
        return (await FlutterOverlayWindow.requestPermission()) ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
      return false;
    }
  }

  Future<void> startSystemOverlayBubble({
    required String chatTitle,
    required String lastMessage,
    required String chatId,
    String? receiverId,
    bool isGroup = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final isGranted = await FlutterOverlayWindow.isPermissionGranted();
      if (!isGranted) return;

      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: chatTitle,
        overlayContent: lastMessage,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
        positionGravity: PositionGravity.auto,
        height: 75,
        width: 75,
      );

      // Share chat data with the overlay engine
      Future.delayed(const Duration(milliseconds: 350), () {
        FlutterOverlayWindow.shareData({
          'chatTitle': chatTitle,
          'lastMessage': lastMessage,
          'chatId': chatId,
          'receiverId': receiverId,
          'isGroup': isGroup,
        });
      });
    } catch (e) {
      debugPrint('Error starting system overlay bubble: $e');
    }
  }

  Future<void> stopSystemOverlayBubble() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint('Error stopping system overlay bubble: $e');
    }
  }

  void showBubble({
    required String chatId,
    required String chatName,
    String? photoUrl,
    String? lastMessage,
    int unreadCount = 1,
    bool isGroupChat = false,
    String? receiverId,
  }) {
    if (!isEnabled.value) return;

    activeBubble.value = ChatBubbleInfo(
      chatId: chatId,
      chatName: chatName,
      photoUrl: photoUrl,
      lastMessage: lastMessage,
      unreadCount: unreadCount,
      isGroupChat: isGroupChat,
      receiverId: receiverId,
    );
  }

  void toggleExpand() {
    isExpanded.value = !isExpanded.value;
  }

  void expand() {
    isExpanded.value = true;
  }

  void collapse() {
    isExpanded.value = false;
  }

  void hideBubble() {
    activeBubble.value = null;
    isExpanded.value = false;
    stopSystemOverlayBubble();
  }

  void _startListeningToIncomingMessages(String userId) {
    _chatListenerSub?.cancel();
    _serviceStartTime = DateTime.now();

    _chatListenerSub = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified ||
              change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final lastTimestamp = data['lastMessageTimestamp'] as Timestamp?;
            if (lastTimestamp != null &&
                lastTimestamp.toDate().isAfter(_serviceStartTime.subtract(const Duration(seconds: 10)))) {
              final String chatId = change.doc.id;
              final String lastMsg = data['lastMessage'] ?? '';
              final bool isGroup = data['isGroup'] ?? false;
              String chatTitle = data['groupName'] ?? 'Study Friend';

              // Unread count for current user
              final Map<String, dynamic> unreadMap = data['unreadCount'] ?? {};
              final int unreadCount = (unreadMap[userId] as num? ?? 0).toInt();

              // If unread > 0, trigger notifications and bubble
              if (unreadCount > 0 && lastMsg.isNotEmpty) {
                _handleIncomingMessage(
                  chatId: chatId,
                  chatTitle: chatTitle,
                  lastMessage: lastMsg,
                  unreadCount: unreadCount,
                  isGroup: isGroup,
                  data: data,
                );
              }
            }
          }
        }
      },
      onError: (err) {
        debugPrint('ChatBubbleService listener error: $err');
      },
    );
  }

  void _handleIncomingMessage({
    required String chatId,
    required String chatTitle,
    required String lastMessage,
    required int unreadCount,
    required bool isGroup,
    required Map<String, dynamic> data,
  }) async {
    String? photoUrl = data['groupPhoto'] ?? data['photoUrl'];
    String? receiverId;

    if (!isGroup) {
      final participants = List<String>.from(data['participants'] ?? []);
      receiverId = participants.firstWhere(
        (p) => p != _currentUserId,
        orElse: () => '',
      );
    }

    // 1. Show / Update in-app floating bubble if enabled
    if (isEnabled.value) {
      showBubble(
        chatId: chatId,
        chatName: chatTitle,
        photoUrl: photoUrl,
        lastMessage: lastMessage,
        unreadCount: unreadCount,
        isGroupChat: isGroup,
        receiverId: receiverId,
      );
    }

    // 2. Show System Overlay Bubble outside the app if enabled
    if (isSystemOverlayEnabled.value) {
      startSystemOverlayBubble(
        chatTitle: chatTitle,
        lastMessage: lastMessage,
        chatId: chatId,
        receiverId: receiverId,
        isGroup: isGroup,
      );
    }

    // 3. Trigger Android Direct-Reply Notification
    try {
      await LocalNotificationService.showChatNotificationWithDirectReply(
        chatId: chatId,
        senderName: chatTitle,
        messageText: lastMessage,
        unreadCount: unreadCount,
      );
    } catch (e) {
      debugPrint('Error triggering direct reply notification: $e');
    }
  }

  void _stopListening() {
    _chatListenerSub?.cancel();
    _chatListenerSub = null;
  }
}
