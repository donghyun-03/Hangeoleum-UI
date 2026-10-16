// STEP 3 · 도전 — 부트캠프·공모전·대외활동·교육 (북마크로 스크랩)
import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../router/routes.dart';
import '../../widgets/common.dart';
import '../../widgets/opportunity_card.dart';
import 'step_sort.dart';

class Step3Challenge extends StatefulWidget {
  const Step3Challenge({super.key, required this.sort});
  final StepSort sort;

  @override
  State<Step3Challenge> createState() => _Step3ChallengeState();
}

class _Step3ChallengeState extends State<Step3Challenge> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim();
    final list = sortOpportunities(
      mockOpportunities.where((o) => o.step == 3 && (q.isEmpty || '${o.title} ${o.org} ${o.field}'.contains(q))).toList(),
      widget.sort,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SearchField(
        controller: _search,
        hint: '프로그램 이름이나 키워드 검색',
        onChanged: (_) => setState(() {}),
        onFilter: () => showToast(context, '필터는 준비 중이에요'),
      ),
      const SizedBox(height: 12),
      if (list.isEmpty) const EmptyState(icon: Icons.search, title: '검색 결과가 없어요'),
      for (final o in list) OpportunityCard(o: o, onTap: () => AppNav.toComingSoon(context, o.title)),
    ]);
  }
}
