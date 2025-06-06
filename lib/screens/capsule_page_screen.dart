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

class _CapsulePageScreenState extends State<CapsulePageScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _capsules = [];
  bool _isLoading = true;
  final ValueNotifier<String> _selectedCategoryNotifier = ValueNotifier<String>("ALL");

  AnimationController? _fadeAnimationController;
  Animation<double>? _fadeAnimation;

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
      parent: _fadeAnimationController!,
      curve: Curves.easeInOut,
    ));

    _loadCapsules();
  }

  @override
  void dispose() {
    _fadeAnimationController?.dispose();
    _selectedCategoryNotifier.dispose();
    super.dispose();
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

        // 상태 결정
        final now = DateTime.now();
        final openDate = data['openDate'] as DateTime;
        final status = data['status'] ?? '';

        if (status == 'draft') {
          data['displayStatus'] = 'draft';
        } else if (openDate.isAfter(now)) {
          data['displayStatus'] = 'waiting';
        } else {
          data['displayStatus'] = 'opened';
        }

        capsules.add(data);
      }

      // 정렬: 상태별로 정렬 (임시저장 > 대기중 > 열림), 같은 상태 내에서는 생성일 기준 내림차순
      capsules.sort((a, b) {
        final aStatus = a['displayStatus'];
        final bStatus = b['displayStatus'];

        // 상태별 우선순위
        const statusPriority = {'draft': 0, 'waiting': 1, 'opened': 2};
        final aPriority = statusPriority[aStatus] ?? 3;
        final bPriority = statusPriority[bStatus] ?? 3;

        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }

        // 같은 상태 내에서는 생성일 기준 내림차순
        final aDate = a['createdDate'] as DateTime? ?? DateTime.now();
        final bDate = b['createdDate'] as DateTime? ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      setState(() {
        _capsules = capsules;
        _isLoading = false;
      });

      _fadeAnimationController?.forward();
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
              '캡슐 삭제',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('캡슐이 삭제되었습니다.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
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
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('캡슐이 삭제되었습니다.'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // 투표 상태만 업데이트
          await capsuleRef.update({'deleteVotes': newDeleteVotes});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    deleteVotes.contains(currentUserEmail)
                        ? '삭제 투표를 취소했습니다.'
                        : '삭제 투표를 등록했습니다.',
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
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
        backgroundColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 좋아요 버튼
            _buildActionButton(
              capsule['isLiked'] ? Icons.favorite : Icons.favorite_border,
              capsule['isLiked'] ? const Color(0xFFEC4899) : const Color(0xFF9CA3AF),
                  () async {
                Navigator.pop(context);
                await _toggleLike(capsule['id']);
              },
            ),
            // 삭제 버튼
            _buildActionButton(
              Icons.delete_outline,
              const Color(0xFFEF4444),
                  () async {
                Navigator.pop(context);
                await _deleteCapsule(capsule['id'], capsule['status']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category, String label, IconData icon) {
    final isSelected = _selectedCategoryNotifier.value == category;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: () {
          _selectedCategoryNotifier.value = category;
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 10,
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
    final now = DateTime.now();
    final openDate = capsule['openDate'] as DateTime?;
    final status = capsule['displayStatus'] ?? 'unknown';
    final isLiked = capsule['isLiked'] ?? false;
    final deleteVotes = List<String>.from(capsule['deleteVotes'] ?? []);
    final owners = List<String>.from(capsule['owners'] ?? []);

    // 상태 정보
    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (status == 'draft') {
      statusIcon = Icons.edit_outlined;
      statusColor = const Color(0xFFF59E0B);
      statusText = '임시저장';
    } else if (status == 'waiting') {
      statusIcon = Icons.lock_outline;
      statusColor = const Color(0xFFEF4444);
      statusText = '대기중';
    } else {
      statusIcon = Icons.celebration_outlined;
      statusColor = const Color(0xFF10B981);
      statusText = '열림';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (status == 'draft' || status == 'opened') {
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
                content: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      openDate != null
                          ? '${DateFormat('yyyy-MM-dd HH:mm').format(openDate)}에 열립니다.'
                          : '아직 열람할 수 없습니다.',
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onLongPress: () => _showCapsuleOptions(capsule),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (capsule['name'] ?? 'C')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capsule['name'] ?? '제목 없음',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'by ${capsule['creatorName']}',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 설명
              if (capsule['description'] != null && capsule['description'].isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    capsule['description'],
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              if (capsule['description'] != null && capsule['description'].isNotEmpty)
                const SizedBox(height: 16),

              // 하단 정보
              Row(
                children: [
                  // 날짜 정보
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          openDate != null
                              ? DateFormat('yyyy.MM.dd HH:mm').format(openDate)
                              : '날짜 미설정',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 삭제 투표 (있는 경우)
                  if (deleteVotes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.how_to_vote,
                            color: Color(0xFFEF4444),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '삭제투표: ${deleteVotes.length}/${owners.length + 1}',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // 좋아요
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? const Color(0xFFEC4899).withOpacity(0.2)
                          : const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLiked
                            ? const Color(0xFFEC4899).withOpacity(0.5)
                            : const Color(0xFF4B5563),
                      ),
                    ),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? const Color(0xFFEC4899) : const Color(0xFF9CA3AF),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(40),
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
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4B5563),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.archive_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 캡슐이 없습니다',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '첫 번째 추억 캡슐을 만들어보세요!',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredCapsules() {
    switch (_selectedCategoryNotifier.value) {
      case 'MINE':
        return _capsules.where((capsule) => capsule['isCreator'] == true).toList();
      case 'SHARED':
        return _capsules.where((capsule) => capsule['isCreator'] != true).toList();
      case 'LIKED':
        return _capsules.where((capsule) => capsule['isLiked'] == true).toList();
      case 'DRAFT':
        return _capsules.where((capsule) => capsule['displayStatus'] == 'draft').toList();
      case 'OPENED':
        return _capsules.where((capsule) => capsule['displayStatus'] == 'opened').toList();
      default:
        return _capsules;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      )
          : _fadeAnimation != null
          ? FadeTransition(
        opacity: _fadeAnimation!,
        child: CustomScrollView(
          slivers: [
            // 앱바
            SliverAppBar(
              expandedHeight: 120,
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
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            '내 캡슐 📦',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ).createShader(bounds),
                            child: Text(
                              '캡슐 관리',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
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
                              icon: const Icon(
                                Icons.refresh,
                                color: Color(0xFF9CA3AF),
                                size: 24,
                              ),
                              onPressed: _loadCapsules,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_capsules.length}개',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 통계 카드들
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // 첫 번째 줄 통계
                    Row(
                      children: [
                        _buildStatCard(
                          '전체',
                          '${_capsules.length}',
                          Icons.archive_outlined,
                          const Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          '내가 만든',
                          '${_capsules.where((c) => c['isCreator'] == true).length}',
                          Icons.create_outlined,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          '공유받은',
                          '${_capsules.where((c) => c['isCreator'] != true).length}',
                          Icons.group_outlined,
                          const Color(0xFFEC4899),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 두 번째 줄 통계
                    Row(
                      children: [
                        _buildStatCard(
                          '임시저장',
                          '${_capsules.where((c) => c['displayStatus'] == 'draft').length}',
                          Icons.edit_outlined,
                          const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          '대기중',
                          '${_capsules.where((c) => c['displayStatus'] == 'waiting').length}',
                          Icons.lock_outline,
                          const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          '열림',
                          '${_capsules.where((c) => c['displayStatus'] == 'opened').length}',
                          Icons.celebration_outlined,
                          const Color(0xFF06B6D4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 카테고리 필터 버튼들
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _selectedCategoryNotifier,
                    builder: (context, selectedCategory, child) {
                      return Row(
                        children: [
                          _buildCategoryButton("ALL", "전체", Icons.all_inclusive),
                          const SizedBox(width: 8),
                          _buildCategoryButton("MINE", "내가 만든", Icons.person_outline),
                          const SizedBox(width: 8),
                          _buildCategoryButton("SHARED", "공유받은", Icons.group_outlined),
                          const SizedBox(width: 8),
                          _buildCategoryButton("LIKED", "좋아요", Icons.favorite_outline),
                          const SizedBox(width: 8),
                          _buildCategoryButton("DRAFT", "임시저장", Icons.edit_outlined),
                          const SizedBox(width: 8),
                          _buildCategoryButton("OPENED", "열림", Icons.celebration_outlined),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // 캡슐 리스트
            ValueListenableBuilder<String>(
              valueListenable: _selectedCategoryNotifier,
              builder: (context, selectedCategory, child) {
                final filteredCapsules = _getFilteredCapsules();

                if (filteredCapsules.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(child: _buildEmptyState()),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return _buildCapsuleCard(filteredCapsules[index]);
                      },
                      childCount: filteredCapsules.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      )
          : CustomScrollView(
        slivers: [
          // 간단한 헤더
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: const Text(
                '캡슐 관리',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}