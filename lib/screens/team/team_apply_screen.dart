// [추가 기능 6] 팀 신청 — STEP 2 팀 카드의 (+) 에서 진입 (디자인 없음 → 임시 레이아웃)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _roles = ['기획', '자료 조사', '디자인', '엑셀·데이터', '발표', '아무거나 괜찮아요'];
const _times = ['평일 낮', '평일 저녁', '주말', '상관없어요'];

class TeamApplyScreen extends StatefulWidget {
  const TeamApplyScreen({super.key, required this.postId});
  final String postId;

  @override
  State<TeamApplyScreen> createState() => _TeamApplyScreenState();
}

class _TeamApplyScreenState extends State<TeamApplyScreen> {
  late final TeamApplication? _prev = context.read<AppState>().applicationFor(widget.postId);
  late String? _role = _prev?.role;
  late String? _time = _prev?.availableTime;
  late final _message = TextEditingController(text: _prev?.message ?? '');
  late final Set<String> _shared = {...?_prev?.sharedRecordIds};
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    String? err;
    if (_role == null) {
      err = '맡고 싶은 역할을 골라 주세요.';
    } else if (_time == null) {
      err = '참여 가능한 시간을 골라 주세요.';
    } else if (_message.text.trim().length < 5) {
      err = '팀장에게 한마디를 남겨 주세요.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // TODO(API): 신청 전송
    context.read<AppState>().applyTeam(TeamApplication(
          postId: widget.postId,
          role: _role!,
          availableTime: _time!,
          message: _message.text.trim(),
          sharedRecordIds: _shared.toList(),
        ));
    showToast(context, _prev == null ? '신청했어요. 팀장이 수락하면 알림으로 알려 드릴게요' : '신청 내용을 수정했어요');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final post = findTeamPost(widget.postId);
    if (post == null) {
      return Scaffold(appBar: AppBar(title: const Text('팀 신청')), body: const EmptyState(title: '모집 글을 찾을 수 없어요'));
    }
    final leader = findMember(post.leaderId);
    final records = context.watch<AppState>().records;

    return Scaffold(
      appBar: AppBar(title: const Text('팀 신청')),
      bottomNavigationBar: BottomBar(child: AppButton(label: _prev == null ? '신청하기' : '신청 수정하기', onPressed: _submit)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: AppColors.soft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(post.category, style: AppText.caption.copyWith(fontSize: 11)),
                const SizedBox(width: 6),
                TagBadge('모집 중 ${post.current}/${post.max}명'),
              ]),
              const SizedBox(height: 6),
              Text(post.title, style: AppText.bodyBold),
              Text('${post.weeks}주 · 주 ${post.perWeek}회 · ${post.mode}', style: AppText.caption),
              if (leader != null)
                InkWell(
                  onTap: () => AppNav.toMemberProfile(context, leader.id),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Avatar(name: leader.name, size: 22, color: AppColors.dim),
                      const SizedBox(width: 6),
                      Text('팀장 ${leader.name}님 ›', style: AppText.small.copyWith(fontSize: 12)),
                    ]),
                  ),
                ),
            ]),
          ),
          const SectionTitle('맡고 싶은 역할'),
          ChipWrap(children: [
            for (final r in _roles) SelectChip(label: r, selected: _role == r, onTap: () => setState(() => _role = r)),
          ]),
          const SectionTitle('참여 가능한 시간'),
          ChipWrap(children: [
            for (final t in _times) SelectChip(label: t, selected: _time == t, onTap: () => setState(() => _time = t)),
          ]),
          const SectionTitle('팀장에게 한마디'),
          LabeledField(controller: _message, maxLines: 4, maxLength: 300, hint: '예) 엑셀은 처음이지만 꾸준히 참여할 수 있어요!'),
          const SectionTitle('내 활동 기록 함께 보내기', aside: '선택'),
          for (final r in records)
            CheckboxListTile(
              value: _shared.contains(r.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _shared.add(r.id);
                } else {
                  _shared.remove(r.id);
                }
              }),
              title: Text(r.title, style: AppText.body.copyWith(fontSize: 13)),
              subtitle: Text('STEP ${r.step} · ${r.date}', style: AppText.caption.copyWith(fontSize: 11)),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.green,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ErrorText(_error),
        ],
      ),
    );
  }
}
