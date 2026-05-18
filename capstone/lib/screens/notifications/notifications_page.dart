import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> notifications = [];
  bool _loading = true;
  int? userId;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetch();
  }

  Future<void> _loadUserIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('user_id');
    });
    await fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    setState(() => _loading = true);
    try {
      if (userId == null) return;
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/notifications?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          notifications = jsonDecode(response.body);
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("알림")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text("알림이 없습니다."))
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, idx) {
                    final n = notifications[idx];
                    return ListTile(
                      leading: const Icon(Icons.notifications),
                      title: Text(n['title'] ?? ''),
                      subtitle: Text(n['body'] ?? ''),
                      trailing: Text(
                        n['created_at'] != null
                            ? n['created_at'].toString().substring(0, 16)
                            : '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  },
                ),
    );
  }
}
