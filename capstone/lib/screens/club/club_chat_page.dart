import 'package:flutter/material.dart';

class ClubChatPage extends StatefulWidget {
  final String clubName;
  const ClubChatPage({super.key, required this.clubName});

  @override
  State<ClubChatPage> createState() => _ClubChatPageState();
}

class _ClubChatPageState extends State<ClubChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'user': '나', 'message': text});
      _controller.clear();
    });
    // TODO: 서버로 메시지 전송 및 수신 구현
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clubName} 채팅방'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[_messages.length - 1 - idx];
                return ListTile(
                  title: Text(msg['user'] ?? ''),
                  subtitle: Text(msg['message'] ?? ''),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
