import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'capsule_create_screen.dart';
import 'capsule_details_screen.dart';

class CapsulePageScreen extends StatefulWidget {
  const CapsulePageScreen({super.key});

  @override
  _CapsulePageScreenState createState() => _CapsulePageScreenState();
}

class _CapsulePageScreenState extends State<CapsulePageScreen> {
  List<Map<String, dynamic>> _capsules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCapsules();
  }

  Future<void> _loadCapsules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // 사용자 정보 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("사용자 정보를 찾을 수 없습니다.");
      }

      final currentUserEmail = userDoc.data()?['email']?.toString() ?? '';
      final userLikes = List<String>.from(userDoc.data()?['like'] ?? []);

      // 내가 만든 캡슐들
      final creatorQuery = await FirebaseFirestore.instance
          .collection('capsules')
          .where('creatorId', isEqualTo: currentUser.uid)
          .get();

      // 공유받은 캡슐들 (소유주로 등록된)
      QuerySnapshot ownersQuery;
      try {
        ownersQuery = await FirebaseFirestore.instance
            .collection('capsules')
            .where('owners', arrayContains: currentUserEmail)
            .get();
      } catch (e) {
        // owners 필드가 없는 경우 빈 결과로 처리
        ownersQuery = await FirebaseFirestore.instance
            .collection('capsules')
            .where('creatorId', isEqualTo: 'non-existent-user')
            .get();
      }

      // 모든 캡슐 문서 합치기 (중복 제거)
      final allDocs = [...creatorQuery.docs, ...ownersQuery.docs];
      final uniqueCapsules = <String, QueryDocumentSnapshot>{};
      for (var doc in allDocs) {
        uniqueCapsules[doc.id] = doc;
      }

      List<Map<String, dynamic>> capsules = [];

      for (var doc in uniqueCapsules.values) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;

        // Timestamp를 DateTime으로 변환
        if (data['createdDate'] is Timestamp) {
          data['createdDate'] = (data['createdDate'] as Timestamp).toDate();
        }
        if (data['openDate'] is Timestamp) {
          data['openDate'] = (data['openDate'] as Timestamp).toDate();
        }

        // 생성자 이름 가져오기
        String creatorName = '알 수 없음';
        if (data['creatorId'] != null) {
          try {
            final creatorDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['creatorId'])
                .get();
            if (creatorDoc.exists) {
              creatorName = creatorDoc.data()?['name']?.toString() ?? '알 수 없음';
            }
          } catch (e) {
            // 생성자 정보를 가져올 수 없는 경우 기본값 유지
          }
        }

        data['creatorName'] = creatorName;
        data['isLiked'] = userLikes.contains(doc.id);
        data['isCreator'] = data['creatorId'] == currentUser.uid;

        capsules.add(data);
      }

      // 생성일 기준 내림차순 정렬
      capsules.sort((a, b) {
        final aDate = a['createdDate'] as DateTime? ?? DateTime.now();
        final bDate = b['createdDate'] as DateTime? ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      setState(() {
        _capsules = capsules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('캡슐 로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteCapsule(String capsuleId, String status) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        title: const Text(
          '캡슐 삭제',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          status == 'draft'
              ? '정말로 이 캡슐을 삭제하시겠습니까?'
              : '캡슐 삭제에 투표하시겠습니까?',
          style: const TextStyle(color: Color(0xFFD1D5DB)),
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
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("사용자 정보를 찾을 수 없습니다.");
      }

      final currentUserEmail = userDoc.data()?['email']?.toString() ?? '';
      final capsuleRef = FirebaseFirestore.instance.collection('capsules').doc(capsuleId);
      final capsuleDoc = await capsuleRef.get();

      if (!capsuleDoc.exists) {
        throw Exception("캡슐을 찾을 수 없습니다.");
      }

      final capsuleData = capsuleDoc.data()!;
      final isCreator = currentUser.uid == capsuleData['creatorId'];

      if (status == 'draft' && isCreator) {
        // 임시저장 상태의 경우 바로 삭제
        await capsuleRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('캡슐이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 삭제 투표 처리
        final owners = List<String>.from(capsuleData['owners'] ?? []);
        final deleteVotes = List<String>.from(capsuleData['deleteVotes'] ?? []);

        List<String> newDeleteVotes = List.from(deleteVotes);
        if (newDeleteVotes.contains(currentUserEmail)) {
          newDeleteVotes.remove(currentUserEmail);
        } else {
          newDeleteVotes.add(currentUserEmail);
        }

        final totalOwners = owners.length + 1; // 생성자 포함

        if (newDeleteVotes.length >= totalOwners) {
          // 모든 소유주가 동의하면 삭제
          await capsuleRef.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('캡슐이 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // 투표 상태만 업데이트
          await capsuleRef.update({'deleteVotes': newDeleteVotes});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleteVotes.contains(currentUserEmail)
                    ? '삭제 투표를 취소했습니다.'
                    : '삭제 투표를 등록했습니다.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // 목록 새로고침
      _loadCapsules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 처리 실패: $e')),
        );
      }
    }
  }

  Future<void> _toggleLike(String capsuleId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);

      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        throw Exception("사용자 정보를 찾을 수 없습니다.");
      }

      final likes = List<String>.from(userDoc.data()?['like'] ?? []);
      if (likes.contains(capsuleId)) {
        likes.remove(capsuleId);
      } else {
        likes.add(capsuleId);
      }

      await userDocRef.update({'like': likes});

      // 로컬 상태 업데이트
      setState(() {
        final index = _capsules.indexWhere((c) => c['id'] == capsuleId);
        if (index != -1) {
          _capsules[index]['isLiked'] = likes.contains(capsuleId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요 처리 실패: $e')),
        );
      }
    }
  }

  void _showCapsuleOptions(Map<String, dynamic> capsule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 좋아요 버튼
            IconButton(
              icon: Icon(
                capsule['isLiked'] ? Icons.favorite : Icons.favorite_border,
                color: capsule['isLiked'] ? Colors.red : Colors.white,
                size: 32,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _toggleLike(capsule['id']);
              },
            ),
            // 삭제 버튼
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
                size: 32,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCapsule(capsule['id'], capsule['status']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleCard(Map<String, dynamic> capsule) {
    final now = DateTime.now();
    final openDate = capsule['openDate'] as DateTime?;
    final status = capsule['status'] ?? 'unknown';
    final isLiked = capsule['isLiked'] ?? false;
    final deleteVotes = List<String>.from(capsule['deleteVotes'] ?? []);
    final owners = List<String>.from(capsule['owners'] ?? []);

    // 상태 정보
    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (status == 'draft') {
      statusIcon = Icons.edit;
      statusColor = const Color(0xFFF59E0B);
      statusText = '임시저장';
    } else if (openDate != null && openDate.isAfter(now)) {
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (status == 'draft' || (openDate != null && !openDate.isAfter(now))) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CapsuleDetailsScreen(
                  capsule: capsule,
                  isEditable: status == 'draft' && capsule['isCreator'] == true,
                ),
              ),
            );
            if (result == true) {
              _loadCapsules();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  openDate != null
                      ? '${DateFormat('yyyy-MM-dd HH:mm').format(openDate)}에 열립니다.'
                      : '아직 열람할 수 없습니다.',
                ),
              ),
            );
          }
        },
        onLongPress: () => _showCapsuleOptions(capsule),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF4F46E5),
                    child: Text(
                      (capsule['name'] ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capsule['name'] ?? '제목 없음',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'by ${capsule['creatorName']}',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 설명
              if (capsule['description'] != null && capsule['description'].isNotEmpty)
                Text(
                  capsule['description'],
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 12),

              // 하단 정보
              Row(
                children: [
                  // 날짜
                  Icon(
                    Icons.schedule,
                    color: const Color(0xFF9CA3AF),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    openDate != null
                        ? DateFormat('yyyy.MM.dd HH:mm').format(openDate)
                        : '날짜 미설정',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),

                  // 삭제 투표 (있는 경우)
                  if (deleteVotes.isNotEmpty) ...[
                    const Icon(
                      Icons.how_to_vote,
                      color: Color(0xFFEF4444),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '삭제 투표: ${deleteVotes.length}/${owners.length + 1}',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // 좋아요
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : const Color(0xFF9CA3AF),
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Row(
              children: [
                const Text(
                  '내 캡슐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadCapsules,
                  icon: const Icon(Icons.refresh, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),

          // 캡슐 목록
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            )
                : _capsules.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.archive,
                    size: 64,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '아직 캡슐이 없습니다',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '첫 번째 추억 캡슐을 만들어보세요!',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: const Color(0xFF4F46E5),
              backgroundColor: const Color(0xFF374151),
              onRefresh: _loadCapsules,
              child: ListView.builder(
                itemCount: _capsules.length,
                itemBuilder: (context, index) {
                  return _buildCapsuleCard(_capsules[index]);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CapsuleCreateScreen(
                onCapsuleCreated: (capsule) => _loadCapsules(),
              ),
            ),
          );
          if (result != null) _loadCapsules();
        },
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}