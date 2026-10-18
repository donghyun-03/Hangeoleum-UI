// [추가 기능 6] 팀원 프로필 — STEP 2 팀 카드의 사람 아이콘에서 진입 (디자인 없음 → 임시 레이아웃)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context) {
    // TODO(API): 회원 공개 프로필 조회
    final state = context.watch<AppState>();
    final m = state.memberById(memberId);
    if (m == null) {
      return Scaffold(appBar: AppBar(title: const Text('팀원 프로필')), body: const EmptyState(title: '프로필을 찾을 수 없어요'));
    }
    // 팀장이거나 팀원으로 참여 중인 모집 글
    final posts = state.teamPosts.where((p) => p.leaderId == m.id || p.memberIds.contains(m.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('팀원 프로필')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Avatar(name: m.name, size: 72)),
          const SizedBox(height: 10),
          Center(child: Text(m.name, style: AppText.h2)),
          const SizedBox(height: 4),
          Center(child: TagBadge('STEP ${m.step} · ${stepInfo[m.step]!.title}')),
          const SizedBox(height: 10),
          Text(m.intro, style: AppText.small.copyWith(fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppCard(
            child: StatRow(center: true, items: [
              (m.missionsDone, '완료한 미션'),
              (m.records, '활동 기록'),
              (m.badges.length, '획득 배지'),
            ]),
          ),
          const SectionTitle('관심 분야'),
          ChipWrap(children: [for (final i in m.interests) TagBadge(i, tone: BadgeTone.gray)]),
          if (m.badges.isNotEmpty) ...[
            const SectionTitle('배지'),
            ChipWrap(children: [for (final b in m.badges) TagBadge(b)]),
          ],
          const SectionTitle('참여 중인 프로젝트'),
          if (posts.isEmpty) Text('참여 중인 프로젝트가 없어요.', style: AppText.caption.copyWith(fontSize: 12.5)),
          for (final p in posts)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.category} · ${p.current}/${p.max}명', style: AppText.caption.copyWith(fontSize: 11)),
                const SizedBox(height: 4),
                Text(p.title, style: AppText.bodyBold),
                const SizedBox(height: 8),
                AppButton(label: '모집 글 보기', small: true, expand: false, onPressed: () => AppNav.toTeamApply(context, p.id)),
              ]),
            ),
          const TodoBox("공개 범위(활동 기록 미리보기 노출 여부) 정해지면 '최근 활동 기록' 섹션 추가"),
        ],
      ),
    );
  }
}
