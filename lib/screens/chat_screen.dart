// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  String? _userContext;

  final List<String> _quickReplies = [
    'Kilo vermek istiyorum',
    'Günlük kalori ihtiyacım nedir?',
    'Protein kaynakları nelerdir?',
    'Sağlıklı kahvaltı önerileri',
    'Diyet yaparken ne yemeliyim?',
    'Su içmenin faydaları nedir?',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserContext();
    _messages.add({
      'role': 'bot',
      'text': 'Merhaba! 🥗 Ben beslenme asistanınım. Kalori, diyet, tarifler veya sağlıklı yaşam hakkında sorularını yanıtlayabilirim.',
    });
  }

  Future<void> _loadUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    final height = prefs.getDouble('height');
    final weight = prefs.getDouble('weight');
    final age = prefs.getInt('age');
    if (height != null && weight != null && age != null) {
      setState(() {
        _userContext = 'Kullanıcı bilgileri: Boy: ${height}cm, Kilo: ${weight}kg, Yaş: $age. Bu bilgileri göz önünde bulundurarak cevap ver.';
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    final answer = await ApiService.chat(text, userContext: _userContext);

    setState(() {
      _messages.add({'role': 'bot', 'text': answer});
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 16,
            child: const Text('🥗', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Beslenme Asistanı',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(_userContext != null ? '● Profilin yüklendi' : '● Çevrimiçi',
                style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {
              _messages.clear();
              _messages.add({'role': 'bot', 'text': 'Sohbet temizlendi. Nasıl yardımcı olabilirim? 🥗'});
            }),
          ),
        ],
      ),
      body: Column(children: [
        // Hızlı cevap butonları
        Container(
          height: 40,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _quickReplies.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _sendMessage(_quickReplies[i]),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Text(_quickReplies[i],
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMid)),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),

        // Mesajlar
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) return _buildTypingIndicator();
              final msg = _messages[i];
              final isUser = msg['role'] == 'user';
              return _buildBubble(msg['text']!, isUser);
            },
          ),
        ),

        // Input alanı
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Mesajınızı yazın...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF0FAF5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.border, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.border, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loading ? null : () => _sendMessage(_controller.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _loading ? Colors.grey[300] : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _loading ? Colors.grey : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary,
              child: const Text('🥗', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: AppTheme.border, width: 0.5),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4, offset: const Offset(0, 2),
                )],
              ),
              child: Text(text, style: TextStyle(
                fontSize: 13,
                color: isUser ? Colors.white : AppTheme.textDark,
                height: 1.5,
              )),
            ),
          ),
          if (isUser) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppTheme.primary,
          child: const Text('🥗', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 600 + i * 200),
                builder: (ctx, val, _) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.3 + val * 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          )),
        ),
      ]),
    );
  }
}