import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart';

class OverlayChatBubbleWidget extends StatefulWidget {
  const OverlayChatBubbleWidget({super.key});

  @override
  State<OverlayChatBubbleWidget> createState() => _OverlayChatBubbleWidgetState();
}

class _OverlayChatBubbleWidgetState extends State<OverlayChatBubbleWidget> {
  bool _isExpanded = false;
  String _chatTitle = 'StudyMate Chat';
  String _lastMessage = 'নতুন বার্তা এসেছে...';
  String _chatId = '';
  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    // Listen for data sent from main app
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        setState(() {
          _chatTitle = data['chatTitle']?.toString() ?? _chatTitle;
          _lastMessage = data['lastMessage']?.toString() ?? _lastMessage;
          _chatId = data['chatId']?.toString() ?? _chatId;
          _isGroup = data['isGroup'] == true;
        });
      }
    });
  }

  void _expand() async {
    setState(() => _isExpanded = true);
    await FlutterOverlayWindow.resizeOverlay(330, 420, false);
  }

  void _collapse() async {
    setState(() => _isExpanded = false);
    await FlutterOverlayWindow.resizeOverlay(75, 75, true);
  }

  void _closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _openStudyMateApp() async {
    final uri = Uri.parse('studymate://chat');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching StudyMate app: $e');
    }
    _collapse();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _isExpanded ? _buildExpandedModal() : _buildCompactBubble(),
    );
  }

  Widget _buildCompactBubble() {
    return Center(
      child: GestureDetector(
        onTap: _expand,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.55),
                blurRadius: 14,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: 2.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  _isGroup ? Icons.groups_rounded : Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              // Unread badge dot
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              // Small close icon on bottom-left for quick dismiss
              Positioned(
                bottom: -2,
                left: -2,
                child: GestureDetector(
                  onTap: _closeOverlay,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedModal() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isGroup ? Icons.groups_rounded : Icons.person_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _chatTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'StudyMate Floating Chat',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Minimize button
                IconButton(
                  icon: const Icon(Icons.remove_rounded, color: Colors.white),
                  onPressed: _collapse,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'মিনিমাইজ',
                ),
                const SizedBox(width: 8),
                // Close button
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: _closeOverlay,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'বন্ধ করুন',
                ),
              ],
            ),
          ),

          // Message Preview Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'সর্বশেষ বার্তা:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Text(
                      _lastMessage.isEmpty ? 'কোন বার্তা নেই' : _lastMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _collapse,
                          icon: const Icon(Icons.keyboard_arrow_left_rounded, size: 18),
                          label: const Text('লুকিয়ে রাখুন'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openStudyMateApp,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('অ্যাপ খুলুন'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
