// 내 정보 — 보기 화면 (팀원 프로필과 같은 구성). 연필 버튼으로 내 정보 수정 화면 이동
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editIntro(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        surfaceTintColor: AppColors.paper,
        title: Text('소개 수정', style: AppText.title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '간단한 소개를 적어 주세요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: AppColors.subtle)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('저장', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    context.read<AppState>().updateUser((u) => u.copyWith(intro: result));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.user;

    final myId = u.id; // 내 ID
    final step = u.currentStep;
    final intro = u.intro.isEmpty ? '안녕하세요, ${u.name}입니다.' : u.intro;

    final missions = state.doneMissionsOf(myId);
    final records = state.recordsOf(myId);
    final posts = state.teamPosts
        .where((p) => p.leaderId == myId || p.memberIds.contains(myId))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<AppState>().logout();
              AppNav.resetTo(context, Routes.login);
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(fontSize: 12.5, color: AppColors.subtle),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '내 정보 수정',
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.paper,
        elevation: 2,
        shape: const CircleBorder(),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
        ),
        child: const Icon(Icons.edit_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Avatar(name: u.name, size: 72)),
          const SizedBox(height: 10),
          Center(child: Text(u.name, style: AppText.h2)),
          const SizedBox(height: 4),
          Center(child: TagBadge('STEP $step · ${stepInfo[step]!.title}')),
          const SizedBox(height: 2),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _editIntro(intro),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      intro,
                      style: AppText.small.copyWith(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.subtle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _StatButton(
                  n: missions.length,
                  label: '완료한 미션',
                  onTap: () => AppNav.toMemberActivity(context, myId),
                ),
                _StatButton(
                  n: records.length,
                  label: '활동 기록',
                  onTap: () => AppNav.toMemberActivity(context, myId, tab: 1),
                ),
              ],
            ),
          ),
          const SectionTitle('관심 분야'),
          if (u.interests.isEmpty)
            Text(
              '선택한 관심 분야가 없어요.',
              style: AppText.caption.copyWith(fontSize: 12.5),
            )
          else
            ChipWrap(
              children: [
                for (final i in u.interests) TagBadge(i, tone: BadgeTone.gray),
              ],
            ),
          const SectionTitle('참여 중인 프로젝트'),
          if (posts.isEmpty)
            Text(
              '참여 중인 프로젝트가 없어요.',
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),
          for (final p in posts)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.category} · ${p.current}/${p.max}명',
                    style: AppText.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(p.title, style: AppText.bodyBold),
                  const SizedBox(height: 8),
                  AppButton(
                    label: '모집 글 보기',
                    small: true,
                    expand: false,
                    onPressed: () => AppNav.toTeamApply(context, p.id),
                  ),
                ],
              ),
            ),
          const SectionTitle('최근 활동 기록'),
          if (records.isEmpty)
            Text(
              '아직 활동 기록이 없어요.',
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),
          for (final r in records.take(2))
            AppCard(
              onTap: () => AppNav.toMemberActivity(context, myId, tab: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TagBadge('STEP ${r.step}', tone: BadgeTone.gray),
                      const SizedBox(width: 6),
                      Text(
                        r.date,
                        style: AppText.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.title, style: AppText.bodyBold),
                  Text(
                    r.star.r,
                    style: AppText.small.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatButton extends StatelessWidget {
  const _StatButton({required this.n, required this.label, this.onTap});
  final int n;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text('$n', style: AppText.h2.copyWith(color: AppColors.green)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.caption.copyWith(fontSize: 11)),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 13,
                      color: AppColors.subtle,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
