import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _userCapsules = [];
  List<Map<String, dynamic>> _likedCapsules = [];
  bool _isLoading = true;

  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

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
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _loadUserData();
    _loadUserCapsules();
    _loadLikedCapsules();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    super.dispose();
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
        _fadeAnimationController.forward();
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

        if (data['createdDate'] is Timestamp) {
          data['createdDate'] = (data['createdDate'] as Timestamp).toDate();
        }
        if (data['openDate'] is Timestamp) {
          data['openDate'] = (data['openDate'] as Timestamp).toDate();
        }

        capsules.add(data);
      }

      capsules.sort((a, b) {
        final aDate = a['createdDate'] as DateTime;
        final bDate = b['createdDate'] as DateTime;
        return bDate.compareTo(aDate);
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
        if (!mounted) return;

        final capsuleDoc = await FirebaseFirestore.instance
            .collection('capsules')
            .doc(capsuleId)
            .get();

        if (capsuleDoc.exists && mounted) {
          final data = capsuleDoc.data()!;
          data['id'] = capsuleDoc.id;

          if (data['createdDate'] is Timestamp) {
            data['createdDate'] = (data['createdDate'] as Timestamp).toDate();
          }
          if (data['openDate'] is Timestamp) {
            data['openDate'] = (data['openDate'] as Timestamp).toDate();
          }

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final nameController = TextEditingController(text: _userData?['name'] ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.edit,
                color: Colors.white,
                size: isSmallScreen ? 16 : 20,
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: Text(
                '프로필 편집',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4B5563),
                ),
              ),
              child: TextField(
                controller: nameController,
                style: TextStyle(color: Colors.white, fontSize: isSmallScreen ? 13 : 16),
                decoration: InputDecoration(
                  labelText: '이름',
                  labelStyle: TextStyle(color: const Color(0xFF9CA3AF), fontSize: isSmallScreen ? 12 : 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: const Color(0xFF9CA3AF),
                    size: isSmallScreen ? 18 : 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 20,
                  vertical: isSmallScreen ? 6 : 10
              ),
            ),
            child: Text(
              '취소',
              style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: isSmallScreen ? 12 : 14
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 20,
                  vertical: isSmallScreen ? 6 : 10
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              '저장',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 12 : 14,
              ),
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('프로필이 업데이트되었습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 업데이트 실패: $e')),
      );
    }
  }

  // 비밀번호 변경 다이얼로그
  Future<void> _showChangePasswordDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: isSmallScreen ? 16 : 20,
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: Text(
                '비밀번호 변경',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField(currentPasswordController, '현재 비밀번호', Icons.lock_outline),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildPasswordField(newPasswordController, '새 비밀번호', Icons.lock_reset),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildPasswordField(confirmPasswordController, '새 비밀번호 확인', Icons.lock_open),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: isSmallScreen ? 12 : 14
              ),
            ),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              '변경',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _changePassword(result['current']!, result['new']!);
    }
  }

  Widget _buildPasswordField(TextEditingController controller, String label, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4B5563),
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.white, fontSize: isSmallScreen ? 13 : 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: const Color(0xFF9CA3AF), fontSize: isSmallScreen ? 12 : 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF9CA3AF),
            size: isSmallScreen ? 18 : 24,
          ),
        ),
        obscureText: true,
      ),
    );
  }

  // 비밀번호 변경
  Future<void> _changePassword(String currentPassword, String newPassword) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.updatePassword(newPassword);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('비밀번호가 변경되었습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
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
        backgroundColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '로그아웃',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '로그아웃',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 자동 로그인 정보 삭제
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('remember_me');
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');

        // Firebase 로그아웃
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
        backgroundColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '계정 삭제',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.\n계속하려면 비밀번호를 입력하세요.',
              style: TextStyle(color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(passwordController, '비밀번호', Icons.lock_outline),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '삭제',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (password != null && password.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      try {
        final credential = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: password,
        );

        await currentUser.reauthenticateWithCredential(credential);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .delete();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: isSmallScreen ? 130 : 150,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
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
                    padding: EdgeInsets.fromLTRB(
                        isSmallScreen ? 12 : 16,
                        isSmallScreen ? 60 : 80,
                        isSmallScreen ? 12 : 16,
                        isSmallScreen ? 12 : 20
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isSmallScreen ? 60 : 80,
                          height: isSmallScreen ? 60 : 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (_userData?['name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 24 : 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 12 : 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                ).createShader(bounds),
                                child: Text(
                                  _userData?['name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 18 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 4 : 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 12,
                                    vertical: isSmallScreen ? 3 : 6
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF374151),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      size: isSmallScreen ? 12 : 16,
                                      color: const Color(0xFF9CA3AF),
                                    ),
                                    SizedBox(width: isSmallScreen ? 3 : 6),
                                    Flexible(
                                      child: Text(
                                        _userData?['email'] ?? '',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: const Color(0xFFD1D5DB),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: PopupMenuButton(
                            icon: Icon(Icons.more_vert,
                                color: Colors.white,
                                size: isSmallScreen ? 18 : 24),
                            color: const Color(0xFF2D3748),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            itemBuilder: (context) => [
                              _buildPopupMenuItem(
                                Icons.edit_outlined,
                                '프로필 편집',
                                const Color(0xFF4F46E5),
                                _showEditProfileDialog,
                              ),
                              _buildPopupMenuItem(
                                Icons.lock_outline,
                                '비밀번호 변경',
                                const Color(0xFFF59E0B),
                                _showChangePasswordDialog,
                              ),
                              _buildPopupMenuItem(
                                Icons.logout,
                                '로그아웃',
                                const Color(0xFF10B981),
                                _logout,
                              ),
                              _buildPopupMenuItem(
                                Icons.delete_forever,
                                '계정 삭제',
                                const Color(0xFFEF4444),
                                _deleteAccount,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  Container(
                    color: const Color(0xFF0F172A),
                    child: Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 4 : 8
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF9CA3AF),
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.analytics_outlined, size: isSmallScreen ? 14 : 18),
                                SizedBox(width: isSmallScreen ? 3 : 6),
                                Text('통계', style: TextStyle(fontSize: isSmallScreen ? 11 : 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.archive_outlined, size: isSmallScreen ? 14 : 18),
                                SizedBox(width: isSmallScreen ? 3 : 6),
                                Text('내 캡슐', style: TextStyle(fontSize: isSmallScreen ? 11 : 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.favorite_outline, size: isSmallScreen ? 14 : 18),
                                SizedBox(width: isSmallScreen ? 3 : 6),
                                Text('좋아요', style: TextStyle(fontSize: isSmallScreen ? 11 : 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
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
      ),
    );
  }

  PopupMenuItem<void> _buildPopupMenuItem(
      IconData icon,
      String text,
      Color color,
      VoidCallback onTap,
      ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return PopupMenuItem(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 2 : 4),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? 12 : 16,
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final now = DateTime.now();
    final totalCapsules = _userCapsules.length;
    final draftCapsules = _userCapsules.where((c) => c['status'] == 'draft').length;
    final submittedCapsules = _userCapsules.where((c) => c['status'] == 'submitted').length;
    final openedCapsules = _userCapsules.where((c) {
      final openDate = c['openDate'] as DateTime;
      return openDate.isBefore(now) && c['status'] != 'draft';
    }).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 캡슐 통계',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 20),
          Row(
            children: [
              _buildStatCard('전체 캡슐', totalCapsules.toString(), Icons.archive_outlined, const Color(0xFF4F46E5)),
              SizedBox(width: isSmallScreen ? 8 : 12),
              _buildStatCard('좋아요한 캡슐', _likedCapsules.length.toString(), Icons.favorite_outline, const Color(0xFFEC4899)),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Row(
            children: [
              _buildStatCard('임시저장', draftCapsules.toString(), Icons.edit_outlined, const Color(0xFFF59E0B)),
              SizedBox(width: isSmallScreen ? 8 : 12),
              _buildStatCard('묻힌 캡슐', submittedCapsules.toString(), Icons.lock_outline, const Color(0xFFEF4444)),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          _buildFullWidthStatCard('열린 캡슐', openedCapsules.toString(), Icons.celebration_outlined, const Color(0xFF10B981)),
          SizedBox(height: isSmallScreen ? 16 : 24),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? 16 : 20,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              count,
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFFD1D5DB),
                fontSize: isSmallScreen ? 9 : 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthStatCard(String title, String count, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: isSmallScreen ? 18 : 24,
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFFD1D5DB),
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF374151),
            const Color(0xFF2D3748),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4B5563),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flash_on,
                  color: Colors.white,
                  size: isSmallScreen ? 16 : 20,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Text(
                '빠른 작업',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  '프로필 편집',
                  Icons.edit_outlined,
                  const Color(0xFF4F46E5),
                  _showEditProfileDialog,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                child: _buildQuickActionButton(
                  '비밀번호 변경',
                  Icons.lock_outline,
                  const Color(0xFFF59E0B),
                  _showChangePasswordDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: isSmallScreen ? 18 : 24,
            ),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCapsulesTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '📦 내가 만든 캡슐',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 3 : 6
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_userCapsules.length}개',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 16),
          _userCapsules.isEmpty
              ? _buildEmptyState(
            Icons.archive_outlined,
            '아직 생성한 캡슐이 없습니다.',
            '첫 번째 추억 캡슐을 만들어보세요!',
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userCapsules.length,
            itemBuilder: (context, index) {
              return _buildCapsuleCard(_userCapsules[index], false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLikedCapsulesTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '❤️ 좋아요한 캡슐',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 3 : 6
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_likedCapsules.length}개',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 16),
          _likedCapsules.isEmpty
              ? _buildEmptyState(
            Icons.favorite_outline,
            '좋아요한 캡슐이 없습니다.',
            '마음에 드는 캡슐에 좋아요를 눌러보세요!',
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _likedCapsules.length,
            itemBuilder: (context, index) {
              return _buildCapsuleCard(_likedCapsules[index], true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 24 : 40),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4B5563),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFF4B5563),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: isSmallScreen ? 32 : 48,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Text(
            subtitle,
            style: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontSize: isSmallScreen ? 11 : 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleCard(Map<String, dynamic> capsule, bool isLiked) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final now = DateTime.now();
    final openDate = capsule['openDate'] as DateTime;
    final status = capsule['status'];

    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (status == 'draft') {
      statusIcon = Icons.edit_outlined;
      statusColor = const Color(0xFFF59E0B);
      statusText = '임시저장';
    } else if (openDate.isAfter(now)) {
      statusIcon = Icons.lock_outline;
      statusColor = const Color(0xFFEF4444);
      statusText = '대기중';
    } else {
      statusIcon = Icons.celebration_outlined;
      statusColor = const Color(0xFF10B981);
      statusText = '열림';
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isSmallScreen ? 32 : 40,
                height: isSmallScreen ? 32 : 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (capsule['name'] ?? 'C')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 12 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capsule['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isLiked && capsule['creatorName'] != null) ...[
                      SizedBox(height: isSmallScreen ? 1 : 2),
                      Text(
                        'by ${capsule['creatorName']}',
                        style: TextStyle(
                          color: const Color(0xFF9CA3AF),
                          fontSize: isSmallScreen ? 10 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8,
                    vertical: isSmallScreen ? 2 : 4
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: isSmallScreen ? 10 : 12),
                    SizedBox(width: isSmallScreen ? 2 : 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: isSmallScreen ? 8 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLiked) ...[
                SizedBox(width: isSmallScreen ? 4 : 8),
                Icon(Icons.favorite,
                    color: const Color(0xFFEC4899),
                    size: isSmallScreen ? 12 : 16),
              ],
            ],
          ),
          if (capsule['description'] != null && capsule['description'].isNotEmpty) ...[
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              capsule['description'],
              style: TextStyle(
                color: const Color(0xFFD1D5DB),
                fontSize: isSmallScreen ? 12 : 14,
              ),
              maxLines: isSmallScreen ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: isSmallScreen ? 8 : 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: isSmallScreen ? 12 : 14,
                color: const Color(0xFF9CA3AF),
              ),
              SizedBox(width: isSmallScreen ? 2 : 4),
              Text(
                '생성: ${DateFormat(isSmallScreen ? 'yy.MM.dd' : 'yyyy.MM.dd').format(capsule['createdDate'])}',
                style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: isSmallScreen ? 10 : 12,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 16),
              Icon(
                Icons.schedule_outlined,
                size: isSmallScreen ? 12 : 14,
                color: const Color(0xFF9CA3AF),
              ),
              SizedBox(width: isSmallScreen ? 2 : 4),
              Expanded(
                child: Text(
                  '열람: ${DateFormat(isSmallScreen ? 'yy.MM.dd' : 'yyyy.MM.dd').format(openDate)}',
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: isSmallScreen ? 10 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverTabBarDelegate(this.child);

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}