import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'my_page_screen.dart';
import 'friend_page_screen.dart';
import 'capsule_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 1;
  String userName = "";
  final ValueNotifier<String> _selectedCategoryNotifier = ValueNotifier<String>("MINE");
  List<Map<String, dynamic>> capsuleList = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  PageController? _pageController;
  AnimationController? _cardAnimationController;
  Animation<double>? _cardScaleAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController!,
      curve: Curves.easeInOut,
    ));

    _fetchUserName();
    _fetchCapsules();
    _cardAnimationController?.forward();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _cardAnimationController?.dispose();
    super.dispose();
  }

  // Firestore에서 사용자 이름을 가져옵니다.
  Future<void> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            userName = doc.data()?['name'] ?? 'User';
          });
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
  }

  // Firestore에서 캡슐 리스트를 가져옵니다.
  Future<void> _fetchCapsules() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final capsuleSnapshot = await FirebaseFirestore.instance.collection('capsules').get();
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      List<Map<String, dynamic>> capsulesWithCreatorName = [];
      List<String> likedCapsuleIds = [];

      if (userDoc.exists) {
        likedCapsuleIds = List<String>.from(userDoc.data()?['like'] ?? []);
      }

      for (var doc in capsuleSnapshot.docs) {
        final data = doc.data();
        String creatorName = '알 수 없음';

        final creatorId = data['creatorId'];
        if (creatorId != null) {
          final creatorDoc = await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
          if (creatorDoc.exists) {
            creatorName = creatorDoc.data()?['name'] ?? '알 수 없음';
          }
        }

        data['creatorName'] = creatorName;
        data['status'] = DateTime.now().isBefore(data['openDate'].toDate()) ? '대기중' : '열림';

        capsulesWithCreatorName.add({
          'id': doc.id,
          'name': data['name'],
          'description': data['description'], // 설명 추가
          'owners': data['owners'],
          'creatorName': creatorName,
          'createdDate': data['createdDate'].toDate(),
          'openDate': data['openDate'].toDate(),
          'status': data['status'],
          'liked': likedCapsuleIds.contains(doc.id),
          'pendingOwners': data['pendingOwners'],
        });
      }

      setState(() {
        capsuleList = capsulesWithCreatorName;
      });
    } catch (e) {
      print('Error fetching capsules: $e');
    }
  }

  Future<Map<String, int>> _fetchCapsuleCounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'created': 0, 'coOwned': 0};

    try {
      final createdCapsulesSnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .where('creatorId', isEqualTo: user.uid)
          .get();
      final coOwnedCapsulesSnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .where('owners', arrayContains: user.email)
          .get();

      return {
        'created': createdCapsulesSnapshot.docs.length,
        'coOwned': coOwnedCapsulesSnapshot.docs.length,
      };
    } catch (e) {
      print('Error fetching capsule counts: $e');
      return {'created': 0, 'coOwned': 0};
    }
  }

  final List<Widget> _pages = [
    const MyPageScreen(),
    const HomeScreen(),
    const FriendPageScreen(),
    const CapsulePageScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        capsuleList.clear();
        _fetchCapsules();
      }
    });
  }

  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D3748),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Color(0xFF4F46E5),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '알림',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('capsules')
                  .where('pendingOwners', arrayContains: FirebaseAuth.instance.currentUser?.email)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4F46E5),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A5568),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '새로운 알림이 없습니다.',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  );
                }

                final capsules = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: capsules.length,
                  itemBuilder: (context, index) {
                    final capsule = capsules[index].data() as Map<String, dynamic>;
                    final capsuleId = capsules[index].id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A5568),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4F46E5).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.archive,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      capsule['name'] ?? '알 수 없는 캡슐',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      '캡슐 초대가 도착했습니다',
                                      style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _acceptInvitation(capsuleId);
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    '수락',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _rejectInvitation(capsuleId);
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A5568),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    '거절',
                                    style: TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '닫기',
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _acceptInvitation(String capsuleId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userId == null) return;

    final capsuleRef = FirebaseFirestore.instance.collection('capsules').doc(capsuleId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      final capsuleSnapshot = await transaction.get(capsuleRef);
      final capsuleData = capsuleSnapshot.data();

      if (capsuleData != null) {
        final pendingOwners = List<dynamic>.from(capsuleData['pendingOwners'] ?? []);
        final owners = List<String>.from(capsuleData['owners'] ?? []);

        pendingOwners.remove(FirebaseAuth.instance.currentUser?.email);
        owners.add(userEmail!);

        transaction.update(capsuleRef, {
          'pendingOwners': pendingOwners,
          'owners': owners,
        });
        setState(() {
          capsuleList.clear();
          _fetchCapsules();
        });
      }
    });
  }

  void _rejectInvitation(String capsuleId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final capsuleRef = FirebaseFirestore.instance.collection('capsules').doc(capsuleId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      final capsuleSnapshot = await transaction.get(capsuleRef);
      final capsuleData = capsuleSnapshot.data();

      if (capsuleData != null) {
        final pendingOwners = List<dynamic>.from(capsuleData['pendingOwners'] ?? []);
        pendingOwners.remove(FirebaseAuth.instance.currentUser?.email);

        transaction.update(capsuleRef, {
          'pendingOwners': pendingOwners,
        });
      }
    });
  }

  // 캘린더에 표시할 날짜별 캡슐 목록을 그룹화합니다.
  Map<DateTime, List<Map<String, dynamic>>> _getCapsulesByDay() {
    Map<DateTime, List<Map<String, dynamic>>> capsuleEvents = {};
    for (var capsule in capsuleList) {
      DateTime day = DateTime(capsule['openDate'].year, capsule['openDate'].month, capsule['openDate'].day);
      if (capsuleEvents[day] == null) {
        capsuleEvents[day] = [];
      }
      capsuleEvents[day]!.add(capsule);
    }
    return capsuleEvents;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final events = _getCapsulesByDay();
    return events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Widget _buildCategoryButton(String category, String label, IconData icon) {
    final isSelected = _selectedCategoryNotifier.value == category;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: () {
          _selectedCategoryNotifier.value = category;
          setState(() {});
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 16,
              vertical: isSmallScreen ? 6 : 10
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isSelected ? null : const Color(0xFF374151),
            borderRadius: BorderRadius.circular(16),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                size: isSmallScreen ? 14 : 16,
              ),
              SizedBox(width: isSmallScreen ? 3 : 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: isSmallScreen ? 11 : 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
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
              padding: EdgeInsets.all(isSmallScreen ? 5 : 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? 14 : 18,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 10),
            Text(
              count,
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFFD1D5DB),
                fontSize: isSmallScreen ? 9 : 10,
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

  Widget _buildCapsuleCard(Map<String, dynamic> capsule) {
    final status = capsule['status'];
    final openDate = capsule['openDate'] as DateTime;
    final createdDate = capsule['createdDate'] as DateTime;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (status == '대기중') {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.lock_outline;
      statusText = '대기중';
    } else {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.celebration_outlined;
      statusText = '열림';
    }

    return _cardScaleAnimation != null
        ? AnimatedBuilder(
      animation: _cardScaleAnimation!,
      builder: (context, child) {
        return Transform.scale(
          scale: _cardScaleAnimation!.value,
          child: _buildCardContent(capsule, statusColor, statusIcon, statusText, openDate, createdDate, isSmallScreen),
        );
      },
    )
        : _buildCardContent(capsule, statusColor, statusIcon, statusText, openDate, createdDate, isSmallScreen);
  }

  Widget _buildCardContent(Map<String, dynamic> capsule, Color statusColor, IconData statusIcon, String statusText, DateTime openDate, DateTime createdDate, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isSmallScreen ? 36 : 44,
                height: isSmallScreen ? 36 : 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    (capsule['name'] ?? 'C')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 14 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capsule['name'],
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 1 : 3),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: isSmallScreen ? 12 : 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                        SizedBox(width: isSmallScreen ? 2 : 3),
                        Expanded(
                          child: Text(
                            'by ${capsule['creatorName']}',
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
              ),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 10,
                      vertical: isSmallScreen ? 3 : 5
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: isSmallScreen ? 10 : 14),
                      SizedBox(width: isSmallScreen ? 2 : 3),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: isSmallScreen ? 9 : 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 14),

          // 캡슐 설명 추가
          if (capsule['description'] != null && capsule['description'].toString().trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                capsule['description'].toString(),
                style: TextStyle(
                  color: const Color(0xFFD1D5DB),
                  fontSize: isSmallScreen ? 11 : 13,
                  height: 1.4,
                ),
                maxLines: isSmallScreen ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: isSmallScreen ? 10 : 14),
          ],

          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.group_outlined,
                  '공동소유주',
                  (capsule['owners'] as List<dynamic>).join(', ').isEmpty
                      ? '없음'
                      : (capsule['owners'] as List<dynamic>).join(', '),
                  isSmallScreen,
                ),
                SizedBox(height: isSmallScreen ? 6 : 10),
                _buildInfoRow(
                  Icons.calendar_today_outlined,
                  '생성일',
                  DateFormat('yyyy년 MM월 dd일').format(createdDate),
                  isSmallScreen,
                ),
                SizedBox(height: isSmallScreen ? 6 : 10),
                _buildInfoRow(
                  Icons.schedule_outlined,
                  '열람일',
                  DateFormat('yyyy년 MM월 dd일').format(openDate),
                  isSmallScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 12 : 14,
          color: const Color(0xFF9CA3AF),
        ),
        SizedBox(width: isSmallScreen ? 4 : 6),
        Text(
          '$label:',
          style: TextStyle(
            color: const Color(0xFF9CA3AF),
            fontSize: isSmallScreen ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: isSmallScreen ? 3 : 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _selectedIndex == 1
          ? FutureBuilder<Map<String, int>>(
        future: _fetchCapsuleCounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4F46E5),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          } else {
            final counts = snapshot.data ?? {'created': 0, 'coOwned': 0};
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: isSmallScreen ? 90 : 110,
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
                          isSmallScreen ? 40 : 50,
                          isSmallScreen ? 12 : 16,
                          isSmallScreen ? 8 : 12
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '안녕하세요 👋',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 14,
                                    color: const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 1 : 2),
                                Flexible(
                                  child: ValueListenableBuilder<String>(
                                    valueListenable: _selectedCategoryNotifier,
                                    builder: (context, selectedCategory, child) {
                                      return ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                        ).createShader(bounds),
                                        child: Text(
                                          userName,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 18 : 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 12),
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
                            child: IconButton(
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: const Color(0xFF9CA3AF),
                                size: isSmallScreen ? 18 : 22,
                              ),
                              onPressed: () {
                                _showNotificationDialog(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // 카테고리 선택
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: isSmallScreen ? 8 : 12
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryButton("MINE", "내 캡슐", Icons.person_outline),
                              SizedBox(width: isSmallScreen ? 6 : 10),
                              _buildCategoryButton("ELSE", "공유됨", Icons.group_outlined),
                              SizedBox(width: isSmallScreen ? 6 : 10),
                              _buildCategoryButton("LIKE", "좋아요", Icons.favorite_outline),
                            ],
                          ),
                        ),
                      ),

                      // 통계 카드
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                        child: Row(
                          children: [
                            _buildStatCard(
                              'Created',
                              '${counts['created']}',
                              Icons.create_outlined,
                              const Color(0xFF4F46E5),
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 12),
                            _buildStatCard(
                              'Co-Owned',
                              '${counts['coOwned']}',
                              Icons.group_outlined,
                              const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 12 : 20),

                      // 캡슐 리스트
                      SizedBox(
                        height: screenHeight * (isSmallScreen ? 0.40 : 0.45), // 작은 화면에서 높이 줄임
                        child: ValueListenableBuilder<String>(
                          valueListenable: _selectedCategoryNotifier,
                          builder: (context, selectedCategory, child) {
                            final filteredCapsules = capsuleList.where((capsule) {
                              if (selectedCategory == "MINE") {
                                return capsule['creatorName'] == userName;
                              } else if (selectedCategory == "ELSE") {
                                return capsule['owners']?.contains(FirebaseAuth.instance.currentUser?.email) ?? false;
                              } else if (selectedCategory == "LIKE") {
                                return capsule['liked'] == true;
                              }
                              return false;
                            }).toList();

                            // 캡슐 정렬: 열람일 기준으로 정렬
                            filteredCapsules.sort((a, b) {
                              final now = DateTime.now();
                              final aOpenDate = a['openDate'] as DateTime;
                              final bOpenDate = b['openDate'] as DateTime;

                              final aIsToday = aOpenDate.year == now.year &&
                                  aOpenDate.month == now.month &&
                                  aOpenDate.day == now.day;
                              final bIsToday = bOpenDate.year == now.year &&
                                  bOpenDate.month == now.month &&
                                  bOpenDate.day == now.day;

                              final aIsOpened = aOpenDate.isBefore(now) || aIsToday;
                              final bIsOpened = bOpenDate.isBefore(now) || bIsToday;

                              // 1. 당일 열림 (가장 앞)
                              if (aIsToday && !bIsToday) return -1;
                              if (bIsToday && !aIsToday) return 1;
                              if (aIsToday && bIsToday) return aOpenDate.compareTo(bOpenDate);

                              // 2. 열리지 않은 것들 (열람일이 빠른 순)
                              if (!aIsOpened && !bIsOpened) {
                                return aOpenDate.compareTo(bOpenDate);
                              }

                              // 3. 열리지 않은 것이 열린 것보다 앞
                              if (!aIsOpened && bIsOpened) return -1;
                              if (aIsOpened && !bIsOpened) return 1;

                              // 4. 둘 다 열린 것들 (열람일이 늦은 순 - 가장 뒤)
                              return bOpenDate.compareTo(aOpenDate);
                            });

                            if (filteredCapsules.isEmpty) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                                padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF374151),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF4B5563),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4B5563),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        selectedCategory == "MINE"
                                            ? Icons.archive_outlined
                                            : selectedCategory == "ELSE"
                                            ? Icons.group_outlined
                                            : Icons.favorite_outline,
                                        size: isSmallScreen ? 28 : 40,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 8 : 12),
                                    Text(
                                      selectedCategory == "MINE"
                                          ? '아직 만든 캡슐이 없습니다'
                                          : selectedCategory == "ELSE"
                                          ? '공유받은 캡슐이 없습니다'
                                          : '좋아요한 캡슐이 없습니다',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: isSmallScreen ? 3 : 6),
                                    Text(
                                      selectedCategory == "MINE"
                                          ? '첫 번째 추억 캡슐을 만들어보세요!'
                                          : selectedCategory == "ELSE"
                                          ? '친구들과 함께 캡슐을 만들어보세요!'
                                          : '마음에 드는 캡슐에 좋아요를 눌러보세요!',
                                      style: TextStyle(
                                        color: const Color(0xFF9CA3AF),
                                        fontSize: isSmallScreen ? 11 : 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            return PageView.builder(
                              controller: _pageController,
                              itemCount: filteredCapsules.length,
                              itemBuilder: (context, index) {
                                return _buildCapsuleCard(filteredCapsules[index]);
                              },
                            );
                          },
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 16 : 24),

                      // 캘린더 섹션
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 6 : 10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.calendar_month,
                                    color: Colors.white,
                                    size: isSmallScreen ? 18 : 22,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 10 : 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '캡슐 캘린더',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 14 : 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '열람일을 확인해보세요',
                                        style: TextStyle(
                                          color: const Color(0xFF9CA3AF),
                                          fontSize: isSmallScreen ? 10 : 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 18),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F2937),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: EdgeInsets.all(isSmallScreen ? 6 : 12),
                              child: TableCalendar(
                                firstDay: DateTime.utc(2000, 1, 1),
                                lastDay: DateTime.utc(2100, 12, 31),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                },
                                eventLoader: _getEventsForDay,
                                calendarStyle: CalendarStyle(
                                  outsideDaysVisible: false,
                                  weekendTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 11 : 13,
                                  ),
                                  defaultTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 11 : 13,
                                  ),
                                  todayDecoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  selectedDecoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  todayTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 11 : 13,
                                  ),
                                  selectedTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 11 : 13,
                                  ),
                                  markerDecoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  titleTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 13 : 15,
                                  ),
                                  leftChevronIcon: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF374151),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                      size: isSmallScreen ? 14 : 18,
                                    ),
                                  ),
                                  rightChevronIcon: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF374151),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: isSmallScreen ? 14 : 18,
                                    ),
                                  ),
                                ),
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(
                                    color: const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                    fontSize: isSmallScreen ? 10 : 11,
                                  ),
                                  weekendStyle: TextStyle(
                                    color: const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                    fontSize: isSmallScreen ? 10 : 11,
                                  ),
                                ),
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, day, events) {
                                    if (events.isEmpty) return const SizedBox();
                                    return Positioned(
                                      bottom: 4,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: events.take(3).map((event) {
                                          Color markerColor = const Color(0xFF10B981);
                                          if (event != null && event is Map && (event['status'] ?? '') == '대기중') {
                                            markerColor = const Color(0xFFEF4444);
                                          }
                                          return Container(
                                            width: isSmallScreen ? 3 : 5,
                                            height: isSmallScreen ? 3 : 5,
                                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: markerColor,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 20 : 32),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      )
          : _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E293B),
              const Color(0xFF0F172A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: 6
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomNavItem(Icons.person_outline, Icons.person, 0, '마이'),
                _buildBottomNavItem(Icons.home_outlined, Icons.home, 1, '홈'),
                _buildBottomNavItem(Icons.group_outlined, Icons.group, 2, '친구'),
                _buildBottomNavItem(Icons.archive_outlined, Icons.archive, 3, '캡슐'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData outlineIcon, IconData filledIcon, int index, String label) {
    bool isSelected = _selectedIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 14,
            vertical: 6
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
              size: isSmallScreen ? 18 : 22,
            ),
            if (isSelected) ...[
              SizedBox(width: isSmallScreen ? 4 : 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 11 : 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}