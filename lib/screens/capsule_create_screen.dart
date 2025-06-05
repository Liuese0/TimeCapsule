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
  final TextEditingController _ownerInputController = TextEditingController();

  DateTime? _openDate;
  List<String> _attachedFiles = []; // 파일 경로를 저장하는 리스트
  List<String> _owners = []; // 공동 소유주 리스트

  void _createCapsule() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _categoryController.text.isEmpty ||
        _openDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필드를 입력해주세요.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
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
      'pendingOwners': _owners,
    };


    try {
      final docRef =
      await FirebaseFirestore.instance.collection('capsules').add(capsule);
      capsule['id'] = docRef.id; // Firestore 문서 ID 저장
      widget.onCapsuleCreated(capsule);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('캡슐 생성 실패: $e')),
      );
    }
  }

  void _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any, // 모든 파일 유형 선택 가능
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFiles.addAll(result.paths.whereType<String>());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 실패: $e')),
      );
    }
  }

  Widget _buildFileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '첨부된 파일:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._attachedFiles.map((file) {
          final isImage = file.endsWith('.jpg') ||
              file.endsWith('.jpeg') ||
              file.endsWith('.png') ||
              file.endsWith('.gif');
          return ListTile(
            leading: isImage
                ? GestureDetector(
              onTap: () => _showImagePreview(file),
              child: Image.file(
                File(file),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            )
                : const Icon(Icons.insert_drive_file),
            title: Text(file.split('/').last),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  _attachedFiles.remove(file);
                });
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showImagePreview(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캡슐 생성')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '설명'),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('공동 소유주:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _owners
                        .map((owner) => Chip(
                      label: Text(owner),
                      backgroundColor: _owners.contains(owner) ? Colors.black : Colors.grey,
                      onDeleted: () {
                        setState(() {
                          _owners.remove(owner);
                        });
                      },
                    )
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ownerInputController,
                          decoration: const InputDecoration(
                            labelText: '공동 소유주 ID 추가',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final ownerId = _ownerInputController.text.trim();
                          if (ownerId.isNotEmpty && !_owners.contains(ownerId)) {
                            setState(() {
                              _owners.add(ownerId);
                            });
                          }
                          _ownerInputController.clear();
                        },
                      )
                    ],
                  ),
                ],
              ),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('열람일 선택:'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _openDate = pickedDate;
                        });
                      }
                    },
                    child: Text(
                      _openDate != null
                          ? DateFormat('yyyy-MM-dd').format(_openDate!)
                          : '선택 안됨',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickFiles,
                child: const Text('파일 첨부'),
              ),
              if (_attachedFiles.isNotEmpty) _buildFileList(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createCapsule,
                child: const Text('캡슐 생성'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
