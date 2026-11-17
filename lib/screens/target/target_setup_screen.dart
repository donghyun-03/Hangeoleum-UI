// 관심기업 · 직무 설정 — 튜토리얼 미션 '관심기업, 직무 입력하기'에서 진입 (전체 탭에서도 열 수 있음)
// 기업 이름 · 기업 유형 · 직무를 정하면 아래에 이 기업의 기준치(5개 영역)를 바로 보여 줍니다.
// 저장하면 true 를 돌려줍니다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/criteria_data.dart';
import '../../models/criteria.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TargetSetupScreen extends StatefulWidget {
  const TargetSetupScreen({super.key});

  @override
  State<TargetSetupScreen> createState() => _TargetSetupScreenState();
}

class _TargetSetupScreenState extends State<TargetSetupScreen> {
  late TargetCompany _t = context.read<AppState>().suggestedTarget;
  late final _name = TextEditingController(text: _t.name);
  late final _job = TextEditingController(text: _t.jobTitle);

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    super.dispose();
  }

  void _pickSample(String name, CompanyTier tier) {
    setState(() {
      _name.text = name;
      _t = _t.copyWith(name: name, tier: tier);
    });
  }

  void _save() {
    context.read<AppState>().setTarget(_t.copyWith(name: _name.text.trim(), jobTitle: _job.text.trim()));
    showToast(context, '관심기업을 저장했어요');
    Navigator.pop(context, true);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: AppText.small.copyWith(fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    final criteria = roughCriteriaFor(_t.copyWith(name: _name.text.trim(), jobTitle: _job.text.trim()));

    return Scaffold(
      appBar: AppBar(title: const Text('관심기업 설정')),
      bottomNavigationBar: BottomBar(child: AppButton(label: '저장하기', onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('어떤 기업에 가고 싶나요?', style: AppText.h2),
          const SizedBox(height: 4),
          Text('기업과 직무를 정하면 지원 기준치를 보여 드릴게요. 나중에 언제든 바꿀 수 있어요.', style: AppText.small),

          _label('기업 이름 (선택)'),
          LabeledField(
            controller: _name,
            hint: '예: 네이버, 한국전력공사',
            onChanged: (v) => setState(() => _t = _t.copyWith(name: v.trim())),
          ),
          const SizedBox(height: 8),
          ChipWrap(children: [
            for (final (name, tier) in kSampleCompanies)
              SelectChip(label: name, selected: _name.text.trim() == name, onTap: () => _pickSample(name, tier)),
          ]),

          _label('기업 유형'),
          ChipWrap(children: [
            for (final tier in CompanyTier.values)
              SelectChip(
                label: tier.label,
                selected: _t.tier == tier,
                onTap: () => setState(() => _t = _t.copyWith(tier: tier)),
              ),
          ]),

          _label('직무'),
          ChipWrap(children: [
            for (final g in JobGroup.values)
              SelectChip(
                label: g.label,
                selected: _t.jobGroup == g,
                onTap: () => setState(() => _t = _t.copyWith(jobGroup: g)),
              ),
          ]),
          const SizedBox(height: 8),
          LabeledField(
            controller: _job,
            hint: '구체적인 직무 (선택, 예: 백엔드 개발)',
            onChanged: (v) => setState(() => _t = _t.copyWith(jobTitle: v.trim())),
          ),

          SectionTitle('${criteria.target.label} 기준치'),
          AppCard(
            child: Column(children: [
              for (final area in CriteriaArea.values) _CriteriaRow(area: area, criteria: criteria),
            ]),
          ),
          Text(criteria.note, style: AppText.caption),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 기준치 한 줄 (영역 이름 · 기준)
class _CriteriaRow extends StatelessWidget {
  const _CriteriaRow({required this.area, required this.criteria});

  final CriteriaArea area;
  final CompanyCriteria criteria;

  String get _text => switch (area) {
        CriteriaArea.portfolio => _count(criteria.minPortfolio, '결과물', '개'),
        CriteriaArea.academic => [
            if (criteria.minEducation != EduLevel.none) criteria.minEducation.label,
            if (criteria.minGpa != null) '학점 ${criteria.minGpa!.toStringAsFixed(1)}/4.5',
          ].join(' · ').ifEmpty('학력·학점 안 봐요'),
        CriteriaArea.jobFit => _count(criteria.minJobFit, '직무 관련 경험', '개'),
        CriteriaArea.language => criteria.minEnglish == null ? '필수 아님' : 'TOEIC ${criteria.minEnglish} 이상 (환산)',
        CriteriaArea.teamwork => _count(criteria.minTeamwork, '팀 활동', '회'),
      };

  static String _count(int n, String what, String unit) => n <= 0 ? '필수 아님' : '$what $n$unit 이상';

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final optional = text == '필수 아님' || text == '학력·학점 안 봐요';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 84, child: Text(area.label, style: AppText.bodyBold.copyWith(fontSize: 13))),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: AppText.body.copyWith(fontSize: 13, color: optional ? AppColors.subtle : AppColors.ink),
          ),
        ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
