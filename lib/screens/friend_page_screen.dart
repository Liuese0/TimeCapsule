import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendPageScreen extends StatefulWidget {
  const FriendPageScreen({super.key});

  @override
  _FriendPageScreenState createState() => _FriendPageScreenState();
}

class _FriendPageScreenState extends State<FriendPageScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadFriendRequests();
    _loadSentRequests();
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
          // null 체크 및 기본값 설정
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

      // 이메일로 검색
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: query.trim().toLowerCase())
          .get();

      // 이름으로 검색 (부분 일치)
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
          // null 체크 및 기본값 설정
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
      // 이미 요청을 보냈는지 확인
      final existingRequest = await FirebaseFirestore.instance
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 친구 요청을 보냈습니다.')),
        );
        return;
      }

      // 이미 친구인지 확인
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
      if (friends.contains(receiverId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 친구입니다.')),
        );
        return;
      }

      // 친구 요청 생성
      await FirebaseFirestore.instance.collection('friendRequests').add({
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 요청을 보냈습니다.')),
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

      // 요청 상태 업데이트
      final requestRef = FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId);
      batch.update(requestRef, {'status': 'accepted'});

      // 양쪽 사용자의 친구 목록에 추가
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
        const SnackBar(content: Text('친구 요청을 수락했습니다.')),
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
        const SnackBar(content: Text('친구 요청을 거절했습니다.')),
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
        title: const Text('친구 삭제'),
        content: const Text('정말로 친구를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 양쪽 사용자의 친구 목록에서 제거
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
        const SnackBar(content: Text('친구를 삭제했습니다.')),
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
        const SnackBar(content: Text('친구 요청을 취소했습니다.')),
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
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF1F2937),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('친구', style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            labelColor: Color(0xFF4F46E5),
            unselectedLabelColor: Color(0xFF9CA3AF),
            indicatorColor: Color(0xFF4F46E5),
            tabs: [
              Tab(text: '친구'),
              Tab(text: '검색'),
              Tab(text: '요청'),
              Tab(text: '보낸요청'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 친구 목록 탭
            _buildFriendsTab(),
            // 친구 검색 탭
            _buildSearchTab(),
            // 받은 요청 탭
            _buildRequestsTab(),
            // 보낸 요청 탭
            _buildSentRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '친구 (${_friends.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _friends.isEmpty
                ? const Center(
              child: Text(
                '아직 친구가 없습니다.\n친구를 검색해서 추가해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD1D5DB)),
              ),
            )
                : ListView.builder(
              itemCount: _friends.length,
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return Card(
                  color: const Color(0xFF374151),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4F46E5),
                      child: Text(
                        (friend['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      friend['name'] ?? '이름 없음',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      friend['email'] ?? '이메일 없음',
                      style: const TextStyle(color: Color(0xFFD1D5DB)),
                    ),
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'remove',
                          child: const Text('친구 삭제'),
                          onTap: () => _removeFriend(friend['uid'] ?? ''),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '이름 또는 이메일로 검색',
              labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFF374151),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
            ),
            onChanged: _searchUsers,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? const Center(
              child: Text(
                '검색 결과가 없습니다.',
                style: TextStyle(color: Color(0xFFD1D5DB)),
              ),
            )
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final isFriend = _friends.any((friend) => friend['uid'] == user['uid']);
                final hasSentRequest = _sentRequests.any((request) => request['receiverId'] == user['uid']);

                return Card(
                  color: const Color(0xFF374151),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4F46E5),
                      child: Text(
                        (user['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      user['name'] ?? '이름 없음',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      user['email'] ?? '이메일 없음',
                      style: const TextStyle(color: Color(0xFFD1D5DB)),
                    ),
                    trailing: isFriend
                        ? const Text(
                      '친구',
                      style: TextStyle(color: Color(0xFF10B981)),
                    )
                        : hasSentRequest
                        ? const Text(
                      '요청됨',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    )
                        : ElevatedButton(
                      onPressed: () => _sendFriendRequest(user['uid'] ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                      child: const Text(
                        '요청',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '받은 친구 요청 (${_friendRequests.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _friendRequests.isEmpty
                ? const Center(
              child: Text(
                '새로운 친구 요청이 없습니다.',
                style: TextStyle(color: Color(0xFFD1D5DB)),
              ),
            )
                : ListView.builder(
              itemCount: _friendRequests.length,
              itemBuilder: (context, index) {
                final request = _friendRequests[index];
                return Card(
                  color: const Color(0xFF374151),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4F46E5),
                      child: Text(
                        request['senderName'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      request['senderName'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      request['senderEmail'],
                      style: const TextStyle(color: Color(0xFFD1D5DB)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _acceptFriendRequest(
                            request['requestId'],
                            request['senderId'],
                          ),
                          child: const Text(
                            '수락',
                            style: TextStyle(color: Color(0xFF10B981)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _rejectFriendRequest(request['requestId']),
                          child: const Text(
                            '거절',
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '보낸 친구 요청 (${_sentRequests.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _sentRequests.isEmpty
                ? const Center(
              child: Text(
                '보낸 친구 요청이 없습니다.',
                style: TextStyle(color: Color(0xFFD1D5DB)),
              ),
            )
                : ListView.builder(
              itemCount: _sentRequests.length,
              itemBuilder: (context, index) {
                final request = _sentRequests[index];
                return Card(
                  color: const Color(0xFF374151),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4F46E5),
                      child: Text(
                        request['receiverName'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      request['receiverName'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      request['receiverEmail'],
                      style: const TextStyle(color: Color(0xFFD1D5DB)),
                    ),
                    trailing: TextButton(
                      onPressed: () => _cancelSentRequest(request['requestId']),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}