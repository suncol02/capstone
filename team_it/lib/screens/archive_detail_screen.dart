import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class ArchiveDetailScreen extends StatefulWidget {
  final Map<String, dynamic> activity;

  const ArchiveDetailScreen({super.key, required this.activity});

  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  String _major = '정보 없음';
  List<dynamic> _tags = [];
  final ImagePicker _picker = ImagePicker();
  List<String> _evidence = [];
  bool _isUploading = false;
  List<Map<String, dynamic>> _links = [];
  final TextEditingController _linkController = TextEditingController();
  bool _isSubmittingLink = false;

  @override
  void initState() {
    super.initState();
    _loadUserMajor();
    _loadTags();
    _loadEvidenceFromActivity();
    _loadLinksFromActivity();
  }

  void _loadLinksFromActivity() {
    final activity = widget.activity;
    final links = <Map<String, dynamic>>[];
    if (activity.containsKey('links') && activity['links'] != null) {
      final v = activity['links'];
      if (v is List) {
        for (final e in v) {
          if (e is Map<String, dynamic>) links.add(e);
          if (e is String) links.add({'url': e});
        }
      }
    }
    setState(() => _links = links);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('링크를 열 수 없습니다: $url')));
    }
  }

  void _loadEvidenceFromActivity() {
    final activity = widget.activity;
    final files = <String>[];

    if (activity.containsKey('image') && activity['image'] != null) {
      final v = activity['image'];
      if (v is String && v.isNotEmpty) files.add(v);
      if (v is List) files.addAll(v.map((e) => e.toString()));
    }
    if (activity.containsKey('file') && activity['file'] != null) {
      final v = activity['file'];
      if (v is String && v.isNotEmpty) files.add(v);
      if (v is List) files.addAll(v.map((e) => e.toString()));
    }
    if (activity.containsKey('evidence') && activity['evidence'] != null) {
      final v = activity['evidence'];
      if (v is List) files.addAll(v.map((e) => e.toString()));
    }

    setState(() {
      _evidence = files;
    });
  }

  // ── 바텀시트: 이미지 / 카메라 / 파일 선택 ──
  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('앨범에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadEvidence(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadEvidence(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('파일 선택 (PDF, 문서 등)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 이미지 업로드 (기존) ──
  Future<void> _pickAndUploadEvidence(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;

      setState(() => _isUploading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증 정보가 없습니다.')));
        setState(() => _isUploading = false);
        return;
      }

      final archiveId = widget.activity['id'] ?? widget.activity['pk'] ?? widget.activity['archive_id'];

      final endpoint = archiveId != null
          ? Uri.parse('$API_BASE_URL/archives/$archiveId/add_evidence/')
          : Uri.parse('$API_BASE_URL/archives/');

      final request = http.MultipartRequest('POST', endpoint)..headers['Authorization'] = 'Token $token';
      request.files.add(await http.MultipartFile.fromPath('file', picked.path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        String? newUrl;
        if (decoded is Map) {
          newUrl = decoded['file'] ?? decoded['image'] ?? decoded['url'] ?? decoded['file_url'];
        }
        if (newUrl != null) {
          setState(() => _evidence.insert(0, newUrl!));
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('증빙 업로드 성공')));
      } else {
        debugPrint('[ERROR] 증빙 업로드 실패: ${response.statusCode} / ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('업로드 실패 (${response.statusCode})')));
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      debugPrint('[ERROR] 증빙 업로드 중 예외: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('업로드 중 오류 발생: $e')));
    }
  }

  // ── 일반 파일 업로드 (신규) ──
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.single;
      if (pickedFile.path == null) return;

      setState(() => _isUploading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증 정보가 없습니다.')));
        setState(() => _isUploading = false);
        return;
      }

      final archiveId = widget.activity['id'] ?? widget.activity['pk'] ?? widget.activity['archive_id'];

      final endpoint = archiveId != null
          ? Uri.parse('$API_BASE_URL/archives/$archiveId/add_evidence/')
          : Uri.parse('$API_BASE_URL/archives/');

      final request = http.MultipartRequest('POST', endpoint)..headers['Authorization'] = 'Token $token';
      request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path!, filename: pickedFile.name));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        String? newUrl;
        if (decoded is Map) {
          newUrl = decoded['file'] ?? decoded['image'] ?? decoded['url'] ?? decoded['file_url'];
        }
        if (newUrl != null) {
          setState(() => _evidence.insert(0, newUrl!));
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('파일 업로드 성공')));
      } else {
        debugPrint('[ERROR] 파일 업로드 실패: ${response.statusCode} / ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('업로드 실패 (${response.statusCode})')));
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      debugPrint('[ERROR] 파일 업로드 중 예외: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('업로드 중 오류 발생: $e')));
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submitLink() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) return;

    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('http:// 또는 https://로 시작하는 URL을 입력하세요')));
      return;
    }

    setState(() => _isSubmittingLink = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증 정보가 없습니다.')));
        setState(() => _isSubmittingLink = false);
        return;
      }

      final archiveId = widget.activity['id'] ?? widget.activity['pk'] ?? widget.activity['archive_id'];

      final endpoint = archiveId != null
          ? Uri.parse('$API_BASE_URL/archives/$archiveId/add_link/')
          : Uri.parse('$API_BASE_URL/archives/');

      final response = await http
          .post(
            endpoint,
            headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'url': link}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => _isSubmittingLink = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final newLink = decoded is Map<String, dynamic> ? decoded : {'url': link};
        setState(() {
          _links.insert(0, newLink);
          _linkController.clear();
        });
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크 등록 성공')));
      } else {
        debugPrint('[ERROR] 링크 등록 실패: ${response.statusCode} / ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('링크 등록 실패 (${response.statusCode})')));
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmittingLink = false);
      debugPrint('[ERROR] 링크 등록 중 예외: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
  }

  Future<void> _loadUserMajor() async {
    final prefs = await SharedPreferences.getInstance();
    final majorData = prefs.getString('user_major') ?? '';
    if (mounted) {
      setState(() {
        _major = majorData.trim().isNotEmpty ? majorData.trim() : '정보 없음';
      });
    }
  }

  Future<void> _loadTags() async {
    final projectDetail = widget.activity['project_detail'] as Map<String, dynamic>?;
    final projectId = projectDetail?['id'] ?? widget.activity['project'];
    if (projectId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$API_BASE_URL/projects/$projectId/my_tags/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200 && mounted) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _tags = data['tags'] ?? [];
      });
    }
  }

  // ── 파일 타입 판별 헬퍼 ──
  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    // 주소창에 확장자 이름이 들어가 있거나 'image'라는 단어가 포함되면 이미지로 간주합니다.
    return lowerUrl.contains('.png') ||
        lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp') ||
        lowerUrl.contains('image');
  }

  bool _isPdfUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.pdf') || lowerUrl.contains('pdf');
  }

  String _fileNameFromUrl(String url) {
    try {
      final decodedUrl = Uri.decodeFull(url); // 한글 파일명이 깨지지 않도록 디코딩
      final name = Uri.tryParse(decodedUrl)?.pathSegments.lastOrNull ?? decodedUrl;
      return name.length > 20 ? '...${name.substring(name.length - 15)}' : name;
    } catch (_) {
      return url.split('/').last;
    }
  }

  IconData _fileIcon(String url) {
    final ext = url.toLowerCase().split('.').last.split('?').first;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _fileIconColor(String url) {
    final ext = url.toLowerCase().split('.').last.split('?').first;
    switch (ext) {
      case 'pdf':
        return Colors.red.shade400;
      case 'doc':
      case 'docx':
        return Colors.blue.shade400;
      case 'xls':
      case 'xlsx':
        return Colors.green.shade500;
      case 'ppt':
      case 'pptx':
        return Colors.orange.shade400;
      default:
        return const Color(0xFF9B98EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectDetail = widget.activity['project_detail'] as Map<String, dynamic>?;

    final String title =
        projectDetail?['name'] ??
        projectDetail?['title'] ??
        widget.activity['title'] ??
        widget.activity['name'] ??
        '완료 프로젝트';

    final String description = projectDetail?['description'] ?? widget.activity['description'] ?? '상세 설명 정보가 없습니다.';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            // ── 헤더 ──
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0xFFEBEBEB),
                  child: Icon(Icons.emoji_emotions_outlined, size: 28, color: Color(0xFF9B98EB)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(_major, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 프로젝트 상세 설명 ──
            const Text(
              '프로젝트 상세 설명',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
            ),
            const SizedBox(height: 24),

            // ── 획득한 태그 ──
            const Text(
              '획득한 태그',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _tags.isEmpty
                ? const Text('획득한 태그가 없습니다.', style: TextStyle(fontSize: 13, color: Colors.black54))
                : Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: _tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEBEBEB)),
                        ),
                        child: Text(tag.toString(), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 28),

            // ── 증빙 파일 섹션 헤더 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '증빙 파일 또는 링크',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton.icon(
                  onPressed: _isUploading ? null : _showPickOptions,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9B98EB)),
                        )
                      : const Icon(Icons.add, size: 18, color: Color(0xFF9B98EB)),
                  label: Text(
                    _isUploading ? '업로드 중...' : '추가',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF9B98EB)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 증빙 파일 목록 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: _evidence.isEmpty
                  ? GestureDetector(
                      onTap: _isUploading ? null : _showPickOptions,
                      child: const Row(
                        children: [
                          Icon(Icons.upload_file, color: Color(0xFF9B98EB), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('탭하여 증빙 파일을 추가하세요', style: TextStyle(fontSize: 14, color: Colors.black45)),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _evidence.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          // 마지막 = 추가 버튼
                          if (i == _evidence.length) {
                            return GestureDetector(
                              onTap: _isUploading ? null : _showPickOptions,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF9B98EB)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add, color: Color(0xFF9B98EB), size: 28),
                                    SizedBox(height: 4),
                                    Text('추가', style: TextStyle(fontSize: 12, color: Color(0xFF9B98EB))),
                                  ],
                                ),
                              ),
                            );
                          }

                          final url = _evidence[i];
                          final displayUrl = url.startsWith('http') ? url : 'http://team-it.iptime.org:8000$url';
                          final isImage = _isImageUrl(displayUrl);
                          final isPdf = _isPdfUrl(displayUrl);
                          final fileName = _fileNameFromUrl(displayUrl);

                          if (isImage) {
                            // ── 이미지 썸네일 ──
                            return GestureDetector(
                              onTap: () async {
                                await showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        displayUrl,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(height: 80, child: Center(child: Icon(Icons.broken_image))),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  displayUrl,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    width: 110,
                                    height: 110,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // ── 일반 파일 카드 ──
                            return GestureDetector(
                              onTap: () => _launchUrl(displayUrl),
                              child: Container(
                                width: 130,
                                height: 110,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_fileIcon(displayUrl), color: _fileIconColor(displayUrl), size: 36),
                                    const SizedBox(height: 6),
                                    Text(
                                      fileName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('탭하여 열기', style: TextStyle(fontSize: 10, color: Colors.blue.shade300)),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // ── 깃허브 / 외부 링크 섹션 ──
            const Text(
              '깃허브 / 외부 링크',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),

            // 링크 입력 바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Color(0xFF9B98EB), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _linkController,
                      decoration: const InputDecoration(
                        hintText: 'https://github.com/...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.black38),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitLink(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _isSubmittingLink
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9B98EB)),
                        )
                      : GestureDetector(
                          onTap: _submitLink,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9B98EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '등록',
                              style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // 등록된 링크 목록
            if (_links.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._links.map((linkMap) {
                final url = linkMap['url']?.toString() ?? '';
                final id = linkMap['id'];
                final isGithub = url.contains('github.com');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(isGithub ? Icons.code : Icons.link, color: const Color(0xFF9B98EB), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _launchUrl(url),
                          child: Text(
                            url,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9B98EB),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF9B98EB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (id != null) {
                            final prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString('auth_token');
                            final archiveId =
                                widget.activity['id'] ?? widget.activity['pk'] ?? widget.activity['archive_id'];
                            if (token != null && archiveId != null) {
                              await http.delete(
                                Uri.parse('$API_BASE_URL/archives/$archiveId/delete_link/'),
                                headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
                                body: jsonEncode({'link_id': id}),
                              );
                            }
                          }
                          setState(() => _links.remove(linkMap));
                        },
                        child: const Icon(Icons.close, size: 16, color: Colors.black38),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
