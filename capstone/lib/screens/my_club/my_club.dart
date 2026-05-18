import 'package:flutter/material.dart';

class MyClubPage extends StatelessWidget {
  const MyClubPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 더미 데이터 예시
    final List<Map<String, String>> members = [
      {'name': '나', 'image': ''},
      {'name': '오상희', 'image': 'https://randomuser.me/api/portraits/women/1.jpg'},
      {'name': '박범진', 'image': 'https://randomuser.me/api/portraits/men/2.jpg'},
      {'name': '서재원교수', 'image': 'https://randomuser.me/api/portraits/men/3.jpg'},
      {'name': '오선희', 'image': 'https://randomuser.me/api/portraits/men/4.jpg'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Image.asset('image/profile.png', width: 28, height: 28),
              const SizedBox(width: 8),
              const Text('배재클럽', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Stack(
                children: [
                  Icon(Icons.notifications_none, size: 32),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: const Text('6', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              if (idx == 0) {
                // 내 프로필(+) 버튼
                return Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        color: Colors.white,
                      ),
                      child: const Icon(Icons.add, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 4),
                    const Text('나', style: TextStyle(fontSize: 12)),
                  ],
                );
              }
              return Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: members[idx]['image']!.isNotEmpty
                        ? NetworkImage(members[idx]['image']!)
                        : null,
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(height: 4),
                  Text(members[idx]['name']!, style: const TextStyle(fontSize: 12)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
