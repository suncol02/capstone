import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClubEditPage extends StatefulWidget {
  final Map<String, dynamic> club;
  const ClubEditPage({super.key, required this.club});

  @override
  State<ClubEditPage> createState() => _ClubEditPageState();
}

class _ClubEditPageState extends State<ClubEditPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.club['name'] ?? '');
    _descController = TextEditingController(text: widget.club['description'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final response = await http.patch(
      Uri.parse('http://192.168.45.204:5000/clubs/${widget.club['id']}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
      }),
    );
    setState(() => _isLoading = false);
    if (response.statusCode == 200) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('동아리 소개 수정')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '동아리명'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '동아리 소개'),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
          ],
        ),
      ),
    );
  }
}
