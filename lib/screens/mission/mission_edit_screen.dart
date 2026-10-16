// [추가 기능 2] 미션 수정 — 진행 중 미션의 마감일 변경 / 완료 처리 / 그만두기 / 다른 미션으로 바꾸기
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MissionEditScreen extends StatefulWidget {
  const MissionEditScreen({super.key});

  @override
  State<MissionEditScreen> createState() => _MissionEditScreenState();
}

class _MissionEditScreenState extends State<MissionEditScreen> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final doing = state.missions.where((m) => m.status == MissionStatus.doing).toList();
    final todo = state.missions.where((m) => m.status == MissionStatus.todo).toList();
    _openId ??= doing.isEmpty ? null : doing.first.id;

    return Scaffold(
      appBar: AppBar(title: const Text('미션 수정')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('마감이 다가오거나 상황이 바뀌면 진행 중인 미션을 바꿀 수 있어요.', style: AppText.small),
          const SizedBox(height: 14),
          if (doing.isEmpty)
            const EmptyState(icon: Icons.check_circle_outline, title: '진행 중인 미션이 없어요', desc: 'STEP 탭에서 미션을 골라 시작해 보세요.'),
          for (final m in doing)
            _MissionEditCard(
              key: ValueKey(m.id),
              m: m,
              todo: todo,
              open: _openId == m.id,
              onToggle: () => setState(() => _openId = _openId == m.id ? '' : m.id),
            ),
        ],
      ),
    );
  }
}

class _MissionEditCard extends StatefulWidget {
  const _MissionEditCard({super.key, required this.m, required this.todo, required this.open, required this.onToggle});

  final Mission m;
  final List<Mission> todo;
  final bool open;
  final VoidCallback onToggle;

  @override
  State<_MissionEditCard> createState() => _MissionEditCardState();
}

class _MissionEditCardState extends State<_MissionEditCard> {
  String? _swapTo;

  String _fmt(DateTime? d) => d == null ? '없음' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.m.due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      context.read<AppState>().updateMission(widget.m.id, (m) => m.copyWith(due: picked));
    }
  }

  void _addDays(int d) {
    final base = widget.m.due ?? DateTime.now();
    context.read<AppState>().updateMission(widget.m.id, (m) => m.copyWith(due: base.add(Duration(days: d))));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final state = context.read<AppState>();
    return AppCard(
      onTap: widget.open ? null : widget.onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: AppText.bodyBold),
                Text('${m.minutes}분 · ${m.category} · 마감 ${_fmt(m.due)}', style: AppText.caption),
              ]),
            ),
            const TagBadge('진행 중'),
          ]),
          if (widget.open) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text('마감일 변경', style: AppText.bodyBold.copyWith(fontSize: 12.5)),
            const SizedBox(height: 8),
            ChipWrap(children: [
              SelectChip(label: '날짜 선택', selected: false, onTap: _pickDue),
              SelectChip(label: '+3일', selected: false, onTap: () => _addDays(3)),
              SelectChip(label: '+7일', selected: false, onTap: () => _addDays(7)),
            ]),
            const SizedBox(height: 16),
            Text('다른 미션으로 바꾸기', style: AppText.bodyBold.copyWith(fontSize: 12.5)),
            const SizedBox(height: 8),
            ChipWrap(children: [
              for (final t in widget.todo)
                SelectChip(label: t.title, selected: _swapTo == t.id, onTap: () => setState(() => _swapTo = t.id)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: AppButton(
                  label: '그만두기',
                  small: true,
                  variant: ButtonVariant.ghost,
                  onPressed: () {
                    state.updateMission(m.id, (x) => x.copyWith(status: MissionStatus.todo, clearDue: true));
                    showToast(context, '미션을 그만뒀어요');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '완료로 변경',
                  small: true,
                  variant: ButtonVariant.outline,
                  onPressed: () {
                    state.updateMission(m.id, (x) => x.copyWith(status: MissionStatus.done));
                    showToast(context, '완료로 바꿨어요');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '바꾸기',
                  small: true,
                  onPressed: _swapTo == null
                      ? null
                      : () {
                          state.swapMission(m.id, _swapTo!);
                          showToast(context, '다른 미션으로 바꿨어요');
                        },
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
