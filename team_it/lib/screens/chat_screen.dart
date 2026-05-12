import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatScreen extends StatefulWidget {
  final int projectId;
  const ChatScreen({super.key, required this.projectId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late WebSocketChannel channel;
  final TextEditingController controller = TextEditingController();
  final List<String> messages = [];

  @override
  void initState() {
    super.initState();
    // 프로젝트 ID 기반 채팅방 연결
    channel = WebSocketChannel.connect(Uri.parse("ws://team-it.iptime.org/ws/chat/${widget.projectId}/"));

    channel.stream.listen((message) {
      setState(() {
        messages.add(message);
      });
    });
  }

  void sendMessage() {
    if (controller.text.isNotEmpty) {
      channel.sink.add('{"message": "${controller.text}"}');
      controller.clear();
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("채팅방 #${widget.projectId}")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (_, index) => ListTile(title: Text(messages[index])),
            ),
          ),
          Row(
            children: [
              Expanded(child: TextField(controller: controller)),
              IconButton(icon: Icon(Icons.send), onPressed: sendMessage),
            ],
          ),
        ],
      ),
    );
  }
}
