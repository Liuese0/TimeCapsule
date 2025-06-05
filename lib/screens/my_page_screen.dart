import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _userCapsules = [];
  List<Map<String, dynamic>> _likedCapsules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserCapsules();
    _loadLikedCapsules();
  }

  // 사용자 정보 로드
  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _userData = userDoc.data();
          _userData!['uid'] = currentUser.uid;
          _userData!['email'] = currentUser.email;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 사용자가 생성한 캡슐 로드
  Future<void> _loadUserCapsules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // orderBy 제거하고 간단한 쿼리 사용
      final capsulesSnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .where('creatorId', isEqualTo: currentUser.uid)
          .get();

      if (!mounted) return;

      List<Map<String, dynamic>> capsules = [];
      for (var doc in capsulesSnapshot.docs) {
        if (!mounted) return;

        final data = doc.data();
        data['id'] = doc.id;

        // Timestamp를 DateTime으로 변환
        if (data['createdDate'] is Timestamp) {
          data['createdDate'] = (data['createdDate'] as Timestamp).toDate();
        }
        if (data['openDate'] is Timestamp) {
          data['openDate'] = (data['openDate'] as Timestamp).toDate();
        }

        capsules.add(data);
      }

      // 메모리에서 정렬
      capsules.sort((a, b) {
        final aDate = a['createdDate'] as DateTime;
        final bDate = b['createdDate'] as DateTime;
        return bDate.compareTo(aDate); // 내림차순 정렬
      });

      if (mounted) {
        setState(() {
          _userCapsules = capsules;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('캡슐 로드 실패: $e')),
        );
      }
    }
  }

  // 좋아요한 캡슐 로드
  Future<void> _loadLikedCapsules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists || !mounted) return;

      final likedCapsuleIds = List<String>.from(userDoc.data()?['like'] ?? []);

      List<Map<String, dynamic>> likedCapsules = [];
      for (String capsuleId in likedCapsuleIds) {
        if (!mounted) return; // 각 루프에서 mounted 체크

        final capsuleDoc = await FirebaseFirestore.instance
            .collection('capsules')
            .doc(capsuleId)
            .get();

        if (capsuleDoc.exists && mounted) {
          final data = capsuleDoc.data()!;
          data['id'] = capsuleDoc.id;

          // Timestamp를 DateTime으로 변환
          if (data['createdDate'] is Timestamp) {
            data['createdDate'] = (data['createdDate'] as Timestamp).toDate();
          }
          if (data['openDate'] is Timestamp) {
            data['openDate'] = (data['openDate'] as Timestamp).toDate();
          }

          // 생성자 이름 가져오기
          if (data['creatorId'] != null && mounted) {
            final creatorDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['creatorId'])
                .get();

            if (creatorDoc.exists && mounted) {
              data['creatorName'] = creatorDoc.data()?['name'] ?? '알 수 없음';
            }
          }

          likedCapsules.add(data);
        }
      }

      if (mounted) {
        setState(() {
          _likedCapsules = likedCapsules;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요 캡슐 로드 실패: $e')),
        );
      }
    }
  }

  // 프로필 편집 다이얼로그
  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _userData?['name'] ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        title: const Text(
          '프로필 편집',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '이름',
                labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
              });
            },
            child: const Text(
              '저장',
              style: TextStyle(color: Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateProfile(result);
    }
  }

  // 프로필 업데이트
  Future<void> _updateProfile(Map<String, String> newData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(newData);

      setState(() {
        _userData!.addAll(newData);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 업데이트 실패: $e')),
      );
    }
  }

  // 비밀번호 변경 다이얼로그
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        title: const Text(
          '비밀번호 변경',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '현재 비밀번호',
                labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '새 비밀번호',
                labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '새 비밀번호 확인',
                labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')),
                );
                return;
              }
              Navigator.pop(context, {
                'current': currentPasswordController.text,
                'new': newPasswordController.text,
              });
            },
            child: const Text(
              '변경',
              style: TextStyle(color: Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _changePassword(result['current']!, result['new']!);
    }
  }

  // 비밀번호 변경
  Future<void> _changePassword(String currentPassword, String newPassword) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      await currentUser.reauthenticateWithCredential(credential);

      // 새 비밀번호로 변경
      await currentUser.updatePassword(newPassword);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호 변경 실패: $e')),
      );
    }
  }

  // 로그아웃
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        title: const Text(
          '로그아웃',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '정말로 로그아웃하시겠습니까?',
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  // 계정 삭제
  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        title: const Text(
          '계정 삭제',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.\n계속하려면 비밀번호를 입력하세요.',
              style: TextStyle(color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '비밀번호',
                labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text(
              '삭제',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (password != null && password.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      try {
        // 재인증
        final credential = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: password,
        );

        await currentUser.reauthenticateWithCredential(credential);

        // Firestore에서 사용자 데이터 삭제
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .delete();

        // 계정 삭제
        await currentUser.delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정이 삭제되었습니다.')),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('계정 삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1F2937),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF1F2937),
        body: Column(
          children: [
            // 고정 헤더
            Container(
              color: const Color(0xFF1F2937),
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF4F46E5),
                    child: Text(
                      (_userData?['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userData?['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _userData?['email'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFD1D5DB),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: const Color(0xFF374151),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit_profile',
                        child: const Text(
                          '프로필 편집',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: _showEditProfileDialog,
                      ),
                      PopupMenuItem(
                        value: 'change_password',
                        child: const Text(
                          '비밀번호 변경',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: _showChangePasswordDialog,
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: _logout,
                      ),
                      PopupMenuItem(
                        value: 'delete_account',
                        child: const Text(
                          '계정 삭제',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 탭바
            Container(
              color: const Color(0xFF1F2937),
              child: const TabBar(
                labelColor: Color(0xFF4F46E5),
                unselectedLabelColor: Color(0xFF9CA3AF),
                indicatorColor: Color(0xFF4F46E5),
                tabs: [
                  Tab(text: '통계'),
                  Tab(text: '내 캡슐'),
                  Tab(text: '좋아요'),
                ],
              ),
            ),
            // 탭 내용
            Expanded(
              child: TabBarView(
                children: [
                  _buildStatsTab(),
                  _buildMyCapsulesTab(),
                  _buildLikedCapsulesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    final now = DateTime.now();
    final totalCapsules = _userCapsules.length;
    final draftCapsules = _userCapsules.where((c) => c['status'] == 'draft').length;
    final submittedCapsules = _userCapsules.where((c) => c['status'] == 'submitted').length;
    final openedCapsules = _userCapsules.where((c) {
      final openDate = c['openDate'] as DateTime;
      return openDate.isBefore(now) && c['status'] != 'draft';
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0), // 16에서 12로 줄임
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '캡슐 통계',
            style: TextStyle(
              fontSize: 18, // 20에서 18로 줄임
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16), // 20에서 16으로 줄임
          _buildStatCard('전체 캡슐', totalCapsules.toString(), Icons.archive, const Color(0xFF4F46E5)),
          const SizedBox(height: 10), // 12에서 10으로 줄임
          _buildStatCard('임시저장', draftCapsules.toString(), Icons.edit, const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          _buildStatCard('묻힌 캡슐', submittedCapsules.toString(), Icons.lock, const Color(0xFFEF4444)),
          const SizedBox(height: 10),
          _buildStatCard('열린 캡슐', openedCapsules.toString(), Icons.celebration, const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _buildStatCard('좋아요한 캡슐', _likedCapsules.length.toString(), Icons.favorite, const Color(0xFFEC4899)),
          const SizedBox(height: 20), // 여유 공간 추가
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10), // 12에서 10으로 줄임
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(10), // 12에서 10으로 줄임
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // 8에서 6으로 줄임
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6), // 8에서 6으로 줄임
            ),
            child: Icon(icon, color: color, size: 18), // 20에서 18로 줄임
          ),
          const SizedBox(width: 10), // 12에서 10으로 줄임
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11, // 12에서 11로 줄임
                    color: Color(0xFFD1D5DB),
                  ),
                ),
                const SizedBox(height: 1), // 2에서 1로 줄임
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 18, // 20에서 18로 줄임
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCapsulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '내가 만든 캡슐 (${_userCapsules.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _userCapsules.isEmpty
              ? const SizedBox(
            height: 200,
            child: Center(
              child: Text(
                '아직 생성한 캡슐이 없습니다.',
                style: TextStyle(color: Color(0xFFD1D5DB)),
              ),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userCapsules.length,
            itemBuilder: (context, index) {
              final capsule = _userCapsules[index];
              final now = DateTime.now();
              final openDate = capsule['openDate'] as DateTime;
              final status = capsule['status'];

              IconData statusIcon;
              Color statusColor;
              String statusText;

              if (status == 'draft') {
                statusIcon = Icons.edit;
                statusColor = const Color(0xFFF59E0B);
                statusText = '임시저장';
              } else if (openDate.isAfter(now)) {
                statusIcon = Icons.lock;
                statusColor = const Color(0xFFEF4444);
                statusText = '대기중';
              } else {
                statusIcon = Icons.celebration;
                statusColor = const Color(0xFF10B981);
                statusText = '열림';
              }

              return Card(
                color: const Color(0xFF374151),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(statusIcon, color: statusColor),
                  title: Text(
                    capsule['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        capsule['description'] ?? '',
                        style: const TextStyle(color: Color(0xFFD1D5DB)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '생성일: ${DateFormat('yyyy-MM-dd').format(capsule['createdDate'])}',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                      Text(
                        '열람일: ${DateFormat('yyyy-MM-dd').format(openDate)}',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLikedCapsulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '좋아요한 캡슐 (${_likedCapsules.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _likedCapsules.isEmpty
              ? const SizedBox(
            height: 200,
            child: Center(
              child: Text(
                '좋아요한 캡슐이 없습니다.',
                style: TextStyle(color: Color(0xFFD1D5DB)),
              ),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _likedCapsules.length,
            itemBuilder: (context, index) {
              final capsule = _likedCapsules[index];
              final now = DateTime.now();
              final openDate = capsule['openDate'] as DateTime;
              final status = capsule['status'];

              IconData statusIcon;
              Color statusColor;
              String statusText;

              if (status == 'draft') {
                statusIcon = Icons.edit;
                statusColor = const Color(0xFDF59E0B);
                statusText = '임시저장';
              } else if (openDate.isAfter(now)) {
                statusIcon = Icons.lock;
                statusColor = const Color(0xFFEF4444);
                statusText = '대기중';
              } else {
                statusIcon = Icons.celebration;
                statusColor = const Color(0xFF10B981);
                statusText = '열림';
              }

              return Card(
                color: const Color(0xFF374151),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(statusIcon, color: statusColor),
                  title: Text(
                    capsule['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'by ${capsule['creatorName'] ?? '알 수 없음'}',
                        style: const TextStyle(color: Color(0xFFD1D5DB)),
                      ),
                      Text(
                        '생성일: ${DateFormat('yyyy-MM-dd').format(capsule['createdDate'])}',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                      Text(
                        '열람일: ${DateFormat('yyyy-MM-dd').format(openDate)}',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite, color: Color(0xFFEC4899)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}