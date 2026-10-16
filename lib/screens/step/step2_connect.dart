// STEP 2 · 연결 — 미니 프로젝트 팀 모집
// [추가 기능 4] 검색창
// 팀 카드 사람 아이콘 → 팀원 프로필 / (+) → 팀 신청
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'step_sort.dart';

class Step2Connect extends StatefulWidget {
  const Step2Connect({super.key, required this.sort});
  final StepSort sort;

  @override
  State<Step2Connect> createState() => _Step2ConnectState();
}

class _Step2ConnectState extends State<Step2Connect> {
  final _search = TextEditingController();
  bool _mineOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _search.text.trim().toLowerCase();

    // TODO(API): 서버 검색으로 교체
    var list = mockTeamPosts.where((p) => q.isEmpty || '${p.title} ${p.desc} ${p.category}'.toLowerCase().contains(q)).toList();
    if (_mineOnly) list = list.where((p) => state.applicationFor(p.id) != null).toList();
    if (widget.sort == StepSort.name) list.sort((a, b) => a.title.compareTo(b.title));
    if (widget.sort == StepSort.deadline) list.sort((a, b) => (b.current / b.max).compareTo(a.current / a.max)); // 자리 적게 남은 순

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // [추가 기능 4] 검색창
      SearchField(controller: _search, hint: '프로젝트 이름, 분야로 검색', onChanged: (_) => setState(() {})),
      const SizedBox(height: 10),
      Row(children: [
        for (final (mine, label) in [(false, '모집 중'), (true, '내가 신청한 글')])
          TextButton(
            onPressed: () => setState(() => _mineOnly = mine),
            child: Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: _mineOnly == mine ? FontWeight.w700 : FontWeight.w400, color: _mineOnly == mine ? AppColors.ink : AppColors.subtle)),
          ),
      ]),
      if (list.isEmpty) const EmptyState(icon: Icons.search, title: '찾는 프로젝트가 없어요'),
      for (final p in list)
        Builder(builder: (context) {
          final leader = findMember(p.leaderId);
          final applied = state.applicationFor(p.id) != null;
          return AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(p.category, style: AppText.caption.copyWith(fontSize: 11)),
                const SizedBox(width: 6),
                TagBadge('모집 중 ${p.current}/${p.max}명'),
                if (applied) ...[const SizedBox(width: 6), const TagBadge('신청함', tone: BadgeTone.dark)],
              ]),
              const SizedBox(height: 6),
              Text(p.title, style: AppText.bodyBold),
              Text(p.desc, style: AppText.small.copyWith(fontSize: 12)),
              const SizedBox(height: 4),
              Text('${p.weeks}주 · 주 ${p.perWeek}회 · ${p.mode} · ${p.postedAgo}', style: AppText.caption),
              const SizedBox(height: 6),
              Row(children: [
                if (leader != null)
                  InkWell(
                    onTap: () => AppNav.toMemberProfile(context, leader.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Avatar(name: leader.name, size: 24, color: AppColors.dim),
                        const SizedBox(width: 6),
                        Text('${leader.name}님', style: AppText.small.copyWith(fontSize: 12)),
                      ]),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: '팀 신청',
                  onPressed: () => AppNav.toTeamApply(context, p.id),
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
                ),
              ]),
            ]),
          );
        }),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: () => AppNav.toComingSoon(context, '팀원 모집 글쓰기'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('글쓰기'),
        ),
      ),
    ]);
  }
}
