import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class CapsuleCreateScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onCapsuleCreated;

  const CapsuleCreateScreen({super.key, required this.onCapsuleCreated});

  @override
  _CapsuleCreateScreenState createState() => _CapsuleCreateScreenState();
}

class _CapsuleCreateScreenState extends State<CapsuleCreateScreen> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _openDate;
  List<String> _attachedFiles = [];
  List<Map<String, dynamic>> _selectedFriends = [];
  List<Map<String, dynamic>> _friendsList = [];
  bool _isLoading = false;
  bool _isFriendsLoading = true;

  AnimationController? _fadeAnimationController;
  Animation<double>? _fadeAnimation;

  AnimationController? _slideAnimationController;
  Animation<Offset>? _slideAnimation;

  // 미리 정의된 카테고리
  final List<String> _predefinedCategories = [
    '일상',
    '추억',
    '여행',
    '가족',
    '친구',
    '연인',
    '성장',
    '꿈',
    '목표',
    '감사',
    '기타'
  ];

  @override
  void initState() {
    super.initState();
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController!,
      curve: Curves.easeInOut,
    ));

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController!,
      curve: Curves.easeOutCubic,
    ));

    _loadFriends();
    _fadeAnimationController?.forward();
    _slideAnimationController?.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _fadeAnimationController?.dispose();
    _slideAnimationController?.dispose();
    super.dispose();
  }

  // 친구 목록 로드
  Future<void> _loadFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final friendsList = List<String>.from(userDoc.data()?['friends'] ?? []);

      List<Map<String, dynamic>> friends = [];
      for (String friendId in friendsList) {
        final friendDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .get();

        if (friendDoc.exists) {
          final friendData = friendDoc.data()!;
          friends.add({
            'uid': friendDoc.id,
            'name': friendData['name']?.toString() ?? '이름 없음',
            'email': friendData['email']?.toString() ?? '이메일 없음',
          });
        }
      }

      setState(() {
        _friendsList = friends;
        _isFriendsLoading = false;
      });
    } catch (e) {
      setState(() {
        _isFriendsLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('친구 목록 로드 실패: $e'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _createCapsule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_openDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 8),
              Text('열람일을 선택해주세요.'),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_openDate!.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 8),
              Text('열람일은 현재 시간보다 최소 1시간 이후여야 합니다.'),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('로그인이 필요합니다.'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final selectedFriendEmails = _selectedFriends.map((friend) => friend['email'] as String).toList();

    final capsule = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'owners': [], // 수락된 사용자만 추가
      'creatorId': currentUser.uid,
      'category': _categoryController.text.trim(),
      'createdDate': DateTime.now(),
      'openDate': _openDate!,
      'status': 'draft',
      'files': _attachedFiles,
      'pendingOwners': selectedFriendEmails,
    };

    try {
      final docRef = await FirebaseFirestore.instance.collection('capsules').add(capsule);
      capsule['id'] = docRef.id;

      widget.onCapsuleCreated(capsule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.celebration, color: Colors.white),
                SizedBox(width: 8),
                Text('캡슐이 성공적으로 생성되었습니다!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('캡슐 생성 실패: $e'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'txt', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.paths.whereType<String>().toList();
        setState(() {
          _attachedFiles.addAll(newFiles);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.attach_file, color: Colors.white),
                const SizedBox(width: 8),
                Text('${newFiles.length}개 파일이 추가되었습니다.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text('파일 선택 실패: $e'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showFriendSelectionDialog() {
    if (_friendsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('추가할 수 있는 친구가 없습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFF9CA3AF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.group_add,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '친구 선택',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _friendsList.length,
            itemBuilder: (context, index) {
              final friend = _friendsList[index];
              final isSelected = _selectedFriends.any((selected) => selected['uid'] == friend['uid']);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.2) : const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(
                    friend['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    friend['email'],
                    style: const TextStyle(color: Color(0xFFD1D5DB)),
                  ),
                  secondary: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF4F46E5),
                    child: Text(
                      friend['name'][0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        if (!isSelected) {
                          _selectedFriends.add(friend);
                        }
                      } else {
                        _selectedFriends.removeWhere((selected) => selected['uid'] == friend['uid']);
                      }
                    });
                    Navigator.pop(context);
                    _showFriendSelectionDialog(); // 다이얼로그 새로고침
                  },
                  activeColor: const Color(0xFF4F46E5),
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '완료',
              style: TextStyle(
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.file(File(imagePath)),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF374151),
            const Color(0xFF2D3748),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4B5563),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4B5563),
        ),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          hintStyle: const TextStyle(color: Color(0xFF6B7280)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildFileList() {
    if (_attachedFiles.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '첨부된 파일 (${_attachedFiles.length}개)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...(_attachedFiles.map((file) {
          final fileName = file.split('/').last;
          final isImage = RegExp(r'\.(jpg|jpeg|png|gif)$', caseSensitive: false).hasMatch(fileName);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4B5563),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                  ),
                  child: isImage
                      ? GestureDetector(
                    onTap: () => _showImagePreview(file),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(file),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                      : const Icon(Icons.insert_drive_file, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isImage ? '이미지' : '파일',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  onPressed: () {
                    setState(() {
                      _attachedFiles.remove(file);
                    });
                  },
                ),
              ],
            ),
          );
        }).toList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4F46E5)),
              SizedBox(height: 16),
              Text(
                '캡슐을 생성하고 있습니다...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      )
          : _fadeAnimation != null
          ? FadeTransition(
        opacity: _fadeAnimation!,
        child: _slideAnimation != null
            ? SlideTransition(
          position: _slideAnimation!,
          child: _buildMainContent(),
        )
            : _buildMainContent(),
      )
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        // 커스텀 앱바
        SliverAppBar(
          expandedHeight: 95,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF0F172A),
          leading: const SizedBox(), // 왼쪽 버튼 제거
          actions: [
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 58, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '새 캡슐 만들기 ✨',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ).createShader(bounds),
                    child: const Text(
                      '추억을 담아보세요',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 메인 콘텐츠
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 캡슐 이름
                  _buildSectionCard(
                    title: '캡슐 이름',
                    icon: Icons.label_outline,
                    color: const Color(0xFF4F46E5),
                    child: _buildTextField(
                      controller: _nameController,
                      label: '캡슐 이름',
                      hint: '캡슐에 어울리는 이름을 지어주세요',
                      maxLength: 30,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '캡슐 이름을 입력해주세요';
                        }
                        if (value.trim().length < 2) {
                          return '캡슐 이름은 2글자 이상이어야 합니다';
                        }
                        return null;
                      },
                    ),
                  ),

                  // 캡슐 설명
                  _buildSectionCard(
                    title: '캡슐 설명',
                    icon: Icons.description_outlined,
                    color: const Color(0xFF10B981),
                    child: _buildTextField(
                      controller: _descriptionController,
                      label: '캡슐 설명',
                      hint: '이 캡슐에 담긴 의미나 추억을 설명해주세요',
                      maxLines: 3,
                      maxLength: 200,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '캡슐 설명을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ),

                  // 카테고리
                  _buildSectionCard(
                    title: '카테고리',
                    icon: Icons.category_outlined,
                    color: const Color(0xFFEC4899),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _predefinedCategories.map((category) {
                            final isSelected = _categoryController.text == category;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _categoryController.text = category;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                  )
                                      : null,
                                  color: isSelected ? null : const Color(0xFF1F2937),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF4B5563),
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                      : null,
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _categoryController,
                          label: '직접 입력',
                          hint: '또는 직접 카테고리를 입력하세요',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '카테고리를 선택하거나 입력해주세요';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  // 열람일
                  _buildSectionCard(
                    title: '열람일',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFFF59E0B),
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().add(const Duration(hours: 1)),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF4F46E5),
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF2D3748),
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: const Color(0xFF2D3748),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 12, minute: 0),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFF4F46E5),
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF2D3748),
                                    onSurface: Colors.white,
                                  ),
                                  dialogBackgroundColor: const Color(0xFF2D3748),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _openDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4B5563)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_today, color: Color(0xFF4F46E5), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _openDate != null
                                        ? DateFormat('yyyy년 MM월 dd일 HH:mm').format(_openDate!)
                                        : '캡슐을 열 날짜와 시간을 선택하세요',
                                    style: TextStyle(
                                      color: _openDate != null ? Colors.white : const Color(0xFF9CA3AF),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_openDate != null)
                                    Text(
                                      '선택한 시간에 캡슐이 열립니다',
                                      style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Color(0xFF9CA3AF), size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 공동 소유주
                  _buildSectionCard(
                    title: '공동 소유주',
                    icon: Icons.group_outlined,
                    color: const Color(0xFF06B6D4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isFriendsLoading)
                          const Center(
                            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                          )
                        else ...[
                          if (_selectedFriends.isNotEmpty) ...[
                            Text(
                              '선택된 친구들 (${_selectedFriends.length}명)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedFriends.map((friend) {
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        child: Text(
                                          friend['name'][0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        friend['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedFriends.removeWhere((f) => f['uid'] == friend['uid']);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Container(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showFriendSelectionDialog,
                              icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
                              label: Text(
                                _selectedFriends.isEmpty ? '친구 추가' : '친구 더 추가',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 파일 첨부
                  _buildSectionCard(
                    title: '파일 첨부',
                    icon: Icons.attach_file_outlined,
                    color: const Color(0xFFEF4444),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.add, color: Colors.white, size: 20),
                            label: const Text(
                              '파일 선택',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        _buildFileList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 최종 생성 버튼
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _createCapsule,
                      icon: const Icon(Icons.celebration, color: Colors.white, size: 20),
                      label: const Text(
                        '캡슐 생성하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80), // FAB와 겹치지 않도록
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}