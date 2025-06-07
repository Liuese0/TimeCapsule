import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendPageScreen extends StatefulWidget {
  const FriendPageScreen({super.key});

  @override
  _FriendPageScreenState createState() => _FriendPageScreenState();
}

class _FriendPageScreenState extends State<FriendPageScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  bool _isSearching = false;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFriends();
    _loadFriendRequests();
    _loadSentRequests();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
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
          final cleanedData = <String, dynamic>{
            'uid': friendDoc.id,
            'name': friendData['name']?.toString() ?? '이름 없음',
            'email': friendData['email']?.toString() ?? '이메일 없음',
            'id': friendData['id']?.toString() ?? friendData['email']?.toString() ?? '아이디 없음',
            'status': friendData['status']?.toString() ?? 'unknown',
            'friends': friendData['friends'] ?? [],
            'like': friendData['like'] ?? [],
            'createdAt': friendData['createdAt'],
          };
          friends.add(cleanedData);
        }
      }

      setState(() {
        _friends = friends;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 목록 로드 실패: $e')),
      );
    }
  }

  // 받은 친구 요청 로드
  Future<void> _loadFriendRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('friendRequests')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> requests = [];
      for (var doc in requestsSnapshot.docs) {
        final requestData = doc.data();
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(requestData['senderId'])
            .get();

        if (senderDoc.exists) {
          final senderData = senderDoc.data()!;
          requests.add({
            'requestId': doc.id,
            'senderId': requestData['senderId']?.toString() ?? '',
            'senderName': senderData['name']?.toString() ?? '이름 없음',
            'senderEmail': senderData['email']?.toString() ?? '이메일 없음',
          });
        }
      }

      setState(() {
        _friendRequests = requests;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 요청 로드 실패: $e')),
      );
    }
  }

  // 보낸 친구 요청 로드
  Future<void> _loadSentRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> requests = [];
      for (var doc in requestsSnapshot.docs) {
        final requestData = doc.data();
        final receiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(requestData['receiverId'])
            .get();

        if (receiverDoc.exists) {
          final receiverData = receiverDoc.data()!;
          requests.add({
            'requestId': doc.id,
            'receiverId': requestData['receiverId']?.toString() ?? '',
            'receiverName': receiverData['name']?.toString() ?? '이름 없음',
            'receiverEmail': receiverData['email']?.toString() ?? '이메일 없음',
          });
        }
      }

      setState(() {
        _sentRequests = requests;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보낸 요청 로드 실패: $e')),
      );
    }
  }

  // 사용자 검색
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: query.trim().toLowerCase())
          .get();

      final nameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query.trim())
          .where('name', isLessThan: query.trim() + '\uf8ff')
          .get();

      final allDocs = [...emailQuery.docs, ...nameQuery.docs];
      final uniqueDocs = {for (var doc in allDocs) doc.id: doc}.values.toList();

      List<Map<String, dynamic>> results = [];
      for (var doc in uniqueDocs) {
        if (doc.id != currentUser.uid) {
          final userData = doc.data();
          final cleanedData = <String, dynamic>{
            'uid': doc.id,
            'name': userData['name']?.toString() ?? '이름 없음',
            'email': userData['email']?.toString() ?? '이메일 없음',
            'id': userData['id']?.toString() ?? userData['email']?.toString() ?? '아이디 없음',
            'status': userData['status']?.toString() ?? 'unknown',
            'friends': userData['friends'] ?? [],
            'like': userData['like'] ?? [],
            'createdAt': userData['createdAt'],
          };
          results.add(cleanedData);
        }
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 실패: $e')),
      );
    }
  }

  // 친구 요청 보내기
  Future<void> _sendFriendRequest(String receiverId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final existingRequest = await FirebaseFirestore.instance
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 8),
                Text('이미 친구 요청을 보냈습니다.'),
              ],
            ),
            backgroundColor: const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
      if (friends.contains(receiverId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('이미 친구입니다.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('friendRequests').add({
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.send, color: Colors.white),
              SizedBox(width: 8),
              Text('친구 요청을 보냈습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFF4F46E5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadSentRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 요청 실패: $e')),
      );
    }
  }

  // 친구 요청 수락
  Future<void> _acceptFriendRequest(String requestId, String senderId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final requestRef = FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId);
      batch.update(requestRef, {'status': 'accepted'});

      final currentUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayUnion([senderId])
      });

      final senderRef = FirebaseFirestore.instance
          .collection('users')
          .doc(senderId);
      batch.update(senderRef, {
        'friends': FieldValue.arrayUnion([currentUser.uid])
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('친구 요청을 수락했습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadFriends();
      _loadFriendRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 요청 수락 실패: $e')),
      );
    }
  }

  // 친구 요청 거절
  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .update({'status': 'rejected'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 8),
              Text('친구 요청을 거절했습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadFriendRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 요청 거절 실패: $e')),
      );
    }
  }

  // 친구 삭제
  Future<void> _removeFriend(String friendId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_remove, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('친구 삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('정말로 친구를 삭제하시겠습니까?', style: TextStyle(color: Color(0xFFD1D5DB))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final currentUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayRemove([friendId])
      });

      final friendRef = FirebaseFirestore.instance
          .collection('users')
          .doc(friendId);
      batch.update(friendRef, {
        'friends': FieldValue.arrayRemove([currentUser.uid])
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('친구를 삭제했습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadFriends();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 삭제 실패: $e')),
      );
    }
  }

  // 보낸 요청 취소
  Future<void> _cancelSentRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.white),
              SizedBox(width: 8),
              Text('친구 요청을 취소했습니다.'),
            ],
          ),
          backgroundColor: const Color(0xFF9CA3AF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadSentRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 취소 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    if (_tabController == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: isSmallScreen ? 100 : 120,
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
                      isSmallScreen ? 45 : 60,
                      isSmallScreen ? 12 : 16,
                      isSmallScreen ? 8 : 16
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '친구 관리 👥',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 16,
                                color: const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 1 : 4),
                            Flexible(
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                ).createShader(bounds),
                                child: Text(
                                  '친구',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 20 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      if (_friendRequests.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8 : 12,
                              vertical: isSmallScreen ? 3 : 6
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_active,
                                  color: Colors.white,
                                  size: isSmallScreen ? 12 : 16),
                              SizedBox(width: isSmallScreen ? 2 : 4),
                              Text(
                                '${_friendRequests.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFF0F172A),
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 4 : 8
                ),
                child: Container(
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
                  child: TabBar(
                    controller: _tabController!,
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
                    padding: EdgeInsets.all(isSmallScreen ? 2 : 4),
                    tabs: [
                      Tab(
                        child: Container(
                          height: isSmallScreen ? 50 : 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group, size: isSmallScreen ? 12 : 16),
                              SizedBox(height: isSmallScreen ? 1 : 2),
                              Text('친구', style: TextStyle(fontSize: isSmallScreen ? 8 : 9, fontWeight: FontWeight.w600)),
                              if (_friends.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(top: isSmallScreen ? 0 : 1),
                                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${_friends.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 6 : 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: Container(
                          height: isSmallScreen ? 50 : 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: isSmallScreen ? 12 : 16),
                              SizedBox(height: isSmallScreen ? 1 : 2),
                              Text('검색', style: TextStyle(fontSize: isSmallScreen ? 8 : 9, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: Container(
                          height: isSmallScreen ? 50 : 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox, size: isSmallScreen ? 12 : 16),
                              SizedBox(height: isSmallScreen ? 1 : 2),
                              Text('요청', style: TextStyle(fontSize: isSmallScreen ? 8 : 9, fontWeight: FontWeight.w600)),
                              if (_friendRequests.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(top: isSmallScreen ? 0 : 1),
                                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${_friendRequests.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 6 : 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: Container(
                          height: isSmallScreen ? 50 : 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send, size: isSmallScreen ? 12 : 16),
                              SizedBox(height: isSmallScreen ? 1 : 2),
                              Text('발송', style: TextStyle(fontSize: isSmallScreen ? 8 : 9, fontWeight: FontWeight.w600)),
                              if (_sentRequests.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(top: isSmallScreen ? 0 : 1),
                                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${_sentRequests.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 6 : 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController!,
          children: [
            _buildFriendsTab(),
            _buildSearchTab(),
            _buildRequestsTab(),
            _buildSentRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          // 친구 수 통계
          Container(
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.group, color: Colors.white, size: isSmallScreen ? 18 : 24),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '총 친구 수',
                        style: TextStyle(
                          color: const Color(0xFF9CA3AF),
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        '${_friends.length}명',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 18 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 20),

          // 친구 목록
          _friends.isEmpty
              ? _buildEmptyState(
            Icons.group_add,
            '아직 친구가 없습니다',
            '검색 탭에서 친구를 추가해보세요!',
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _friends.length,
            itemBuilder: (context, index) {
              final friend = _friends[index];
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 40 : 50,
                      height: isSmallScreen ? 40 : 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          (friend['name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 14 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend['name'] ?? '이름 없음',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 2 : 4),
                          Text(
                            friend['email'] ?? '이메일 없음',
                            style: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton(
                        icon: Icon(Icons.more_vert,
                            color: const Color(0xFF9CA3AF),
                            size: isSmallScreen ? 16 : 20),
                        color: const Color(0xFF2D3748),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.person_remove,
                                      color: const Color(0xFFEF4444),
                                      size: isSmallScreen ? 12 : 16),
                                ),
                                SizedBox(width: isSmallScreen ? 6 : 8),
                                Text('친구 삭제',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: isSmallScreen ? 12 : 14)),
                              ],
                            ),
                            onTap: () => _removeFriend(friend['uid'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          // 검색창
          Container(
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white, fontSize: isSmallScreen ? 13 : 16),
              decoration: InputDecoration(
                hintText: '이름 또는 이메일로 검색',
                hintStyle: TextStyle(color: const Color(0xFF9CA3AF), fontSize: isSmallScreen ? 13 : 16),
                prefixIcon: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  child: Icon(Icons.search, color: const Color(0xFF4F46E5), size: isSmallScreen ? 18 : 24),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 14 : 20,
                    vertical: isSmallScreen ? 12 : 16
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 20),

          // 검색 결과
          _isSearching
              ? Container(
            padding: EdgeInsets.all(isSmallScreen ? 24 : 40),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircularProgressIndicator(color: const Color(0xFF4F46E5)),
                SizedBox(height: isSmallScreen ? 10 : 16),
                Text(
                  '검색 중...',
                  style: TextStyle(color: const Color(0xFFD1D5DB), fontSize: isSmallScreen ? 13 : 16),
                ),
              ],
            ),
          )
              : _searchResults.isEmpty
              ? _buildEmptyState(
            Icons.search_off,
            _searchController.text.isEmpty ? '친구를 검색해보세요' : '검색 결과가 없습니다',
            _searchController.text.isEmpty ? '이름이나 이메일로 새로운 친구를 찾아보세요!' : '다른 검색어를 시도해보세요',
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              final isFriend = _friends.any((friend) => friend['uid'] == user['uid']);
              final hasSentRequest = _sentRequests.any((request) => request['receiverId'] == user['uid']);

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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 40 : 50,
                      height: isSmallScreen ? 40 : 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          (user['name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 14 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] ?? '이름 없음',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 2 : 4),
                          Text(
                            user['email'] ?? '이메일 없음',
                            style: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    isFriend
                        ? Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 12,
                          vertical: isSmallScreen ? 4 : 6
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: isSmallScreen ? 12 : 14),
                          SizedBox(width: isSmallScreen ? 2 : 4),
                          Text(
                            '친구',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                          ),
                        ],
                      ),
                    )
                        : hasSentRequest
                        ? Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 12,
                          vertical: isSmallScreen ? 4 : 6
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CA3AF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF9CA3AF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, color: const Color(0xFF9CA3AF), size: isSmallScreen ? 12 : 14),
                          SizedBox(width: isSmallScreen ? 2 : 4),
                          Text(
                            '요청됨',
                            style: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ElevatedButton(
                      onPressed: () => _sendFriendRequest(user['uid'] ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 10 : 16,
                            vertical: isSmallScreen ? 6 : 8
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ).copyWith(
                        backgroundColor: MaterialStateProperty.all(Colors.transparent),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 12,
                            vertical: isSmallScreen ? 4 : 6
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add, color: Colors.white, size: isSmallScreen ? 12 : 14),
                            SizedBox(width: isSmallScreen ? 2 : 4),
                            Text(
                              '요청',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 10 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          // 요청 수 표시
          if (_friendRequests.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444).withOpacity(0.1),
                    const Color(0xFFDC2626).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.notifications_active, color: Colors.white, size: isSmallScreen ? 18 : 24),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '새로운 친구 요청',
                          style: TextStyle(
                            color: const Color(0xFFD1D5DB),
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        Text(
                          '${_friendRequests.length}개',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_friendRequests.isNotEmpty) SizedBox(height: isSmallScreen ? 12 : 20),

          // 요청 목록
          _friendRequests.isEmpty
              ? _buildEmptyState(
            Icons.inbox,
            '새로운 친구 요청이 없습니다',
            '친구 요청이 오면 여기에 표시됩니다',
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _friendRequests.length,
            itemBuilder: (context, index) {
              final request = _friendRequests[index];
              return Container(
                margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: isSmallScreen ? 40 : 50,
                          height: isSmallScreen ? 40 : 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              request['senderName'][0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 10 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request['senderName'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              Text(
                                request['senderEmail'],
                                style: TextStyle(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: isSmallScreen ? 10 : 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8,
                                    vertical: isSmallScreen ? 2 : 4
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '친구 요청',
                                  style: TextStyle(
                                    color: const Color(0xFFF59E0B),
                                    fontSize: isSmallScreen ? 8 : 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptFriendRequest(
                              request['requestId'],
                              request['senderId'],
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ).copyWith(
                              backgroundColor: MaterialStateProperty.all(Colors.transparent),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, color: Colors.white, size: isSmallScreen ? 14 : 16),
                                  SizedBox(width: isSmallScreen ? 4 : 6),
                                  Text(
                                    '수락',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 12 : 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _rejectFriendRequest(request['requestId']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF374151),
                              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFF6B7280)),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close, color: const Color(0xFFEF4444), size: isSmallScreen ? 14 : 16),
                                SizedBox(width: isSmallScreen ? 4 : 6),
                                Text(
                                  '거절',
                                  style: TextStyle(
                                    color: const Color(0xFFEF4444),
                                    fontSize: isSmallScreen ? 12 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          // 보낸 요청 수 표시
          if (_sentRequests.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withOpacity(0.1),
                    const Color(0xFFD97706).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.send, color: Colors.white, size: isSmallScreen ? 18 : 24),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '보낸 친구 요청',
                          style: TextStyle(
                            color: const Color(0xFFD1D5DB),
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        Text(
                          '${_sentRequests.length}개',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_sentRequests.isNotEmpty) SizedBox(height: isSmallScreen ? 12 : 20),

          // 보낸 요청 목록
          _sentRequests.isEmpty
              ? _buildEmptyState(
            Icons.outbox,
            '보낸 친구 요청이 없습니다',
            '검색에서 친구에게 요청을 보내보세요',
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sentRequests.length,
            itemBuilder: (context, index) {
              final request = _sentRequests[index];
              return Container(
                margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: isSmallScreen ? 40 : 50,
                          height: isSmallScreen ? 40 : 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              request['receiverName'][0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 10 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request['receiverName'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              Text(
                                request['receiverEmail'],
                                style: TextStyle(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: isSmallScreen ? 10 : 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8,
                                    vertical: isSmallScreen ? 2 : 4
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '응답 대기중',
                                  style: TextStyle(
                                    color: const Color(0xFFF59E0B),
                                    fontSize: isSmallScreen ? 8 : 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _cancelSentRequest(request['requestId']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF374151),
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel, color: const Color(0xFFEF4444), size: isSmallScreen ? 14 : 16),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Text(
                              '요청 취소',
                              style: TextStyle(
                                color: const Color(0xFFEF4444),
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
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
        gradient: LinearGradient(
          colors: [
            const Color(0xFF374151),
            const Color(0xFF2D3748),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4B5563),
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              fontSize: isSmallScreen ? 14 : 18,
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
}