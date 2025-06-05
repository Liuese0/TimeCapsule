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
  Future<List<Map<String, dynamic>>> _fetchCapsules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("사용자 정보를 찾을 수 없습니다.");
      }

      final currentUserEmail = userDoc.data()?['id'] ?? '';
      if (currentUserEmail.isEmpty) {
        throw Exception("이메일 정보를 찾을 수 없습니다.");
      }

      final userLikes = List<String>.from(userDoc.data()?['like'] ?? []);

      final creatorQuerySnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .where('creatorId', isEqualTo: currentUser.uid)
          .get();

      final ownersQuerySnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .where('owners', arrayContains: currentUserEmail)
          .get();

      final capsules = creatorQuerySnapshot.docs + ownersQuerySnapshot.docs;

      final uniqueCapsules = {
        for (var doc in capsules) doc.id: doc
      }.values.toList();

      List<Map<String, dynamic>> capsulesWithNames = [];

      for (var doc in uniqueCapsules) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        if (data['openDate'] is Timestamp) {
          data['openDate'] = (data['openDate'] as Timestamp).toDate();
        }

        final creatorId = data['creatorId'];
        String creatorName = '알 수 없음';

        if (creatorId != null) {
          final creatorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(creatorId)
              .get();

          if (creatorDoc.exists) {
            creatorName = creatorDoc.data()?['name'] ?? '알 수 없음';
          }
        }

        data['creatorName'] = creatorName;
        data['isLiked'] = userLikes.contains(doc.id); // 좋아요 여부 추가
        capsulesWithNames.add(data);
      }

      return capsulesWithNames;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 실패: $e')),
      );
      return [];
    }
  }

  Future<void> _deleteCapsule(String capsuleId, String capsuleStatus) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDocRef =
    FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    try {
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        throw Exception("사용자 문서를 찾을 수 없습니다.");
      }

      final currentUserEmail = userDoc.data()?['id'] ?? '';
      final capsuleRef = FirebaseFirestore.instance.collection('capsules').doc(capsuleId);
      final capsuleSnapshot = await capsuleRef.get();

      if (!capsuleSnapshot.exists) {
        throw Exception("캡슐을 찾을 수 없습니다.");
      }

      final capsuleData = capsuleSnapshot.data()!;
      final isCreator = currentUser.uid == capsuleData['creatorId'];
      final owners = List<String>.from(capsuleData['owners'] ?? []);
      final deleteVotes = List<String>.from(capsuleData['deleteVotes'] ?? []);

      if (capsuleStatus == 'draft' && isCreator) {
        // 생성자가 'draft' 상태일 때 바로 삭제
        await capsuleRef.delete();
      } else if (owners.contains(currentUserEmail)) {
        // 공동소유주의 경우 삭제 투표
        final isAlreadyVoted = deleteVotes.contains(currentUserEmail);

        if (isAlreadyVoted) {
          deleteVotes.remove(currentUserEmail); // 투표 취소
        } else {
          deleteVotes.add(currentUserEmail); // 투표 추가
        }

        await capsuleRef.update({
          'deleteVotes': deleteVotes,
        });

        // 삭제 동의 인원 확인
        if (deleteVotes.length >= owners.length+1) {
          // 모든 소유주가 동의했을 경우 캡슐 삭제
          await capsuleRef.delete();
        }
      } else if (capsuleStatus != 'draft' && isCreator) {
        // 공동소유주의 경우 삭제 투표
        final isAlreadyVoted = deleteVotes.contains(currentUserEmail);

        if (isAlreadyVoted) {
          deleteVotes.remove(currentUserEmail); // 투표 취소
        } else {
          deleteVotes.add(currentUserEmail); // 투표 추가
        }

        await capsuleRef.update({
          'deleteVotes': deleteVotes,
        });

        // 삭제 동의 인원 확인
        if (deleteVotes.length >= owners.length+1) {
          // 모든 소유주가 동의했을 경우 캡슐 삭제
          await capsuleRef.delete();
        }
      }


      else {
        throw Exception("삭제 권한이 없습니다.");
      }

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('캡슐 삭제 실패: $e')),
      );
    }
  }


  Future<void> _confirmAndDeleteCapsule(String capsuleId, String capsuleStatus) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('캡슐 삭제'),
          content: const Text('정말로 이 캡슐을 삭제하시겠습니까? 삭제 후 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // 삭제 취소
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // 삭제 확인
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await _deleteCapsule(capsuleId, capsuleStatus);
    }
  }

  Future<void> _toggleLike(String capsuleId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDocRef =
    FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    try {
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        throw Exception("사용자 문서를 찾을 수 없습니다.");
      }

      final likes = List<String>.from(userDoc.data()?['like'] ?? []);
      if (likes.contains(capsuleId)) {
        // 이미 좋아요된 상태 -> 제거
        likes.remove(capsuleId);
      } else {
        // 좋아요 추가
        likes.add(capsuleId);
      }

      await userDocRef.update({'like': likes});
      setState(() {}); // UI 업데이트
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 상태 변경 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCapsules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('아직 생성된 캡슐이 없습니다.'));
          } else {
            final capsules = snapshot.data!;
            final now = DateTime.now();

            return ListView.builder(
              itemCount: capsules.length,
              itemBuilder: (context, index) {
                final capsule = capsules[index];
                final openDate = capsule['openDate'] as DateTime;
                final isLiked = capsule['isLiked'] ?? false;
                final status = capsule['status'];

                return GestureDetector(
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        content: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.favorite),
                              color: Colors.red,
                              onPressed: () async {
                                await _toggleLike(capsule['id']);
                                Navigator.pop(context); // 팝업 닫기
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colors.black,
                              onPressed: () async {
                                Navigator.pop(context); // 팝업 닫기
                                await _confirmAndDeleteCapsule(capsule['id'], status);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        capsule['name'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('${capsule['name']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('by ${capsule['creatorName']}'),
                          Builder(
                            builder: (context) {
                              final deleteVotes = List<String>.from(capsule['deleteVotes'] ?? []);
                              final owners = List<String>.from(capsule['owners'] ?? []);
                              return Text(
                                '삭제 투표: ${deleteVotes.length} / ${owners.length+1}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              );
                            },
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        status == 'draft'
                            ? const Icon(Icons.edit, color: Colors.blue)
                            : openDate.isAfter(now)
                            ? const Icon(Icons.lock, color: Colors.red)
                            : const Icon(Icons.celebration, color: Colors.green),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.favorite,
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (status == 'draft') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CapsuleDetailsScreen(
                              capsule: capsule,
                              isEditable: true,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() {});
                        }
                      } else if (openDate.isBefore(now) || openDate.isAtSameMomentAs(now)) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CapsuleDetailsScreen(
                              capsule: capsule,
                              isEditable: false,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() {});
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '열람일 (${DateFormat('yyyy-MM-dd').format(openDate)}) 이후에 확인할 수 있습니다.',
                            ),
                          ),
                        );
                      }
                    },
                  ),

                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CapsuleCreateScreen(
                onCapsuleCreated: (capsule) {
                  // 캡슐 생성 후 UI 갱신
                  setState(() {});
                },
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
