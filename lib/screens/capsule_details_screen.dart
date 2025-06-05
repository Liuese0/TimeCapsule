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
  final _formKey = GlobalKey<FormState>();

  DateTime? _openDate;
  List<Map<String, dynamic>> _owners = [];
  List<String> _attachedFiles = [];
  List<Map<String, dynamic>> _friendsList = [];
  List<Map<String, dynamic>> _selectedFriends = [];
  bool _isLoading = false;
  bool _isFriendsLoading = true;
  bool _hasChanges = false;

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
  }

  void _initializeData() {
    _nameController = TextEditingController(text: widget.capsule['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.capsule['description'] ?? '');
    _categoryController = TextEditingController(text: widget.capsule['category'] ?? '');

    _openDate = widget.capsule['openDate'] is DateTime
        ? widget.capsule['openDate']
        : (widget.capsule['openDate'] as Timestamp?)?.toDate();

    _attachedFiles = List<String>.from(widget.capsule['files'] ?? []);
    _loadOwners();
  }

  bool get _isDraft => widget.capsule['status'] == 'draft';
  bool get _isOpen => _openDate != null && DateTime.now().isAfter(_openDate!);

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
    super.dispose();
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
        // 선택된 친구들을 pendingOwners에 추가
        final newPendingEmails = _selectedFriends.map((f) => f['email'] as String).toList();
        final currentPendingEmails = List<String>.from(widget.capsule['pendingOwners'] ?? []);
        final allPendingEmails = [...currentPendingEmails, ...newPendingEmails].toSet().toList();

        await FirebaseFirestore.instance
            .collection('capsules')
            .doc(widget.capsule['id'])
            .update({
          'status': 'submitted',
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _categoryController.text.trim(),
          'openDate': _openDate,
          'files': _attachedFiles,
          'pendingOwners': allPendingEmails,
        });

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
      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsule['id'])
          .update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'openDate': _openDate,
        'files': _attachedFiles,
      });

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