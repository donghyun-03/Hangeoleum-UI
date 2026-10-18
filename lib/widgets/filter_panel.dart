// 검색창 오른쪽 필터 아이콘을 누르면 열리는 필터 패널 (STEP 2 · STEP 4 공통)
//
// 쓰는 법
//   final groups = [FilterGroup('region', '지역', ['서울', '경기'])];
//   final selected = FilterSelection(groups);
//   FilterPanel(groups: groups, selection: selected, resultCount: n, onChanged: () => setState(() {}), onClose: ...)
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

class FilterGroup {
  const FilterGroup(this.key, this.label, this.options);
  final String key;
  final String label;
  final List<String> options;
}

/// 그룹별로 선택된 값. 같은 그룹 안에서는 OR, 그룹끼리는 AND 로 거릅니다.
class FilterSelection {
  FilterSelection(List<FilterGroup> groups) : _map = {for (final g in groups) g.key: <String>{}};
  final Map<String, Set<String>> _map;

  Set<String> of(String key) => _map[key] ?? const {};
  int get count => _map.values.fold(0, (n, s) => n + s.length);
  bool get isEmpty => count == 0;

  void toggle(String key, String value) {
    final set = _map.putIfAbsent(key, () => <String>{});
    if (!set.remove(value)) set.add(value);
  }

  void clear() {
    for (final s in _map.values) {
      s.clear();
    }
  }

  /// [key] 그룹에 선택이 없거나, [values] 중 하나라도 선택돼 있으면 통과
  bool matches(String key, Iterable<String?> values) {
    final sel = of(key);
    if (sel.isEmpty) return true;
    return values.any((v) => v != null && sel.contains(v));
  }
}

class FilterPanel extends StatelessWidget {
  const FilterPanel({
    super.key,
    required this.groups,
    required this.selection,
    required this.resultCount,
    required this.onChanged,
    required this.onClose,
  });

  final List<FilterGroup> groups;
  final FilterSelection selection;
  final int resultCount;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final g in groups) ...[
          Text(g.label, style: AppText.bodyBold.copyWith(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          ChipWrap(children: [
            for (final o in g.options)
              SelectChip(
                label: o,
                selected: selection.of(g.key).contains(o),
                onTap: () {
                  selection.toggle(g.key, o);
                  onChanged();
                },
              ),
          ]),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(
            child: AppButton(
              label: '초기화',
              small: true,
              variant: ButtonVariant.ghost,
              onPressed: selection.isEmpty
                  ? null
                  : () {
                      selection.clear();
                      onChanged();
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: AppButton(label: '$resultCount건 보기', small: true, onPressed: onClose)),
        ]),
      ]),
    );
  }
}

/// 필터 패널을 닫았을 때 선택된 필터를 칩으로 보여줌 (누르면 해제)
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({super.key, required this.groups, required this.selection, required this.onChanged});

  final List<FilterGroup> groups;
  final FilterSelection selection;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (selection.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ChipWrap(children: [
        for (final g in groups)
          for (final v in selection.of(g.key))
            RemovableChip(
              label: v,
              onRemove: () {
                selection.toggle(g.key, v);
                onChanged();
              },
            ),
      ]),
    );
  }
}

/// 선택된 값 + 닫기 아이콘 칩 (누르면 해제)
class RemovableChip extends StatelessWidget {
  const RemovableChip({super.key, required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.greenLight,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.green)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.greenDark)),
            const SizedBox(width: 4),
            const Icon(Icons.close, size: 14, color: AppColors.greenDark),
          ]),
        ),
      ),
    );
  }
}
