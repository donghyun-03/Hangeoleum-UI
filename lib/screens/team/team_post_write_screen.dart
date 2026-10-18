// 팀 모집 글쓰기 — STEP 2 '글쓰기' 버튼에서 진입
// 분야 · 제목 · 한 줄 소개 · 프로젝트 설명 · 구하는 팀원 · 모집 인원 · 기간 · 진행 방식 · 마감일 · 연락 링크
// 올리면 true 를 돌려주고 STEP 2 '내가 쓴 글' 탭으로 이동
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_panel.dart';

const _categories = ['데이터·엑셀', '공모전', '마케팅·기획', '디자인', '개발', '스터디', '기타'];
const _rolePresets = ['기획', '디자이너', '프론트엔드', '백엔드', '엑셀·데이터', '콘텐츠 기획', '발표', '상관없음'];
const _weeksOptions = [2, 4, 6, 8];
const _modes = ['온라인', '오프라인', '온·오프라인'];

class TeamPostWriteScreen extends StatefulWidget {
  const TeamPostWriteScreen({super.key});

  @override
  State<TeamPostWriteScreen> createState() => _TeamPostWriteScreenState();
}

class _TeamPostWriteScreenState extends State<TeamPostWriteScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _description = TextEditingController();
  final _customRole = TextEditingController();
  final _contact = TextEditingController();

  String? _category;
  final List<String> _roles = [];
  int _max = 3; // 나 포함 총 인원
  int _weeks = 4;
  int _perWeek = 1;
  String _mode = '온라인';
  DateTime? _deadline;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _desc, _description, _customRole, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleRole(String r) {
    setState(() {
      if (!_roles.remove(r)) _roles.add(r);
    });
  }

  void _addCustomRole() {
    final r = _customRole.text.trim();
    if (r.isEmpty || _roles.contains(r)) return;
    setState(() {
      _roles.add(r);
      _customRole.clear();
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _fail(String message) {
    setState(() => _error = message);
    showToast(context, message);
  }

  void _submit() {
    if (_category == null) return _fail('분야를 골라 주세요.');
    if (_title.text.trim().length < 2) return _fail('제목을 입력해 주세요.');
    if (_description.text.trim().length < 10) return _fail('프로젝트 설명을 10자 이상 적어 주세요.');
    if (_roles.isEmpty) return _fail('구하는 팀원을 하나 이상 골라 주세요.');
    final link = _contact.text.trim();
    if (link.isNotEmpty && !RegExp(r'^https?://.+\..+').hasMatch(link)) return _fail('연락 링크를 확인해 주세요.');

    final state = context.read<AppState>();
    final desc = _desc.text.trim();
    final description = _description.text.trim();
    // TODO(API): 모집 글 등록
    state.addTeamPost(TeamPost(
      id: 'tp-${DateTime.now().microsecondsSinceEpoch}',
      category: _category!,
      title: _title.text.trim(),
      desc: desc.isNotEmpty ? desc : description.split('\n').first,
      current: 1,
      max: _max,
      weeks: _weeks,
      perWeek: _perWeek,
      mode: _mode,
      leaderId: state.user.id,
      postedAgo: '방금 전',
      description: description,
      wantedRoles: List.of(_roles),
      deadline: _deadline == null ? null : _fmt(_deadline!),
      contactLink: link.isEmpty ? null : link,
    ));
    showToast(context, "모집 글을 올렸어요! '내가 쓴 글'에서 확인할 수 있어요");
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final customRoles = _roles.where((r) => !_rolePresets.contains(r)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('팀원 모집 글쓰기')),
      bottomNavigationBar: BottomBar(child: AppButton(label: '모집 글 올리기', onPressed: _submit)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          const SectionTitle('분야'),
          ChipWrap(children: [
            for (final c in _categories) SelectChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c)),
          ]),

          const SectionTitle('기본 정보'),
          LabeledField(label: '제목', hint: '예) 엑셀로 가계부 자동화 시트 같이 만들어요', controller: _title, maxLength: 40),
          const SizedBox(height: 12),
          LabeledField(label: '한 줄 소개 (목록에 보여요)', hint: '예) 엑셀 처음이어도 괜찮아요, 같이 공부하면서 만들어요', controller: _desc, maxLength: 50),

          const SectionTitle('프로젝트 설명'),
          LabeledField(
            controller: _description,
            maxLines: 7,
            maxLength: 1000,
            hint: '어떤 프로젝트인지, 목표와 진행 방식을 적어 주세요.\n\n'
                '예) 4주 동안 엑셀로 가계부 자동화 시트를 만들어요.\n'
                '1~2주차: 함수·피벗 같이 공부\n'
                '3~4주차: 각자 시트 완성 후 피드백\n'
                '결과물: 포트폴리오에 넣을 시트 + 회고 글',
          ),

          const SectionTitle('구하는 팀원', aside: '여러 개 선택'),
          ChipWrap(children: [
            for (final r in _rolePresets) SelectChip(label: r, selected: _roles.contains(r), onTap: () => _toggleRole(r)),
            for (final r in customRoles) RemovableChip(label: r, onRemove: () => _toggleRole(r)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: LabeledField(controller: _customRole, hint: '직접 입력 (예: 영상 편집)', maxLength: 15)),
            const SizedBox(width: 8),
            AppButton(label: '추가', small: true, expand: false, variant: ButtonVariant.outline, onPressed: _addCustomRole),
          ]),

          const SectionTitle('모집 인원 (나 포함)'),
          Row(children: [
            IconButton.outlined(
              tooltip: '인원 줄이기',
              onPressed: _max > 2 ? () => setState(() => _max--) : null,
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(width: 56, child: Text('$_max명', textAlign: TextAlign.center, style: AppText.h2.copyWith(fontSize: 16))),
            IconButton.outlined(
              tooltip: '인원 늘리기',
              onPressed: _max < 6 ? () => setState(() => _max++) : null,
              icon: const Icon(Icons.add, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('새로 구하는 인원 ${_max - 1}명', style: AppText.caption.copyWith(fontSize: 12))),
          ]),

          const SectionTitle('기간'),
          ChipWrap(children: [
            for (final w in _weeksOptions) SelectChip(label: '$w주', selected: _weeks == w, onTap: () => setState(() => _weeks = w)),
          ]),
          const SizedBox(height: 10),
          ChipWrap(children: [
            for (final n in [1, 2, 3]) SelectChip(label: '주 $n회', selected: _perWeek == n, onTap: () => setState(() => _perWeek = n)),
          ]),

          const SectionTitle('진행 방식'),
          Segmented<String>(
            value: _mode,
            onChanged: (v) => setState(() => _mode = v),
            options: [for (final m in _modes) (m, m)],
          ),

          const SectionTitle('모집 마감일', aside: '선택'),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_deadline == null ? '날짜 선택 (안 고르면 상시 모집)' : _fmt(_deadline!)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _deadline == null ? AppColors.muted : AppColors.ink,
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
            if (_deadline != null)
              IconButton(tooltip: '마감일 지우기', onPressed: () => setState(() => _deadline = null), icon: const Icon(Icons.close, size: 18)),
          ]),

          const SectionTitle('연락 방법', aside: '선택'),
          LabeledField(controller: _contact, hint: '오픈채팅 링크 (https://open.kakao.com/...)', keyboardType: TextInputType.url),
          const SizedBox(height: 6),
          Text('신청이 수락된 팀원에게만 보여 줄 예정이에요.', style: AppText.caption),
          ErrorText(_error),
        ],
      ),
    );
  }
}
