import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  DateTime? _openDate;
  List<String> _owners = [];
  List<String> _attachedFiles = [];
  final TextEditingController _newOwnerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.capsule['name']);
    _descriptionController =
        TextEditingController(text: widget.capsule['description']);
    _categoryController =
        TextEditingController(text: widget.capsule['category']);
    _owners = List<String>.from(widget.capsule['owners'] ?? []);
    _openDate = widget.capsule['openDate'];
    _attachedFiles = List<String>.from(widget.capsule['files'] ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _newOwnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = widget.capsule['status'] == 'draft';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.capsule['name']),
        actions: [
          if (isDraft && widget.isEditable)
            IconButton(
              icon: const Icon(Icons.archive),
              onPressed: _buryCapsule,
              tooltip: '캡슐 묻기',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditableField(
              label: '캡슐 이름',
              controller: _nameController,
              editable: isDraft && widget.isEditable,
            ),
            const SizedBox(height: 16),
            _buildEditableField(
              label: '설명',
              controller: _descriptionController,
              editable: isDraft && widget.isEditable,
            ),
            const SizedBox(height: 16),
            _buildOwnersField(isDraft),
            const SizedBox(height: 16),
            _buildEditableField(
              label: '카테고리',
              controller: _categoryController,
              editable: isDraft && widget.isEditable,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '열람일: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (isDraft && widget.isEditable)
                  TextButton(
                    onPressed: _pickOpenDate,
                    child: Text(
                      _openDate != null
                          ? DateFormat('yyyy-MM-dd').format(_openDate!)
                          : '날짜 선택',
                    ),
                  )
                else
                  Text(
                    _openDate != null
                        ? DateFormat('yyyy-MM-dd').format(_openDate!)
                        : '설정되지 않음',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFileList(),
            const SizedBox(height: 16),
            if (isDraft && widget.isEditable)
              ElevatedButton(
                onPressed: _saveChanges,
                child: const Text('저장'),
              ),
          ],
        ),
      ),
    );
  }

  void _buryCapsule() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캡슐 묻기'),
        content: const Text('정말로 캡슐을 묻으시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('capsules')
            .doc(widget.capsule['id'])
            .update({
          'status': 'submitted',
          'files': _attachedFiles,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('캡슐이 묻혔습니다!')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('캡슐 묻기 실패: $e')),
        );
      }
    }
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool editable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        editable
            ? TextField(controller: controller)
            : Text(controller.text),
      ],
    );
  }

  Widget _buildOwnersField(bool isDraft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '공동 소유주:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8.0,
          children: _owners
              .map((owner) => Chip(
            label: Text(owner),
            deleteIcon: isDraft && widget.isEditable
                ? const Icon(Icons.close)
                : null,
            onDeleted: isDraft && widget.isEditable
                ? () {
              setState(() {
                _owners.remove(owner);
              });
            }
                : null,
          ))
              .toList(),
        ),
        if (isDraft && widget.isEditable)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newOwnerController,
                  decoration: const InputDecoration(hintText: '공동 소유주 추가'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_newOwnerController.text.isNotEmpty) {
                    setState(() {
                      _owners.add(_newOwnerController.text.trim());
                      _newOwnerController.clear();
                    });
                  }
                },
              ),
            ],
          ),
      ],
    );
  }

  void _pickOpenDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _openDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _openDate = pickedDate;
        widget.capsule['openDate'] = pickedDate;
      });
    }
  }

  Widget _buildFileList() {
    final isDraft = widget.capsule['status'] == 'draft';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '첨부 파일:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (_attachedFiles.isNotEmpty)
          ..._attachedFiles.map(
                (filePath) {
              final fileName = filePath.split('/').last;
              final fileExtension = fileName.split('.').last.toLowerCase();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: fileExtension == 'jpg' ||
                      fileExtension == 'jpeg' ||
                      fileExtension == 'png'
                      ? Image.file(
                    File(filePath),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                      : Icon(
                    fileExtension == 'pdf'
                        ? Icons.picture_as_pdf
                        : Icons.insert_drive_file,
                    size: 50,
                    color: Colors.blue,
                  ),
                  title: Text(fileName),
                  trailing: isDraft && widget.isEditable
                      ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _attachedFiles.remove(filePath);
                      });
                    },
                  )
                      : null,
                  onTap: () {
                    _previewFile(filePath);
                  },
                ),
              );
            },
          ),
        if (isDraft && widget.isEditable)
          ElevatedButton(
            onPressed: _selectFiles,
            child: const Text('파일 추가'),
          ),
      ],
    );
  }

  Future<void> _selectFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _attachedFiles.addAll(result.paths.whereType<String>());
      });
    }
  }

  void _previewFile(String filePath) {
    final fileExtension = filePath.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Image.file(File(filePath)),
        ),
      );
    } else if (fileExtension == 'pdf') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF 파일 미리보기 기능은 구현되지 않았습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미리보기를 지원하지 않는 파일 형식입니다.')),
      );
    }
  }

  Future<void> _saveChanges() async {
    try {
      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsule['id'])
          .update({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'category': _categoryController.text,
        'openDate': _openDate,
        'owners': _owners,
        'files': _attachedFiles,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경사항이 저장되었습니다.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }
}
