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

class _CapsuleCreateScreenState extends State<CapsuleCreateScreen> {
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
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
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
          SnackBar(content: Text('친구 목록 로드 실패: $e')),
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
        const SnackBar(content: Text('열람일을 선택해주세요.')),
      );
      return;
    }

    if (_openDate!.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('열람일은 현재 시간보다 최소 1시간 이후여야 합니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
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
          const SnackBar(
            content: Text('캡슐이 성공적으로 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('캡슐 생성 실패: $e')),
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
          SnackBar(content: Text('${newFiles.length}개 파일이 추가되었습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 실패: $e')),
      );
    }
  }

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
          '친구 선택',
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
                  });
                  Navigator.pop(context);
                  _showFriendSelectionDialog(); // 다이얼로그 새로고침
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
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    if (_attachedFiles.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '첨부된 파일',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...(_attachedFiles.map((file) {
          final fileName = file.split('/').last;
          final isImage = RegExp(r'\.(jpg|jpeg|png|gif)$', caseSensitive: false).hasMatch(fileName);

          return Card(
            color: const Color(0xFF374151),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: isImage
                  ? GestureDetector(
                onTap: () => _showImagePreview(file),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(file),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file, color: Colors.white),
              ),
              title: Text(
                fileName,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _attachedFiles.remove(file);
                  });
                },
              ),
            ),
          );
        }).toList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('새 캡슐 만들기', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _createCapsule,
              child: const Text(
                '생성',
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
              '캡슐을 생성하고 있습니다...',
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
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '캡슐에 어울리는 이름을 지어주세요',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                ),
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
              const SizedBox(height: 24),

              // 캡슐 설명
              const Text(
                '캡슐 설명',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '이 캡슐에 담긴 의미나 추억을 설명해주세요',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                ),
                maxLines: 3,
                maxLength: 200,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '캡슐 설명을 입력해주세요';
                  }
                  return null;
                },
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '카테고리를 선택하거나 입력해주세요';
                  }
                  return null;
                },
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
              GestureDetector(
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
                      initialTime: const TimeOfDay(hour: 12, minute: 0),
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
                            : '캡슐을 열 날짜와 시간을 선택하세요',
                        style: TextStyle(
                          color: _openDate != null ? Colors.white : const Color(0xFF9CA3AF),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 공동 소유주
              const Text(
                '공동 소유주',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_isFriendsLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                )
              else ...[
                if (_selectedFriends.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedFriends.map((friend) {
                      return Chip(
                        label: Text(friend['name']),
                        backgroundColor: const Color(0xFF4F46E5),
                        labelStyle: const TextStyle(color: Colors.white),
                        deleteIcon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedFriends.removeWhere((f) => f['uid'] == friend['uid']);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: _showFriendSelectionDialog,
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: Text(
                    _selectedFriends.isEmpty ? '친구 추가' : '친구 더 추가',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF374151),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // 파일 첨부
              Row(
                children: [
                  const Text(
                    '파일 첨부',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file, color: Colors.white),
                    label: const Text(
                      '파일 선택',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFileList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}