// 직무 검색해서 고르기 — 진단 채팅의 '해보고 싶은 직무는 뭐예요?' 와 내 기준 바꾸기에서 씁니다.
// 비어 있으면 관심 분야 직무를 먼저 보여 주고, 글자를 치면 그 글자가 들어간 직무가 바로 나와요.
// 목록(data/job_catalog.dart)에 없으면 친 글자 그대로 정할 수도 있어요.
import 'package:flutter/material.dart';

import '../data/job_catalog.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class JobSearchField extends StatefulWidget {
  const JobSearchField({
    super.key,
    required this.onSelected,
    this.field,
    this.selected,
    this.dark = false,
    this.autofocus = true,
    this.maxResults = 12,
  });

  /// 고른 직무 이름
  final ValueChanged<String> onSelected;

  /// 진단에서 고른 관심 분야 (이 분야 직무를 앞에 보여 줌)
  final String? field;

  /// 지금 정해 둔 직무 (내 기준 바꾸기에서 표시)
  final String? selected;

  /// 진단 채팅처럼 검은 칩으로 보일지
  final bool dark;
  final bool autofocus;
  final int maxResults;

  @override
  State<JobSearchField> createState() => _JobSearchFieldState();
}

class _JobSearchFieldState extends State<JobSearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim();
    final field = kJobCatalog.any((j) => j.field == widget.field) ? widget.field : null;
    // 글자가 없으면 관심 분야 직무만, 있으면 전체에서 검색 (관심 분야 먼저)
    final results = query.isEmpty && field != null
        ? kJobCatalog.where((j) => j.field == field).toList()
        : searchJobs(query, field: field);
    final shown = results.take(widget.maxResults).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          // 엔터를 누르면 맨 위 결과를 고릅니다
          onSubmitted: (_) {
            if (shown.isNotEmpty) widget.onSelected(shown.first.name);
          },
          decoration: InputDecoration(
            hintText: '직무 검색 (예: 데이터, 영상, 사무)',
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.subtle),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: '지우기',
                    icon: const Icon(Icons.close, size: 18, color: AppColors.subtle),
                    onPressed: () => setState(_ctrl.clear),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          query.isEmpty
              ? (field == null ? '직무를 검색하거나 아래에서 골라 주세요' : '$field 직무예요. 다른 직무는 검색해 보세요')
              : (results.isEmpty ? '"$query" 이(가) 들어간 직무가 없어요' : '"$query" 검색 결과 ${results.length}개'),
          style: AppText.caption,
        ),
        const SizedBox(height: 8),
        ChipWrap(
          children: [
            for (final j in shown)
              SelectChip(
                label: j.name,
                selected: j.name == widget.selected,
                dark: widget.dark,
                onTap: () => widget.onSelected(j.name),
              ),
            // 목록에 없는 직무는 친 글자 그대로 정할 수 있게
            if (query.isNotEmpty && !results.any((j) => j.name == query))
              SelectChip(
                label: "'$query' 그대로 쓰기",
                selected: false,
                onTap: () => widget.onSelected(query),
              ),
          ],
        ),
      ],
    );
  }
}
