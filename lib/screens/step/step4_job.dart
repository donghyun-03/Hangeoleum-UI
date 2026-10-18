// STEP 4 · 취업 — 내 경험 요약 + 채용 공고 (북마크로 스크랩)
// 검색창 + 필터 (STEP 3 과 같은 형태). 필터: 지역 · 고용형태 · 경력 · 직무
// 오른쪽 위 '지원현황' 버튼은 step_screen.dart 에 있습니다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/opportunity_card.dart';
import 'step_sort.dart';

final _jobs = mockOpportunities.where((o) => o.step == 4).toList();

final _groups = [
  const FilterGroup('region', '지역', ['서울', '경기', '인천', '온라인']),
  const FilterGroup('employment', '고용형태', ['정규직', '계약직', '인턴']),
  const FilterGroup('career', '경력', ['신입', '경력무관']),
  FilterGroup('field', '직무', _jobs.map((j) => j.field).toSet().toList()),
];

class Step4Job extends StatefulWidget {
  const Step4Job({super.key, required this.sort});
  final StepSort sort;

  @override
  State<Step4Job> createState() => _Step4JobState();
}

class _Step4JobState extends State<Step4Job> {
  final _search = TextEditingController();
  final _filter = FilterSelection(_groups);
  bool _open = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _search.text.trim();
    // TODO(API): 서버 검색·필터로 교체
    final list = sortOpportunities(
      _jobs
          .where((j) => q.isEmpty || '${j.title} ${j.org} ${j.field}'.contains(q))
          .where((j) =>
              _filter.matches('region', [j.region]) &&
              _filter.matches('employment', [j.employment]) &&
              _filter.matches('career', [j.career]) &&
              _filter.matches('field', [j.field]))
          .toList(),
      widget.sort,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('내 경험 요약', style: AppText.bodyBold.copyWith(fontSize: 12.5))),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, Routes.recordList),
              child: Text('전체 보기 ›', style: AppText.caption),
            ),
          ]),
          const SizedBox(height: 10),
          StatRow(items: [
            (state.missions.where((m) => m.status == MissionStatus.done).length, '완료한 미션'),
            (state.records.length, '활동 기록'),
            (0, '정리한 포트폴리오'),
          ]),
        ]),
      ),
      const SizedBox(height: 4),

      // 검색창 + 필터 (STEP 3 과 같은 형태)
      SearchField(
        controller: _search,
        hint: '회사명, 직무로 검색',
        onChanged: (_) => setState(() {}),
        onFilter: () => setState(() => _open = !_open),
        filterCount: _filter.count,
        filterOpen: _open,
      ),
      if (_open)
        FilterPanel(
          groups: _groups,
          selection: _filter,
          resultCount: list.length,
          onChanged: () => setState(() {}),
          onClose: () => setState(() => _open = false),
        )
      else
        ActiveFilterChips(groups: _groups, selection: _filter, onChanged: () => setState(() {})),
      const SizedBox(height: 12),
      Text('채용 공고 ${list.length}건', style: AppText.bodyBold.copyWith(fontSize: 12.5)),
      const SizedBox(height: 8),
      if (list.isEmpty) const EmptyState(icon: Icons.search_off, title: '조건에 맞는 공고가 없어요', desc: '검색어나 필터를 줄여 보세요.'),
      for (final o in list) OpportunityCard(o: o, onTap: () => AppNav.toComingSoon(context, o.title)),
    ]);
  }
}
