// [추가 기능 6] 프로그램 등록 (기관) — STEP 3·4 의 '글쓰기' 버튼에서 진입 (디자인 없음 → 임시 레이아웃)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _kindsByStep = {
  3: [OpportunityKind.bootcamp, OpportunityKind.contest, OpportunityKind.activity, OpportunityKind.education],
  4: [OpportunityKind.job],
};
final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class ProgramRegisterScreen extends StatefulWidget {
  const ProgramRegisterScreen({super.key});

  @override
  State<ProgramRegisterScreen> createState() => _ProgramRegisterScreenState();
}

class _ProgramRegisterScreenState extends State<ProgramRegisterScreen> {
  int _step = 3;
  OpportunityKind _kind = OpportunityKind.bootcamp;
  String? _error;
  late final Map<String, TextEditingController> _f = {
    for (final k in ['title', 'org', 'region', 'capacity', 'deadline', 'startDate', 'endDate', 'target', 'desc', 'link'])
      k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    if (user.role == UserRole.institution) _f['org']!.text = user.name;
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String k) => _f[k]!.text.trim();

  void _submit() {
    String? err;
    if (_v('title').isEmpty) {
      err = '프로그램 이름을 입력해 주세요.';
    } else if (_v('org').isEmpty) {
      err = '기관명을 입력해 주세요.';
    } else if (!_dateRe.hasMatch(_v('deadline'))) {
      err = '모집 마감일을 YYYY-MM-DD 형식으로 입력해 주세요.';
    } else if (_v('link').isNotEmpty && !RegExp(r'^https?://.+\..+').hasMatch(_v('link'))) {
      err = '신청 링크를 확인해 주세요.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // TODO(API): 등록 요청 → 관리자 검수 후 노출 여부 정하기
    context.read<AppState>().addProgram(Program(
          id: 'pg-${DateTime.now().microsecondsSinceEpoch}',
          step: _step,
          kind: _kind,
          title: _v('title'),
          org: _v('org'),
          region: _v('region'),
          capacity: _v('capacity'),
          deadline: _v('deadline'),
          startDate: _v('startDate'),
          endDate: _v('endDate'),
          target: _v('target'),
          desc: _v('desc'),
          link: _v('link'),
        ));
    showToast(context, '프로그램을 등록했어요');
    Navigator.pop(context);
  }

  Widget _row(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로그램 등록')),
      bottomNavigationBar: BottomBar(child: AppButton(label: '등록하기', onPressed: _submit)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle('노출할 단계'),
          Segmented<int>(
            value: _step,
            onChanged: (v) => setState(() {
              _step = v;
              _kind = _kindsByStep[v]!.first;
            }),
            options: const [(3, 'STEP 3 · 도전'), (4, 'STEP 4 · 취업')],
          ),
          const SectionTitle('유형'),
          ChipWrap(children: [
            for (final k in _kindsByStep[_step]!)
              SelectChip(label: kindLabel[k]!, selected: _kind == k, onTap: () => setState(() => _kind = k)),
          ]),
          const SectionTitle('기본 정보'),
          LabeledField(
            label: '프로그램 이름',
            hint: _step == 4 ? '예) 데이터 입력 사원 모집' : '예) 데이터 분석 입문 부트캠프',
            controller: _f['title'],
          ),
          const SizedBox(height: 12),
          LabeledField(label: '기관명', controller: _f['org']),
          const SizedBox(height: 12),
          _row(
            LabeledField(label: '지역', hint: '서울 / 온라인', controller: _f['region']),
            LabeledField(label: '모집 인원', hint: '예) 20명', controller: _f['capacity']),
          ),
          const SizedBox(height: 12),
          LabeledField(label: '모집 마감일', hint: 'YYYY-MM-DD', controller: _f['deadline'], keyboardType: TextInputType.datetime),
          const SizedBox(height: 12),
          _row(
            LabeledField(label: '진행 시작', hint: 'YYYY-MM-DD', controller: _f['startDate'], keyboardType: TextInputType.datetime),
            LabeledField(label: '진행 종료', hint: 'YYYY-MM-DD', controller: _f['endDate'], keyboardType: TextInputType.datetime),
          ),
          const SizedBox(height: 12),
          LabeledField(label: '지원 대상', hint: '예) 만 19-34세 미취업 청년', controller: _f['target']),
          const SizedBox(height: 12),
          LabeledField(label: '상세 설명', hint: '프로그램 내용, 일정, 혜택 등을 적어 주세요', controller: _f['desc'], maxLines: 5),
          const SizedBox(height: 12),
          LabeledField(label: '신청 링크 (선택)', hint: 'https://', controller: _f['link'], keyboardType: TextInputType.url),
          const TodoBox('날짜 입력은 showDatePicker 로, 포스터 이미지 첨부 추가'),
          ErrorText(_error),
          const SizedBox(height: 8),
          Text('등록한 프로그램은 검수 후 STEP ${_step == 3 ? '3 · 도전' : '4 · 취업'}에 노출돼요.', style: AppText.caption),
        ],
      ),
    );
  }
}
