import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() =>
      _FavoriteScreenState();
}

class _FavoriteScreenState
    extends State<FavoriteScreen> {
  List<String> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs =
        await SharedPreferences.getInstance();

    setState(() {
      _favorites =
          prefs.getStringList(
                'favorite_projects',
              ) ??
              [];
    });
  }

  Future<void> _removeFavorite(
    String title,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    setState(() {
      _favorites.remove(title);
    });

    await prefs.setStringList(
      'favorite_projects',
      _favorites,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7F7),

      appBar: AppBar(
        backgroundColor:
            Colors.white,

        elevation: 0,

        centerTitle: true,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },

          icon: const Icon(
            Icons.close,
            color: Colors.black,
          ),
        ),

        title: const Text(
          '관심 목록',

          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView.separated(
        itemCount: _favorites.length,

        separatorBuilder:
            (_, __) => Divider(
                  height: 1,
                  color:
                      Colors.grey.shade300,
                ),

        itemBuilder: (context, index) {
          final title =
              _favorites[index];

          return Container(
            color: Colors.white,

            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),

            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      const Color(
                    0xFFE9ECFF,
                  ),

                  child: Text(
                    title[0],

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        title,

                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      const Text(
                        '관심 프로젝트',

                        style: TextStyle(
                          color:
                              Color(
                            0xFF7A82F0,
                          ),

                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _removeFavorite(
                          title,
                        );
                      },

                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${index + 1}',

                      style: TextStyle(
                        color:
                            Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}