// 팀 신청 (모집 글 상세) — STEP 2 팀 카드를 누르면 진입
// 위: 모집 글 요약 → 팀원(팀장 + 팀원, 누르면 프로필) → 프로젝트 소개 → 구하는 팀원
// 아래: 신청 폼 (내 글이면 신청 대신 안내). 신청하면 true 를 돌려주고 STEP 2 '내가 신청한 글' 탭으로 이동
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

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

  void _fail(String message) {
    setState(() => _error = message);
    showToast(context, message); // 폼이 길어서 아래 에러 문구가 안 보일 수 있으니 토스트로도 알림
  }

  void _submit() {
    if (_role == null) return _fail('맡고 싶은 역할을 골라 주세요.');
    if (_time == null) return _fail('참여 가능한 시간을 골라 주세요.');
    if (_message.text.trim().length < 5) return _fail('팀장에게 한마디를 5자 이상 남겨 주세요.');

    // TODO(API): 신청 전송
    context.read<AppState>().applyTeam(TeamApplication(
          postId: widget.postId,
          role: _role!,
          availableTime: _time!,
          message: _message.text.trim(),
          sharedRecordIds: _shared.toList(),
          appliedAt: DateTime.now(),
        ));
    showToast(context, _prev == null ? "신청했어요! '내가 신청한 글'에서 확인할 수 있어요" : '신청 내용을 수정했어요');
    Navigator.pop(context, true);
  }

  void _cancel() {
    context.read<AppState>().cancelTeamApplication(widget.postId);
    showToast(context, '신청을 취소했어요');
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final post = state.teamPostById(widget.postId);
    if (post == null) {
      return Scaffold(appBar: AppBar(title: const Text('팀 신청')), body: const EmptyState(title: '모집 글을 찾을 수 없어요'));
    }
    final mine = state.isMyPost(post);
    final canApply = !mine && (!post.isFull || _prev != null);

    return Scaffold(
      appBar: AppBar(title: Text(mine ? '내 모집 글' : '팀 신청')),
      bottomNavigationBar: canApply
          ? BottomBar(child: AppButton(label: _prev == null ? '신청하기' : '신청 수정하기', onPressed: _submit))
          : null,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PostSummary(post: post),
          _Members(post: post),
          const SectionTitle('프로젝트 소개'),
          Text(
            post.description.isEmpty ? post.desc : post.description,
            style: AppText.body.copyWith(fontSize: 13.5, height: 1.65),
          ),
          if (post.contactLink != null && post.contactLink!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(post.contactLink!, style: AppText.caption.copyWith(color: AppColors.muted))),
            ]),
          ],
          const SectionTitle('구하는 팀원'),
          if (post.wantedRoles.isEmpty)
            Text('상관없어요', style: AppText.small)
          else
            ChipWrap(children: [for (final r in post.wantedRoles) _RoleTag(r)]),

          const SizedBox(height: 8),
          const Divider(),
          if (mine) ...[
            const SizedBox(height: 16),
            AppCard(
              color: AppColors.soft,
              child: Text('내가 쓴 모집 글이에요. 신청이 들어오면 알림으로 알려 드릴게요.', style: AppText.small.copyWith(fontSize: 13)),
            ),
            const TodoBox('신청자 목록 · 수락/거절, 글 수정/마감 기능 (API 정해지면)'),
          ] else if (!canApply) ...[
            const SizedBox(height: 16),
            AppCard(color: AppColors.soft, child: Text('모집이 끝난 팀이에요.', style: AppText.small.copyWith(fontSize: 13))),
          ] else ...[
            if (_prev != null) _AppliedBanner(application: _prev, onCancel: _cancel),
            const SectionTitle('맡고 싶은 역할'),
            ChipWrap(children: [
              // 팀이 구하는 역할 + '상관없어요'
              for (final r in {...post.wantedRoles.where((x) => x != '상관없음'), '상관없어요'})
                SelectChip(label: r, selected: _role == r, onTap: () => setState(() => _role = r)),
            ]),
            const SectionTitle('참여 가능한 시간'),
            ChipWrap(children: [
              for (final t in _times) SelectChip(label: t, selected: _time == t, onTap: () => setState(() => _time = t)),
            ]),
            const SectionTitle('팀장에게 한마디'),
            LabeledField(controller: _message, maxLines: 4, maxLength: 300, hint: '예) 엑셀은 처음이지만 꾸준히 참여할 수 있어요!'),
            SectionTitle('내 활동 기록 함께 보내기', aside: '선택'),
            for (final r in state.records)
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
        ],
      ),
    );
  }
}

class _PostSummary extends StatelessWidget {
  const _PostSummary({required this.post});
  final TeamPost post;

  @override
  Widget build(BuildContext context) {
    final p = post;
    return AppCard(
      color: AppColors.soft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(p.category, style: AppText.caption.copyWith(fontSize: 11)),
          const SizedBox(width: 6),
          TagBadge(p.isFull ? '모집 완료' : '모집 중 ${p.current}/${p.max}명', tone: p.isFull ? BadgeTone.gray : BadgeTone.green),
        ]),
        const SizedBox(height: 6),
        Text(p.title, style: AppText.h2.copyWith(fontSize: 17)),
        Text(p.desc, style: AppText.small.copyWith(fontSize: 12.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _Meta(Icons.calendar_today_outlined, '${p.weeks}주 · 주 ${p.perWeek}회'),
          _Meta(Icons.place_outlined, p.mode),
          if (p.deadline != null) _Meta(Icons.timer_outlined, '${p.deadline!.substring(5).replaceAll('-', '/')} 모집 마감'),
        ]),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text, style: AppText.caption.copyWith(fontSize: 12, color: AppColors.muted)),
      ]);
}

/// 팀장 + 팀원 + 남은 자리. 누르면 팀원 프로필
class _Members extends StatelessWidget {
  const _Members({required this.post});
  final TeamPost post;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final people = [post.leaderId, ...post.memberIds].map(state.memberById).whereType<TeamMember>().toList();
    final empty = (post.max - post.current).clamp(0, 6);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('팀원 ${post.current}/${post.max}'),
      SizedBox(
        height: 92,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final m in people)
              _MemberTile(
                name: m.id == state.user.id ? '${m.name}(나)' : m.name,
                sub: m.id == post.leaderId ? '팀장' : '팀원',
                leader: m.id == post.leaderId,
                onTap: () => AppNav.toMemberProfile(context, m.id),
              ),
            for (var i = 0; i < empty; i++) const _EmptySeat(),
          ],
        ),
      ),
    ]);
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.name, required this.sub, required this.leader, required this.onTap});
  final String name;
  final String sub;
  final bool leader;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(children: [
            Avatar(name: name, size: 46, color: leader ? AppColors.green : AppColors.dim),
            const SizedBox(height: 4),
            Text(name, style: AppText.bodyBold.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
            Text(sub, style: AppText.caption.copyWith(fontSize: 10.5, color: leader ? AppColors.green : AppColors.subtle)),
          ]),
        ),
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 64,
        child: Column(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.dim)),
            child: const Icon(Icons.person_add_alt_outlined, size: 20, color: AppColors.subtle),
          ),
          const SizedBox(height: 4),
          Text('빈 자리', style: AppText.caption.copyWith(fontSize: 11)),
        ]),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag(this.role);
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.greenLine),
      ),
      child: Text(role, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
    );
  }
}

class _AppliedBanner extends StatelessWidget {
  const _AppliedBanner({required this.application, required this.onCancel});
  final TeamApplication application;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        const Icon(Icons.check_circle, size: 18, color: AppColors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '신청 완료 · ${applicationStatusLabel[application.status]}\n${application.role} · ${application.availableTime}',
            style: AppText.small.copyWith(fontSize: 12.5, color: AppColors.greenDark),
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('신청 취소', style: TextStyle(fontSize: 12, color: AppColors.subtle))),
      ]),
    );
  }
}
