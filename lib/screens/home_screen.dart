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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;
  String userName = "";
  final ValueNotifier<String> _selectedCategoryNotifier = ValueNotifier<String>("MINE");
  List<Map<String, dynamic>> capsuleList = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _fetchCapsules();
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
          title: const Text('알림'),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('capsules')
                  .where('pendingOwners', arrayContains: FirebaseAuth.instance.currentUser?.email)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('새로운 알림이 없습니다.'));
                }

                final capsules = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: capsules.length,
                  itemBuilder: (context, index) {
                    final capsule = capsules[index].data() as Map<String, dynamic>;
                    final capsuleId = capsules[index].id;
                    return ListTile(
                      title: Text(capsule['name'] ?? '알 수 없는 캡슐'),
                      subtitle: const Text('초대 상태: 대기 중'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              _acceptInvitation(capsuleId);
                              Navigator.of(context).pop();
                            },
                            child: const Text('수락'),
                          ),
                          TextButton(
                            onPressed: () {
                              _rejectInvitation(capsuleId);
                              Navigator.of(context).pop();
                            },
                            child: const Text('거절'),
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
              child: const Text('닫기'),
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

  @override
  Widget build(BuildContext context) {
    final capsuleEvents = _getCapsulesByDay();

    return Scaffold(
      backgroundColor: const Color(0xFF1F2937), // bg-gray-900
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: const EdgeInsets.only(top: 25, left: 16, right: 16, bottom: 8),
          color: const Color(0xFF1F2937),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 헤더: 인사말 및 사용자 이름 (카테고리 "MINE" 선택 시 indigo, 아니면 흰색)
              Row(
                children: [
                  const Text(
                    '안녕하세요, ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _selectedCategoryNotifier,
                    builder: (context, selectedCategory, child) {
                      return Text(
                        userName,
                        style: TextStyle(
                          fontSize: 25.0,
                          fontWeight: FontWeight.bold,
                          color: selectedCategory == "MINE"
                              ? const Color.fromRGBO(94, 53, 189, 1)
                              : Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
              // 알림 버튼
              IconButton(
                icon: const Icon(Icons.notifications, color: Color(0xFF9CA3AF)), // text-gray-400
                onPressed: () {
                  _showNotificationDialog(context);
                },
              )
            ],
          ),
        ),
      ),
      body: _selectedIndex == 1
          ? FutureBuilder<Map<String, int>>(
        future: _fetchCapsuleCounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final counts = snapshot.data ?? {'created': 0, 'coOwned': 0};
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리 선택 토글
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151), // bg-gray-800
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: _selectedCategoryNotifier.value == "MINE"
                                    ? const Color(0xFF4F46E5) // 선택 시
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                _selectedCategoryNotifier.value = "MINE";
                                setState(() {});
                              },
                              child: Text(
                                "MINE",
                                style: TextStyle(
                                    color: _selectedCategoryNotifier.value == "MINE"
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: _selectedCategoryNotifier.value == "ELSE"
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                _selectedCategoryNotifier.value = "ELSE";
                                setState(() {});
                              },
                              child: Text(
                                "ELSE",
                                style: TextStyle(
                                    color: _selectedCategoryNotifier.value == "ELSE"
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: _selectedCategoryNotifier.value == "LIKE"
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                _selectedCategoryNotifier.value = "LIKE";
                                setState(() {});
                              },
                              child: Text(
                                "LIKE",
                                style: TextStyle(
                                    color: _selectedCategoryNotifier.value == "LIKE"
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 캡슐 카운트
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Created Capsules', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
                            Text('${counts['created']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Co-Owned Capsules', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
                            Text('${counts['coOwned']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 캡슐 리스트
                  SizedBox(
                    height: 300,
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

                        if (filteredCapsules.isEmpty) {
                          return const Center(child: Text('표시할 캡슐이 없습니다.', style: TextStyle(color: Color(0xFFD1D5DB))));
                        }

                        return PageView.builder(
                          itemCount: filteredCapsules.length,
                          itemBuilder: (context, index) {
                            final capsule = filteredCapsules[index];
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Card(
                                color: const Color(0xFF374151), // bg-gray-800
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        capsule['name'],
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(height: 8),
                                      // 캡슐 상세 정보
                                      Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: const [
                                              Text('생성자:', style: TextStyle(fontSize: 16, color: Color(0xFFD1D5DB))),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const SizedBox(width: 70),
                                              Text(capsule['creatorName'], style: const TextStyle(fontSize: 16, color: Colors.white)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: const [
                                              Text('공동소유주:', style: TextStyle(fontSize: 16, color: Color(0xFFD1D5DB))),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const SizedBox(width: 100),
                                              Flexible(
                                                child: Text(
                                                  (capsule['owners'] as List<dynamic>).join(', '),
                                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('생성일:', style: TextStyle(fontSize: 16, color: Color(0xFFD1D5DB))),
                                              Text(DateFormat('yyyy-MM-dd').format(capsule['createdDate']), style: const TextStyle(fontSize: 16, color: Colors.white)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('열람일:', style: TextStyle(fontSize: 16, color: Color(0xFFD1D5DB))),
                                              Text(DateFormat('yyyy-MM-dd').format(capsule['openDate']), style: const TextStyle(fontSize: 16, color: Colors.white)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('상태:', style: TextStyle(fontSize: 16, color: Color(0xFFD1D5DB))),
                                              Text(
                                                capsule['status'],
                                                style: TextStyle(fontSize: 16, color: capsule['status'] == '대기중' ? const Color(0xFF3B82F6) : Colors.white),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // 캘린더 섹션
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151), // bg-gray-800
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
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
                          todayDecoration: BoxDecoration(color: const Color(0xFF4F46E5), shape: BoxShape.circle),
                          selectedDecoration: BoxDecoration(color: const Color(0xFF4338CA), shape: BoxShape.circle),
                          todayTextStyle: const TextStyle(color: Colors.white),
                          defaultTextStyle: const TextStyle(color: Colors.white),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          leftChevronIcon: const Icon(Icons.chevron_left, color: Color(0xFFD1D5DB)),
                          rightChevronIcon: const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) {
                            if (events.isEmpty) return const SizedBox();
                            return Wrap(
                              spacing: 2,
                              children: events.map((event) {
                                Color markerColor = Colors.grey;
                                if (event != null && event is Map && (event['status'] ?? '') == '대기중') {
                                  markerColor = const Color(0xFF1D4ED8);
                                }
                                return Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: markerColor,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      )
          : _pages[_selectedIndex],
      // 커스텀 Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF374151), // bg-gray-800
          border: Border(top: BorderSide(color: const Color(0xFF4B5563))), // border-gray-700
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomNavItem(Icons.person, 0),
              _buildBottomNavItem(Icons.home, 1),
              _buildBottomNavItem(Icons.group, 2),
              _buildBottomNavItem(Icons.archive, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    Color iconColor = isSelected ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF);
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
