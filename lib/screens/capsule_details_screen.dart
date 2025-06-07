import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class CapsuleDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> capsule;
  final bool isEditable;

  const CapsuleDetailsScreen({
    Key? key,
    required this.capsule,
    required this.isEditable,
  }) : super(key: key);

  @override
  _CapsuleDetailsScreenState createState() => _CapsuleDetailsScreenState();
}

class _CapsuleDetailsScreenState extends State<CapsuleDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _personalMemoController;
  late TextEditingController _newCommonLetterController;
  final _formKey = GlobalKey<FormState>();

  DateTime? _openDate;
  List<Map<String, dynamic>> _owners = [];
  List<String> _attachedFiles = [];
  List<Map<String, dynamic>> _friendsList = [];
  List<Map<String, dynamic>> _selectedFriends = [];
  List<Map<String, dynamic>> _commonLetters = [];
  Map<String, dynamic>? _personalMemo;
  bool _isLoading = false;
  bool _isFriendsLoading = true;
  bool _hasChanges = false;
  bool _hasPersonalMemo = false;
  bool _isPersonalMemoPrivate = true;
  bool _showNewLetterForm = false;

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
    _initializeData();
    if (widget.isEditable && _isDraft) {
      _loadFriends();
    } else {
      _isFriendsLoading = false;
    }
    _loadMemosAndLetters();
  }

  void _initializeData() {
    _nameController = TextEditingController(text: widget.capsule['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.capsule['description'] ?? '');
    _categoryController = TextEditingController(text: widget.capsule['category'] ?? '');
    _newCommonLetterController = TextEditingController();

    _openDate = widget.capsule['openDate'] is DateTime
        ? widget.capsule['openDate']
        : (widget.capsule['openDate'] as Timestamp?)?.toDate();

    _attachedFiles = List<String>.from(widget.capsule['files'] ?? []);
    _loadOwners();
  }

  bool get _isDraft => widget.capsule['status'] == 'draft';
  bool get _isOpen => _openDate != null && DateTime.now().isAfter(_openDate!);
  bool get _canViewContent => _isDraft || _isOpen;

  // 메모와 편지 로드
  Future<void> _loadMemosAndLetters() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // 개인 메모 로드
      final personalMemoData = widget.capsule['personalMemo'];
      if (personalMemoData != null && personalMemoData is Map<String, dynamic>) {
        setState(() {
          _personalMemo = personalMemoData;
          _hasPersonalMemo = true;
          _isPersonalMemoPrivate = personalMemoData['isPrivate'] ?? true;

          // 편집 가능하고 본인의 메모인 경우에만 컨트롤러에 텍스트 설정
          if (widget.isEditable && personalMemoData['authorId'] == currentUser.uid) {
            _personalMemoController = TextEditingController(text: personalMemoData['content'] ?? '');
          } else {
            _personalMemoController = TextEditingController();
          }
        });
      } else {
        _personalMemoController = TextEditingController();
      }

      // 공통 편지 로드
      final commonLettersData = widget.capsule['commonLetters'];
      if (commonLettersData != null && commonLettersData is List) {
        setState(() {
          _commonLetters = List<Map<String, dynamic>>.from(commonLettersData);
        });
      }
    } catch (e) {
      print('메모 및 편지 로드 실패: $e');
    }
  }

  // 소유주 정보 로드
  Future<void> _loadOwners() async {
    try {
      final ownerEmails = List<String>.from(widget.capsule['owners'] ?? []);
      final pendingEmails = List<String>.from(widget.capsule['pendingOwners'] ?? []);

      List<Map<String, dynamic>> owners = [];

      // 수락된 소유주들
      for (String email in ownerEmails) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          owners.add({
            'uid': userQuery.docs.first.id,
            'name': userData['name']?.toString() ?? '이름 없음',
            'email': email,
            'status': 'accepted',
          });
        }
      }

      // 대기 중인 소유주들
      for (String email in pendingEmails) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          owners.add({
            'uid': userQuery.docs.first.id,
            'name': userData['name']?.toString() ?? '이름 없음',
            'email': email,
            'status': 'pending',
          });
        }
      }

      setState(() {
        _owners = owners;
      });
    } catch (e) {
      debugPrint('소유주 로드 실패: $e');
    }
  }

  // 친구 목록 로드 (편집 모드에서만)
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
          final friendEmail = friendData['email']?.toString() ?? '';

          // 이미 소유주가 아닌 친구들만 추가
          if (!_owners.any((owner) => owner['email'] == friendEmail)) {
            friends.add({
              'uid': friendDoc.id,
              'name': friendData['name']?.toString() ?? '이름 없음',
              'email': friendEmail,
            });
          }
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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _personalMemoController.dispose();
    _newCommonLetterController.dispose();
    super.dispose();
  }

  // 공통 편지 추가
  Future<void> _addCommonLetter() async {
    if (_newCommonLetterController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('편지 내용을 입력해주세요.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userName = userDoc.data()?['name'] ?? '익명';

      final newLetter = {
        'content': _newCommonLetterController.text.trim(),
        'authorId': currentUser.uid,
        'authorName': userName,
        'createdAt': DateTime.now(),
      };

      final updatedLetters = [..._commonLetters, newLetter];

      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsule['id'])
          .update({
        'commonLetters': updatedLetters,
      });

      setState(() {
        _commonLetters = updatedLetters;
        _newCommonLetterController.clear();
        _showNewLetterForm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('편지가 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('편지 추가 실패: $e')),
      );
    }
  }

  // 캡슐 묻기
  Future<void> _buryCapsule() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        title: const Text(
          '캡슐 묻기',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '캡슐을 묻으면 열람일까지 수정할 수 없습니다.\n정말로 묻으시겠습니까?',
          style: TextStyle(color: Color(0xFFD1D5DB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text(
              '묻기',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 개인 메모 데이터 준비
        Map<String, dynamic>? personalMemoData;
        if (_hasPersonalMemo && _personalMemoController.text.trim().isNotEmpty) {
          final currentUser = FirebaseAuth.instance.currentUser;
          personalMemoData = {
            'content': _personalMemoController.text.trim(),
            'isPrivate': _isPersonalMemoPrivate,
            'authorId': currentUser?.uid,
            'createdAt': DateTime.now(),
          };
        }

        // 선택된 친구들을 pendingOwners에 추가
        final newPendingEmails = _selectedFriends.map((f) => f['email'] as String).toList();
        final currentPendingEmails = List<String>.from(widget.capsule['pendingOwners'] ?? []);
        final allPendingEmails = [...currentPendingEmails, ...newPendingEmails].toSet().toList();

        final updateData = {
          'status': 'submitted',
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _categoryController.text.trim(),
          'openDate': _openDate,
          'files': _attachedFiles,
          'pendingOwners': allPendingEmails,
        };

        if (personalMemoData != null) {
          updateData['personalMemo'] = personalMemoData;
        }

        await FirebaseFirestore.instance
            .collection('capsules')
            .doc(widget.capsule['id'])
            .update(updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('캡슐이 성공적으로 묻혔습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('캡슐 묻기 실패: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 변경사항 저장
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updateData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'openDate': _openDate,
        'files': _attachedFiles,
      };

      // 개인 메모 업데이트
      if (_hasPersonalMemo && _personalMemoController.text.trim().isNotEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        updateData['personalMemo'] = {
          'content': _personalMemoController.text.trim(),
          'isPrivate': _isPersonalMemoPrivate,
          'authorId': currentUser?.uid,
          'createdAt': _personalMemo?['createdAt'] ?? DateTime.now(),
        };
      } else if (!_hasPersonalMemo) {
        updateData['personalMemo'] = {};
      }

      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsule['id'])
          .update(updateData);

      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('변경사항이 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 파일 추가
  Future<void> _selectFiles() async {
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
          _hasChanges = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 실패: $e')),
      );
    }
  }

  // 친구 선택 다이얼로그
  void _showFriendSelectionDialog() {
    if (_friendsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가할 수 있는 친구가 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        title: const Text(
          '친구 추가',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _friendsList.length,
            itemBuilder: (context, index) {
              final friend = _friendsList[index];
              final isSelected = _selectedFriends.any((selected) => selected['uid'] == friend['uid']);

              return CheckboxListTile(
                title: Text(
                  friend['name'],
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  friend['email'],
                  style: const TextStyle(color: Color(0xFFD1D5DB)),
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
                    _hasChanges = true;
                  });
                  Navigator.pop(context);
                  _showFriendSelectionDialog();
                },
                activeColor: const Color(0xFF4F46E5),
                checkColor: Colors.white,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '완료',
              style: TextStyle(color: Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );
  }

  // 이미지 미리보기
  void _previewFile(String filePath) {
    final fileExtension = filePath.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.file(File(filePath)),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 파일 형식은 미리보기를 지원하지 않습니다.')),
      );
    }
  }

  // 상태 정보 위젯
  Widget _buildStatusInfo() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_isDraft) {
      statusText = '임시저장';
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.edit;
    } else if (_isOpen) {
      statusText = '열람 가능';
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.celebration;
    } else {
      statusText = '대기중';
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.lock;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 개인 메모 섹션
  Widget _buildPersonalMemoSection() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final canViewMemo = _personalMemo != null &&
        (_personalMemo!['authorId'] == currentUser?.uid ||
            !(_personalMemo!['isPrivate'] ?? true));

    if (!_canViewContent && !_isDraft) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.lock, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 8),
            Text(
              '캡슐이 열리면 개인 메모를 확인할 수 있습니다',
              style: TextStyle(color: const Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note, color: const Color(0xFF8B5CF6), size: 20),
            const SizedBox(width: 8),
            const Text(
              '개인 메모',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (_personalMemo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (_personalMemo!['isPrivate'] ?? true)
                      ? const Color(0xFFEF4444).withOpacity(0.2)
                      : const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (_personalMemo!['isPrivate'] ?? true) ? Icons.lock : Icons.lock_open,
                      size: 12,
                      color: (_personalMemo!['isPrivate'] ?? true)
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (_personalMemo!['isPrivate'] ?? true) ? '비공개' : '공개',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (_personalMemo!['isPrivate'] ?? true)
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (widget.isEditable && _isDraft) ...[
          // 편집 모드
          Row(
            children: [
              Checkbox(
                value: _hasPersonalMemo,
                onChanged: (value) {
                  setState(() {
                    _hasPersonalMemo = value ?? false;
                    _hasChanges = true;
                    if (!_hasPersonalMemo) {
                      _personalMemoController.clear();
                    }
                  });
                },
                activeColor: const Color(0xFF8B5CF6),
              ),
              const Text(
                '개인 메모 작성하기',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          if (_hasPersonalMemo) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              child: TextFormField(
                controller: _personalMemoController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '개인 메모',
                  labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  hintText: '미래의 나에게 전하고 싶은 메시지를 작성하세요...',
                  hintStyle: TextStyle(color: Color(0xFF6B7280)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (value) => setState(() => _hasChanges = true),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPersonalMemoPrivate ? Icons.lock : Icons.lock_open,
                    color: _isPersonalMemoPrivate ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPersonalMemoPrivate ? '비공개 메모' : '공개 메모',
                          style: TextStyle(
                            color: _isPersonalMemoPrivate ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _isPersonalMemoPrivate
                              ? '나만 볼 수 있습니다'
                              : '공동 소유주도 볼 수 있습니다',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: !_isPersonalMemoPrivate,
                    onChanged: (value) {
                      setState(() {
                        _isPersonalMemoPrivate = !value;
                        _hasChanges = true;
                      });
                    },
                    activeColor: const Color(0xFF10B981),
                    inactiveThumbColor: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
          ],
        ] else if (canViewMemo) ...[
          // 읽기 모드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: const Color(0xFF8B5CF6), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _personalMemo!['authorId'] == currentUser?.uid ? '내 메모' : '작성자의 메모',
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_personalMemo!['createdAt'] != null)
                      Text(
                        DateFormat('yyyy.MM.dd').format(
                            _personalMemo!['createdAt'] is DateTime
                                ? _personalMemo!['createdAt']
                                : (_personalMemo!['createdAt'] as Timestamp).toDate()
                        ),
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _personalMemo!['content'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ] else if (_personalMemo != null && !canViewMemo) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4B5563)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: const Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Text(
                  '비공개 메모입니다',
                  style: TextStyle(color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4B5563)),
            ),
            child: Text(
              '작성된 개인 메모가 없습니다',
              style: TextStyle(color: const Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  // 공통 편지 섹션
  Widget _buildCommonLettersSection() {
    if (!_canViewContent && !_isDraft) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.lock, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 8),
            Text(
              '캡슐이 열리면 공통 편지를 확인할 수 있습니다',
              style: TextStyle(color: const Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.mail_outline, color: const Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            const Text(
              '공통 편지',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (_commonLetters.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_commonLetters.length}개',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 기존 편지들 표시
        if (_commonLetters.isNotEmpty) ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _commonLetters.length,
            itemBuilder: (context, index) {
              final letter = _commonLetters[index];
              final isCurrentUserLetter = letter['authorId'] == FirebaseAuth.instance.currentUser?.uid;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrentUserLetter
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentUserLetter
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF4B5563),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF10B981),
                          child: Text(
                            (letter['authorName'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          letter['authorName'] ?? '익명',
                          style: TextStyle(
                            color: isCurrentUserLetter
                                ? const Color(0xFF10B981)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (isCurrentUserLetter) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '내 편지',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (letter['createdAt'] != null)
                          Text(
                            DateFormat('yyyy.MM.dd HH:mm').format(
                                letter['createdAt'] is DateTime
                                    ? letter['createdAt']
                                    : (letter['createdAt'] as Timestamp).toDate()
                            ),
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      letter['content'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4B5563)),
            ),
            child: Text(
              '아직 작성된 공통 편지가 없습니다',
              style: TextStyle(color: const Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 새 편지 작성 (임시저장 상태에서만 가능)
        if (_isDraft && widget.isEditable) ...[
          if (_showNewLetterForm) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: const Color(0xFF10B981), size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        '새 편지 작성',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: const Color(0xFF9CA3AF), size: 16),
                        onPressed: () {
                          setState(() {
                            _showNewLetterForm = false;
                            _newCommonLetterController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newCommonLetterController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: '모두에게 전하고 싶은 메시지를 작성하세요...',
                      hintStyle: TextStyle(color: Color(0xFF6B7280)),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _addCommonLetter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '편지 추가',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showNewLetterForm = true;
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text(
                  '편지 작성하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ] else if (_isOpen) ...[
          // 캡슐이 열린 경우 편지 작성 불가 안내
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6B7280).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: const Color(0xFF6B7280), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '캡슐이 열린 후에는 더 이상 편지를 작성할 수 없습니다',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // 캡슐이 묻힌 상태 (아직 열리지 않음)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: const Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '캡슐이 묻힌 후에는 편지를 작성할 수 없습니다',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 소유주 목록 위젯
  Widget _buildOwnersList() {
    if (_owners.isEmpty && _selectedFriends.isEmpty) {
      return const Text(
        '공동 소유주가 없습니다',
        style: TextStyle(color: Color(0xFF9CA3AF)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기존 소유주들
        ..._owners.map((owner) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: Text(
                    owner['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner['name'],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        owner['email'],
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: owner['status'] == 'accepted'
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    owner['status'] == 'accepted' ? '수락됨' : '대기중',
                    style: TextStyle(
                      color: owner['status'] == 'accepted'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        // 새로 선택된 친구들 (임시저장 상태에서만)
        if (_isDraft && widget.isEditable && _selectedFriends.isNotEmpty) ...[
          ..._selectedFriends.map((friend) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4F46E5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF4F46E5),
                    child: Text(
                      friend['name'][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend['name'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          friend['email'],
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '추가예정',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedFriends.removeWhere((f) => f['uid'] == friend['uid']);
                        _hasChanges = true;
                      });
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  // 파일 목록 위젯
  Widget _buildFileList() {
    if (_attachedFiles.isEmpty) {
      return const Text(
        '첨부된 파일이 없습니다',
        style: TextStyle(color: Color(0xFF9CA3AF)),
      );
    }

    return Column(
      children: _attachedFiles.map((filePath) {
        final fileName = filePath.split('/').last;
        final fileExtension = fileName.split('.').last.toLowerCase();
        final isImage = ['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension);

        return Card(
          color: const Color(0xFF374151),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: isImage
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(filePath),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            )
                : Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileExtension == 'pdf' ? Icons.picture_as_pdf : Icons.insert_drive_file,
                color: Colors.white,
              ),
            ),
            title: Text(
              fileName,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: widget.isEditable && _isDraft
                ? IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  _attachedFiles.remove(filePath);
                  _hasChanges = true;
                });
              },
            )
                : const Icon(Icons.visibility, color: Color(0xFF9CA3AF)),
            onTap: () => _previewFile(filePath),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        title: Text(
          widget.capsule['name'] ?? '캡슐 상세',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        actions: [
          if (widget.isEditable && _isDraft && !_isLoading) ...[
            if (_hasChanges)
              TextButton(
                onPressed: _saveChanges,
                child: const Text(
                  '저장',
                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.archive, color: Color(0xFF4F46E5)),
              onPressed: _buryCapsule,
              tooltip: '캡슐 묻기',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(height: 16),
            Text(
              '처리 중...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 및 날짜 정보
              Row(
                children: [
                  _buildStatusInfo(),
                  const Spacer(),
                  Icon(
                    Icons.schedule,
                    color: const Color(0xFF9CA3AF),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _openDate != null
                        ? DateFormat('yyyy.MM.dd HH:mm').format(_openDate!)
                        : '날짜 미설정',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 캡슐 이름
              const Text(
                '캡슐 이름',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isEditable && _isDraft)
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF374151),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _hasChanges = true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '캡슐 이름을 입력해주세요';
                    }
                    return null;
                  },
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _nameController.text,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              const SizedBox(height: 24),

              // 캡슐 설명
              const Text(
                '설명',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isEditable && _isDraft)
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF374151),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _hasChanges = true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '설명을 입력해주세요';
                    }
                    return null;
                  },
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _descriptionController.text,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              const SizedBox(height: 24),

              // 카테고리
              const Text(
                '카테고리',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isEditable && _isDraft) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _predefinedCategories.map((category) {
                    final isSelected = _categoryController.text == category;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _categoryController.text = category;
                          _hasChanges = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '또는 직접 입력하세요',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFF374151),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _hasChanges = true),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _categoryController.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 24),

              // 열람일
              const Text(
                '열람일',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isEditable && _isDraft)
                GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _openDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now().add(const Duration(hours: 1)),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF4F46E5),
                              onPrimary: Colors.white,
                              surface: Color(0xFF374151),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_openDate ?? DateTime.now()),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF4F46E5),
                                onPrimary: Colors.white,
                                surface: Color(0xFF374151),
                                onSurface: Colors.white,
                              ),
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
                          _hasChanges = true;
                        });
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6B7280)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 12),
                        Text(
                          _openDate != null
                              ? DateFormat('yyyy년 MM월 dd일 HH:mm').format(_openDate!)
                              : '날짜를 선택하세요',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isOpen ? Icons.celebration : Icons.schedule,
                        color: _isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _openDate != null
                            ? DateFormat('yyyy년 MM월 dd일 HH:mm').format(_openDate!)
                            : '날짜 미설정',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // 개인 메모 섹션
              _buildPersonalMemoSection(),
              const SizedBox(height: 24),

              // 공통 편지 섹션
              _buildCommonLettersSection(),
              const SizedBox(height: 24),

              // 공동 소유주
              Row(
                children: [
                  const Text(
                    '공동 소유주',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isEditable && _isDraft && !_isFriendsLoading)
                    TextButton.icon(
                      onPressed: _showFriendSelectionDialog,
                      icon: const Icon(Icons.person_add, color: Color(0xFF4F46E5), size: 16),
                      label: const Text(
                        '친구 추가',
                        style: TextStyle(color: Color(0xFF4F46E5)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isFriendsLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
              else
                _buildOwnersList(),
              const SizedBox(height: 24),

              // 첨부 파일
              Row(
                children: [
                  const Text(
                    '첨부 파일',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isEditable && _isDraft)
                    TextButton.icon(
                      onPressed: _selectFiles,
                      icon: const Icon(Icons.attach_file, color: Color(0xFF4F46E5), size: 16),
                      label: const Text(
                        '파일 추가',
                        style: TextStyle(color: Color(0xFF4F46E5)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFileList(),
              const SizedBox(height: 40),

              // 하단 액션 버튼들
              if (widget.isEditable && _isDraft) ...[
                if (_hasChanges)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '변경사항 저장',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _buryCapsule,
                    icon: const Icon(Icons.archive, color: Colors.white),
                    label: const Text(
                      '캡슐 묻기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else if (_isOpen) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text(
                        '캡슐이 열렸습니다! 추억을 확인해보세요 🎉',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text(
                            '아직 열람일이 되지 않았습니다',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_openDate != null)
                        Text(
                          '${DateFormat('yyyy년 MM월 dd일 HH:mm').format(_openDate!)}에 열립니다',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}