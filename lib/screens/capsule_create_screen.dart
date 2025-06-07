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
  final TextEditingController _personalMemoController = TextEditingController();
  final TextEditingController _commonLetterController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _openDate;
  List<String> _attachedFiles = [];
  List<Map<String, dynamic>> _selectedFriends = [];
  List<Map<String, dynamic>> _friendsList = [];
  bool _isLoading = false;
  bool _isFriendsLoading = true;
  bool _hasPersonalMemo = false;
  bool _hasCommonLetter = false;
  bool _isPersonalMemoPrivate = true; // 개인 메모 비공개 여부

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
    _personalMemoController.dispose();
    _commonLetterController.dispose();
    _fadeAnimationController?.dispose();
    _slideAnimationController?.dispose();
    super.dispose();
  }

  // 반응형 디자인을 위한 도우미 메서드들
  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 12.0;
    if (screenWidth < 600) return 16.0;
    return 20.0;
  }

  double _getResponsiveMargin(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 8.0;
    if (screenWidth < 600) return 12.0;
    return 16.0;
  }

  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return baseFontSize * 0.9;
    if (screenWidth < 600) return baseFontSize;
    return baseFontSize * 1.1;
  }

  double _getResponsiveIconSize(BuildContext context, double baseIconSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return baseIconSize * 0.9;
    if (screenWidth < 600) return baseIconSize;
    return baseIconSize * 1.1;
  }

  double _getResponsiveHeight(BuildContext context, double baseHeight) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) return baseHeight * 0.8;
    if (screenHeight < 800) return baseHeight * 0.9;
    return baseHeight;
  }

  EdgeInsets _getResponsiveEdgeInsets(BuildContext context, EdgeInsets baseInsets) {
    final screenWidth = MediaQuery.of(context).size.width;
    final factor = screenWidth < 360 ? 0.8 : screenWidth < 600 ? 0.9 : 1.0;
    return EdgeInsets.fromLTRB(
      baseInsets.left * factor,
      baseInsets.top * factor,
      baseInsets.right * factor,
      baseInsets.bottom * factor,
    );
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
                Icon(Icons.error_outline,
                  color: Colors.white,
                  size: _getResponsiveIconSize(context, 20),
                ),
                SizedBox(width: _getResponsiveMargin(context) * 0.5),
                Expanded(
                  child: Text(
                    '친구 목록 로드 실패: $e',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                    ),
                  ),
                ),
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
          content: Row(
            children: [
              Icon(Icons.warning_amber,
                color: Colors.white,
                size: _getResponsiveIconSize(context, 20),
              ),
              SizedBox(width: _getResponsiveMargin(context) * 0.5),
              Expanded(
                child: Text(
                  '열람일을 선택해주세요.',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
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
          content: Row(
            children: [
              Icon(Icons.warning_amber,
                color: Colors.white,
                size: _getResponsiveIconSize(context, 20),
              ),
              SizedBox(width: _getResponsiveMargin(context) * 0.5),
              Expanded(
                child: Text(
                  '열람일은 현재 시간보다 최소 1시간 이후여야 합니다.',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
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
          content: Row(
            children: [
              Icon(Icons.error_outline,
                color: Colors.white,
                size: _getResponsiveIconSize(context, 20),
              ),
              SizedBox(width: _getResponsiveMargin(context) * 0.5),
              Expanded(
                child: Text(
                  '로그인이 필요합니다.',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
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

    // 개인 메모와 공통 편지 데이터 준비
    Map<String, dynamic> personalMemoData = {};
    Map<String, dynamic> commonLetterData = {};

    if (_hasPersonalMemo && _personalMemoController.text.trim().isNotEmpty) {
      personalMemoData = {
        'content': _personalMemoController.text.trim(),
        'isPrivate': _isPersonalMemoPrivate,
        'authorId': currentUser.uid,
        'createdAt': DateTime.now(),
      };
    }

    if (_hasCommonLetter && _commonLetterController.text.trim().isNotEmpty) {
      // 사용자 이름 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userName = userDoc.data()?['name'] ?? '익명';

      commonLetterData = {
        'content': _commonLetterController.text.trim(),
        'authorId': currentUser.uid,
        'authorName': userName,
        'createdAt': DateTime.now(),
      };
    }

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
      'personalMemo': personalMemoData,
      'commonLetters': commonLetterData.isNotEmpty ? [commonLetterData] : [],
    };

    try {
      final docRef = await FirebaseFirestore.instance.collection('capsules').add(capsule);
      capsule['id'] = docRef.id;

      widget.onCapsuleCreated(capsule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.celebration,
                  color: Colors.white,
                  size: _getResponsiveIconSize(context, 20),
                ),
                SizedBox(width: _getResponsiveMargin(context) * 0.5),
                Expanded(
                  child: Text(
                    '캡슐이 성공적으로 생성되었습니다!',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                    ),
                  ),
                ),
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
                Icon(Icons.error_outline,
                  color: Colors.white,
                  size: _getResponsiveIconSize(context, 20),
                ),
                SizedBox(width: _getResponsiveMargin(context) * 0.5),
                Expanded(
                  child: Text(
                    '캡슐 생성 실패: $e',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                    ),
                  ),
                ),
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
                Icon(Icons.attach_file,
                  color: Colors.white,
                  size: _getResponsiveIconSize(context, 20),
                ),
                SizedBox(width: _getResponsiveMargin(context) * 0.5),
                Expanded(
                  child: Text(
                    '${newFiles.length}개 파일이 추가되었습니다.',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                    ),
                  ),
                ),
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
              Icon(Icons.error_outline,
                color: Colors.white,
                size: _getResponsiveIconSize(context, 20),
              ),
              SizedBox(width: _getResponsiveMargin(context) * 0.5),
              Expanded(
                child: Text(
                  '파일 선택 실패: $e',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
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
          content: Row(
            children: [
              Icon(Icons.info_outline,
                color: Colors.white,
                size: _getResponsiveIconSize(context, 20),
              ),
              SizedBox(width: _getResponsiveMargin(context) * 0.5),
              Expanded(
                child: Text(
                  '추가할 수 있는 친구가 없습니다.',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
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

    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.45; // 화면 높이의 45%

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
              padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.group_add,
                color: Colors.white,
                size: _getResponsiveIconSize(context, 20),
              ),
            ),
            SizedBox(width: _getResponsiveMargin(context)),
            Expanded(
              child: Text(
                '친구 선택',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: _getResponsiveFontSize(context, 18),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: dialogHeight,
          child: ListView.builder(
            itemCount: _friendsList.length,
            itemBuilder: (context, index) {
              final friend = _friendsList[index];
              final isSelected = _selectedFriends.any((selected) => selected['uid'] == friend['uid']);

              return Container(
                margin: EdgeInsets.only(bottom: _getResponsiveMargin(context) * 0.5),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: _getResponsiveFontSize(context, 16),
                    ),
                  ),
                  subtitle: Text(
                    friend['email'],
                    style: TextStyle(
                      color: const Color(0xFFD1D5DB),
                      fontSize: _getResponsiveFontSize(context, 12),
                    ),
                  ),
                  secondary: CircleAvatar(
                    radius: _getResponsiveIconSize(context, 20),
                    backgroundColor: const Color(0xFF4F46E5),
                    child: Text(
                      friend['name'][0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: _getResponsiveFontSize(context, 14),
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
              padding: _getResponsiveEdgeInsets(context,
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '완료',
              style: TextStyle(
                color: const Color(0xFF4F46E5),
                fontWeight: FontWeight.bold,
                fontSize: _getResponsiveFontSize(context, 16),
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
              top: _getResponsivePadding(context),
              right: _getResponsivePadding(context),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: _getResponsiveIconSize(context, 30),
                  ),
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
      margin: EdgeInsets.only(bottom: _getResponsiveMargin(context)),
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
        padding: EdgeInsets.all(_getResponsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: _getResponsiveIconSize(context, 16),
                  ),
                ),
                SizedBox(width: _getResponsiveMargin(context) * 0.5),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: _getResponsiveMargin(context) * 0.75),
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
        style: TextStyle(
          color: Colors.white,
          fontSize: _getResponsiveFontSize(context, 16),
        ),
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: const Color(0xFF9CA3AF),
            fontSize: _getResponsiveFontSize(context, 14),
          ),
          hintStyle: TextStyle(
            color: const Color(0xFF6B7280),
            fontSize: _getResponsiveFontSize(context, 14),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(_getResponsivePadding(context)),
          counterStyle: TextStyle(
            color: const Color(0xFF9CA3AF),
            fontSize: _getResponsiveFontSize(context, 12),
          ),
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
        SizedBox(height: _getResponsiveMargin(context)),
        Text(
          '첨부된 파일 (${_attachedFiles.length}개)',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: _getResponsiveMargin(context) * 0.75),
        ...(_attachedFiles.map((file) {
          final fileName = file.split('/').last;
          final isImage = RegExp(r'\.(jpg|jpeg|png|gif)$', caseSensitive: false).hasMatch(fileName);

          return Container(
            margin: EdgeInsets.only(bottom: _getResponsiveMargin(context) * 0.5),
            padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.75),
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
                  width: _getResponsiveIconSize(context, 40),
                  height: _getResponsiveIconSize(context, 40),
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
                        width: _getResponsiveIconSize(context, 40),
                        height: _getResponsiveIconSize(context, 40),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                      : Icon(
                    Icons.insert_drive_file,
                    color: const Color(0xFF4F46E5),
                    size: _getResponsiveIconSize(context, 24),
                  ),
                ),
                SizedBox(width: _getResponsiveMargin(context) * 0.75),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: _getResponsiveFontSize(context, 14),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isImage ? '이미지' : '파일',
                        style: TextStyle(
                          color: const Color(0xFF9CA3AF),
                          fontSize: _getResponsiveFontSize(context, 12),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: const Color(0xFFEF4444),
                    size: _getResponsiveIconSize(context, 24),
                  ),
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

  Widget _buildPersonalMemoSection() {
    return _buildSectionCard(
      title: '개인 메모',
      icon: Icons.edit_note,
      color: const Color(0xFF8B5CF6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.scale(
                scale: MediaQuery.of(context).size.width < 360 ? 0.9 : 1.0,
                child: Checkbox(
                  value: _hasPersonalMemo,
                  onChanged: (value) {
                    setState(() {
                      _hasPersonalMemo = value ?? false;
                      if (!_hasPersonalMemo) {
                        _personalMemoController.clear();
                      }
                    });
                  },
                  activeColor: const Color(0xFF8B5CF6),
                ),
              ),
              Expanded(
                child: Text(
                  '개인 메모 작성하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: _getResponsiveFontSize(context, 16),
                  ),
                ),
              ),
            ],
          ),
          if (_hasPersonalMemo) ...[
            SizedBox(height: _getResponsiveMargin(context) * 0.75),
            Container(
              padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.75),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF8B5CF6),
                    size: _getResponsiveIconSize(context, 16),
                  ),
                  SizedBox(width: _getResponsiveMargin(context) * 0.5),
                  Expanded(
                    child: Text(
                      '개인 메모는 나만의 특별한 추억이나 감정을 담을 수 있습니다.',
                      style: TextStyle(
                        color: const Color(0xFFD1D5DB),
                        fontSize: _getResponsiveFontSize(context, 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: _getResponsiveMargin(context)),
            _buildTextField(
              controller: _personalMemoController,
              label: '개인 메모',
              hint: '미래의 나에게 전하고 싶은 메시지를 작성하세요...',
              maxLines: 5,
              maxLength: 1000,
              validator: (value) => null, // 선택사항이므로 검증 없음
            ),
            SizedBox(height: _getResponsiveMargin(context)),
            Container(
              padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.75),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4B5563),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPersonalMemoPrivate ? Icons.lock : Icons.lock_open,
                    color: _isPersonalMemoPrivate ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: _getResponsiveIconSize(context, 20),
                  ),
                  SizedBox(width: _getResponsiveMargin(context) * 0.75),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPersonalMemoPrivate ? '비공개 메모' : '공개 메모',
                          style: TextStyle(
                            color: _isPersonalMemoPrivate ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: _getResponsiveFontSize(context, 14),
                          ),
                        ),
                        Text(
                          _isPersonalMemoPrivate
                              ? '나만 볼 수 있습니다'
                              : '공동 소유주도 볼 수 있습니다',
                          style: TextStyle(
                            color: const Color(0xFF9CA3AF),
                            fontSize: _getResponsiveFontSize(context, 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: MediaQuery.of(context).size.width < 360 ? 0.8 : 1.0,
                    child: Switch(
                      value: !_isPersonalMemoPrivate, // 스위치는 공개 여부를 나타냄
                      onChanged: (value) {
                        setState(() {
                          _isPersonalMemoPrivate = !value;
                        });
                      },
                      activeColor: const Color(0xFF10B981),
                      inactiveThumbColor: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommonLetterSection() {
    return _buildSectionCard(
      title: '공통 편지',
      icon: Icons.mail_outline,
      color: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.scale(
                scale: MediaQuery.of(context).size.width < 360 ? 0.9 : 1.0,
                child: Checkbox(
                  value: _hasCommonLetter,
                  onChanged: (value) {
                    setState(() {
                      _hasCommonLetter = value ?? false;
                      if (!_hasCommonLetter) {
                        _commonLetterController.clear();
                      }
                    });
                  },
                  activeColor: const Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: Text(
                  '공통 편지 작성하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: _getResponsiveFontSize(context, 16),
                  ),
                ),
              ),
            ],
          ),
          if (_hasCommonLetter) ...[
            SizedBox(height: _getResponsiveMargin(context) * 0.75),
            Container(
              padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.75),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF10B981),
                    size: _getResponsiveIconSize(context, 16),
                  ),
                  SizedBox(width: _getResponsiveMargin(context) * 0.5),
                  Expanded(
                    child: Text(
                      '공통 편지는 모든 공동 소유주가 함께 보는 메시지입니다.',
                      style: TextStyle(
                        color: const Color(0xFFD1D5DB),
                        fontSize: _getResponsiveFontSize(context, 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: _getResponsiveMargin(context)),
            _buildTextField(
              controller: _commonLetterController,
              label: '공통 편지',
              hint: '모두에게 전하고 싶은 메시지를 작성하세요...',
              maxLines: 5,
              maxLength: 1000,
              validator: (value) => null, // 선택사항이므로 검증 없음
            ),
            SizedBox(height: _getResponsiveMargin(context) * 0.75),
            Container(
              padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.75),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.group,
                    color: const Color(0xFF10B981),
                    size: _getResponsiveIconSize(context, 16),
                  ),
                  SizedBox(width: _getResponsiveMargin(context) * 0.5),
                  Expanded(
                    child: Text(
                      '캡슐이 열리면 모든 공동 소유주가 이 편지를 볼 수 있으며, 추가로 더 많은 편지를 작성할 수 있습니다.',
                      style: TextStyle(
                        color: const Color(0xFF10B981),
                        fontSize: _getResponsiveFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: const Color(0xFF4F46E5),
                strokeWidth: MediaQuery.of(context).size.width < 360 ? 3.0 : 4.0,
              ),
              SizedBox(height: _getResponsiveMargin(context)),
              Text(
                '캡슐을 생성하고 있습니다...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getResponsiveFontSize(context, 16),
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
          expandedHeight: _getResponsiveHeight(context, 95),
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF0F172A),
          leading: const SizedBox(), // 왼쪽 버튼 제거
          actions: [
            Container(
              margin: EdgeInsets.all(_getResponsiveMargin(context) * 0.5),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: _getResponsiveIconSize(context, 24),
                ),
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
              child: SafeArea(
                child: Padding(
                  padding: _getResponsiveEdgeInsets(context,
                      const EdgeInsets.fromLTRB(20, 8, 20, 8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '새 캡슐 만들기 ✨',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: _getResponsiveMargin(context) * 0.05),
                      Flexible(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          ).createShader(bounds),
                          child: Text(
                            '추억을 담아보세요',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 18),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 메인 콘텐츠
        SliverPadding(
          padding: EdgeInsets.all(_getResponsivePadding(context)),
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _predefinedCategories.map((category) {
                              final isSelected = _categoryController.text == category;
                              return Container(
                                margin: EdgeInsets.only(right: _getResponsiveMargin(context) * 0.5),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _categoryController.text = category;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: _getResponsiveEdgeInsets(context,
                                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
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
                                        fontSize: _getResponsiveFontSize(context, 14),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: _getResponsiveMargin(context)),
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
                        padding: EdgeInsets.all(_getResponsivePadding(context)),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4B5563)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: const Color(0xFF4F46E5),
                                size: _getResponsiveIconSize(context, 20),
                              ),
                            ),
                            SizedBox(width: _getResponsiveMargin(context) * 0.75),
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
                                      fontSize: _getResponsiveFontSize(context, 16),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_openDate != null)
                                    Text(
                                      '선택한 시간에 캡슐이 열립니다',
                                      style: TextStyle(
                                        color: const Color(0xFF9CA3AF),
                                        fontSize: _getResponsiveFontSize(context, 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: const Color(0xFF9CA3AF),
                              size: _getResponsiveIconSize(context, 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 개인 메모 섹션 추가
                  _buildPersonalMemoSection(),

                  // 공통 편지 섹션 추가
                  _buildCommonLetterSection(),

                  // 공동 소유주
                  _buildSectionCard(
                    title: '공동 소유주',
                    icon: Icons.group_outlined,
                    color: const Color(0xFF06B6D4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isFriendsLoading)
                          Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF4F46E5),
                              strokeWidth: MediaQuery.of(context).size.width < 360 ? 3.0 : 4.0,
                            ),
                          )
                        else ...[
                          if (_selectedFriends.isNotEmpty) ...[
                            Text(
                              '선택된 친구들 (${_selectedFriends.length}명)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _getResponsiveFontSize(context, 14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: _getResponsiveMargin(context) * 0.75),
                            Wrap(
                              spacing: _getResponsiveMargin(context) * 0.5,
                              runSpacing: _getResponsiveMargin(context) * 0.5,
                              children: _selectedFriends.map((friend) {
                                return Container(
                                  padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.5),
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
                                        radius: _getResponsiveIconSize(context, 12),
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        child: Text(
                                          friend['name'][0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _getResponsiveFontSize(context, 10),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: _getResponsiveMargin(context) * 0.5),
                                      Text(
                                        friend['name'],
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: _getResponsiveFontSize(context, 14),
                                        ),
                                      ),
                                      SizedBox(width: _getResponsiveMargin(context) * 0.25),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedFriends.removeWhere((f) => f['uid'] == friend['uid']);
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(_getResponsiveMargin(context) * 0.125),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: _getResponsiveIconSize(context, 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: _getResponsiveMargin(context)),
                          ],
                          Container(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showFriendSelectionDialog,
                              icon: Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: _getResponsiveIconSize(context, 20),
                              ),
                              label: Text(
                                _selectedFriends.isEmpty ? '친구 추가' : '친구 더 추가',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: _getResponsiveFontSize(context, 16),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                padding: EdgeInsets.symmetric(
                                    vertical: _getResponsiveHeight(context, 16)),
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
                            icon: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: _getResponsiveIconSize(context, 20),
                            ),
                            label: Text(
                              '파일 선택',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: _getResponsiveFontSize(context, 16),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              padding: EdgeInsets.symmetric(
                                  vertical: _getResponsiveHeight(context, 16)),
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

                  SizedBox(height: _getResponsiveMargin(context)),

                  // 최종 생성 버튼
                  Container(
                    width: double.infinity,
                    height: _getResponsiveHeight(context, 56),
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
                      icon: Icon(
                        Icons.celebration,
                        color: Colors.white,
                        size: _getResponsiveIconSize(context, 20),
                      ),
                      label: Text(
                        '캡슐 생성하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _getResponsiveFontSize(context, 16),
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

                  SizedBox(height: _getResponsiveHeight(context, 80)), // FAB와 겹치지 않도록
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}