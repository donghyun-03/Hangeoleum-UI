// STEP 2 · 연결 — 미니 프로젝트 팀 모집
// 검색창 + 필터 (STEP 3 과 같은 형태). 필터: 분야 · 구하는 팀원 · 진행 방식 · 기간
// 탭: 모집 중 / 내가 신청한 글 / 내가 쓴 글
// 카드 → 팀 신청(상세) / 팀원 아바타 → 팀원 프로필 / 글쓰기 → 팀 모집 글쓰기
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_panel.dart';
import 'step_sort.dart';

enum _Tab { open, applied, mine }

class Step2Connect extends StatefulWidget {
  const Step2Connect({super.key, required this.sort});
  final StepSort sort;

  @override
  State<Step2Connect> createState() => _Step2ConnectState();
}

class _Step2ConnectState extends State<Step2Connect> {
  final _search = TextEditingController();
  _Tab _tab = _Tab.open;
  bool _filterOpen = false;
  List<FilterGroup> _groups = const [];
  FilterSelection? _filter;
  String _groupsSig = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 필터 선택지는 모집 글에서 뽑아요 (새 글이 생기면 선택지도 늘어남)
  void _syncGroups(List<TeamPost> posts) {
    final categories = {for (final p in posts) p.category}.toList();
    final roles = {for (final p in posts) ...p.wantedRoles}.toList();
    _groupsSig = _sig(posts);
    final groups = [
      FilterGroup('category', '분야', categories),
      FilterGroup('role', '구하는 팀원', roles),
      const FilterGroup('mode', '진행 방식', ['온라인', '오프라인', '온·오프라인']),
      const FilterGroup('weeks', '기간', ['4주 이하', '5~8주', '9주 이상']),
    ];
    final old = _filter;
    _groups = groups;
    _filter = FilterSelection(groups);
    // 기존 선택 유지
    if (old != null) {
      for (final g in groups) {
        for (final v in old.of(g.key)) {
          if (g.options.contains(v)) _filter!.toggle(g.key, v);
        }
      }
    }
  }

  String _sig(List<TeamPost> posts) =>
      '${{for (final p in posts) p.category}.join(',')}|${{for (final p in posts) ...p.wantedRoles}.join(',')}';

  String _weeksBucket(int w) => w <= 4 ? '4주 이하' : (w <= 8 ? '5~8주' : '9주 이상');

  Future<void> _openPost(TeamPost p) async {
    final applied = await AppNav.toTeamApply(context, p.id);
    if (applied == true && mounted) setState(() => _tab = _Tab.applied);
  }

  Future<void> _write() async {
    final posted = await Navigator.pushNamed<bool>(context, Routes.teamPostWrite);
    if (posted == true && mounted) setState(() => _tab = _Tab.mine);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final posts = state.teamPosts;
    if (_filter == null || _groupsSig != _sig(posts)) _syncGroups(posts);
    final filter = _filter!;
    final q = _search.text.trim().toLowerCase();

    final appliedCount = posts.where((p) => state.applicationFor(p.id) != null).length;
    final mineCount = posts.where(state.isMyPost).length;

    // TODO(API): 서버 검색·필터로 교체
    var list = posts.where((p) {
      final inTab = switch (_tab) {
        _Tab.open => !state.isMyPost(p),
        _Tab.applied => state.applicationFor(p.id) != null,
        _Tab.mine => state.isMyPost(p),
      };
      return inTab &&
          (q.isEmpty || '${p.title} ${p.desc} ${p.category} ${p.wantedRoles.join(' ')}'.toLowerCase().contains(q)) &&
          filter.matches('category', [p.category]) &&
          filter.matches('role', p.wantedRoles) &&
          filter.matches('mode', [p.mode]) &&
          filter.matches('weeks', [_weeksBucket(p.weeks)]);
    }).toList();
    if (widget.sort == StepSort.name) list.sort((a, b) => a.title.compareTo(b.title));
    if (widget.sort == StepSort.deadline) {
      list.sort((a, b) => (a.deadline ?? '9999').compareTo(b.deadline ?? '9999'));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 검색창 + 필터 (STEP 3 과 같은 형태)
      SearchField(
        controller: _search,
        hint: '프로젝트 이름, 분야, 역할로 검색',
        onChanged: (_) => setState(() {}),
        onFilter: () => setState(() => _filterOpen = !_filterOpen),
        filterCount: filter.count,
        filterOpen: _filterOpen,
      ),
      if (_filterOpen)
        FilterPanel(
          groups: _groups,
          selection: filter,
          resultCount: list.length,
          onChanged: () => setState(() {}),
          onClose: () => setState(() => _filterOpen = false),
        )
      else
        ActiveFilterChips(groups: _groups, selection: filter, onChanged: () => setState(() {})),
      const SizedBox(height: 12),

      // 탭
      Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          for (final (t, label) in [
            (_Tab.open, '모집 중'),
            (_Tab.applied, '내가 신청한 글 $appliedCount'),
            (_Tab.mine, '내가 쓴 글 $mineCount'),
          ])
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _tab == t ? AppColors.ink : Colors.transparent, width: 2)),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _tab == t ? FontWeight.w700 : FontWeight.w400,
                      color: _tab == t ? AppColors.ink : AppColors.subtle,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),

      if (list.isEmpty)
        EmptyState(
          icon: _tab == _Tab.open ? Icons.search_off : Icons.inbox_outlined,
          title: switch (_tab) {
            _Tab.open => '찾는 프로젝트가 없어요',
            _Tab.applied => '아직 신청한 팀이 없어요',
            _Tab.mine => '아직 쓴 모집 글이 없어요',
          },
          desc: switch (_tab) {
            _Tab.open => '검색어나 필터를 줄여 보세요.',
            _Tab.applied => '모집 중인 글에서 마음에 드는 팀에 신청해 보세요.',
            _Tab.mine => '아래 글쓰기로 함께할 팀원을 모아 보세요.',
          },
        ),
      for (final p in list) _TeamPostCard(post: p, onTap: () => _openPost(p)),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: _write,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('글쓰기'),
        ),
      ),
    ]);
  }
}

class _TeamPostCard extends StatelessWidget {
  const _TeamPostCard({required this.post, required this.onTap});
  final TeamPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = post;
    final application = state.applicationFor(p.id);
    final mine = state.isMyPost(p);
    final people = [p.leaderId, ...p.memberIds].map(state.memberById).whereType<TeamMember>().toList();

    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(p.category, style: AppText.caption.copyWith(fontSize: 11)),
          TagBadge(p.isFull ? '모집 완료' : '모집 중 ${p.current}/${p.max}명', tone: p.isFull ? BadgeTone.gray : BadgeTone.green),
          if (mine) const TagBadge('내 글', tone: BadgeTone.dark),
          if (application != null)
            TagBadge('신청 완료 · ${applicationStatusLabel[application.status]}', tone: BadgeTone.dark),
        ]),
        const SizedBox(height: 6),
        Text(p.title, style: AppText.bodyBold),
        Text(p.desc, style: AppText.small.copyWith(fontSize: 12)),
        if (p.wantedRoles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final r in p.wantedRoles) TagBadge(r, tone: BadgeTone.gray),
          ]),
        ],
        const SizedBox(height: 8),
        Text(
          [
            '${p.weeks}주',
            '주 ${p.perWeek}회',
            p.mode,
            if (p.deadline != null) '~${p.deadline!.substring(5).replaceAll('-', '/')} 마감',
            p.postedAgo,
          ].join(' · '),
          style: AppText.caption,
        ),
        const SizedBox(height: 6),
        Row(children: [
          // 팀원 아바타 (누르면 팀원 프로필)
          for (final m in people.take(4))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => AppNav.toMemberProfile(context, m.id),
                child: Tooltip(message: '${m.name} 프로필', child: Avatar(name: m.name, size: 26, color: m.id == p.leaderId ? AppColors.green : AppColors.dim)),
              ),
            ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              people.isEmpty ? '' : '${people.first.name}${mine ? '(나)' : '님'}${people.length > 1 ? ' 외 ${people.length - 1}명' : ''}',
              style: AppText.small.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!mine && application == null && !p.isFull)
            IconButton(
              tooltip: '팀 신청',
              onPressed: onTap,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
            ),
        ]),
      ]),
    );
  }
}
