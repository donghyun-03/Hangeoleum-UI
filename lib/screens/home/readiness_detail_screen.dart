// 홈 준비도 "자세히 보기": 항목별 점수, 부족한 점, 반영된 근거, 계산 방법

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../router/routes.dart';
import '../../services/readiness_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/home/readiness_card.dart';

class ReadinessDetailScreen extends StatelessWidget {
  const ReadinessDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppState>().readiness;
    final weakest = r.weakest.area;
    // 부족한 항목이 위로 오도록: 채우면 많이 오르는 순
    final areas = [...r.shownAreas]..sort((a, b) => b.gain.compareTo(a.gain));

    return Scaffold(
      appBar: AppBar(title: const Text('준비도 자세히 보기')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('준비도 ${r.score}점 · ${r.levelLabel}', style: AppText.h2),
          const SizedBox(height: 4),
          Text('기준: ${r.target.label} · ${r.source == ReadinessSource.ai ? 'AI 판단' : '기본 계산'}', style: AppText.caption),
          if (r.summary != null) ...[
            const SizedBox(height: 8),
            Text(r.summary!, style: AppText.small),
          ],
          const SizedBox(height: 16),
          for (final a in areas) _AreaDetail(area: a, highlight: a.area == weakest),
          const SizedBox(height: 8),
          const SectionTitle('준비도는 이렇게 계산해요'),
          _HowItWorks(result: r),
        ],
      ),
    );
  }
}

class _AreaDetail extends StatelessWidget {
  const _AreaDetail({required this.area, required this.highlight});

  final AreaResult area;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: highlight ? AppColors.greenLight : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(area.label, style: AppText.bodyBold),
              const SizedBox(width: 6),
              TagBadge(areaStatusLabel[area.status]!, tone: toneOf(area.status)),
              if (highlight) ...[
                const SizedBox(width: 6),
                const TagBadge('가장 먼저', tone: BadgeTone.dark),
              ],
              const Spacer(),
              Text('${area.score}점', style: AppText.bodyBold.copyWith(color: AppColors.greenDark)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '비중 ${(area.weight * 100).round()}% · 채우면 준비도 +${area.gain}점',
            style: AppText.caption,
          ),
          const SizedBox(height: 10),
          Text('부족한 점', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (area.gaps.isEmpty)
            Text('부족한 점이 없어요.', style: AppText.small)
          else
            for (final g in area.gaps) _Bullet(g),
          const SizedBox(height: 8),
          Text('반영된 근거', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (area.evidence.isEmpty)
            Text('아직 없어요.', style: AppText.small)
          else
            for (final e in area.evidence) _Bullet('${e.title} (${e.kind})'),
          const SizedBox(height: 8),
          Text(area.howScored, style: AppText.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _goFill(context, area.area),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.greenDark,
                side: const BorderSide(color: AppColors.greenLine),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(area.nextAction, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  void _goFill(BuildContext context, ReadinessArea a) {
    switch (a) {
      case ReadinessArea.portfolio:
        Navigator.pushNamed(context, Routes.recordList);
      case ReadinessArea.grades:
      case ReadinessArea.language:
        Navigator.pushNamed(context, Routes.profile);
      case ReadinessArea.jobSkill:
      case ReadinessArea.teamwork:
        // 홈으로 돌아가 아래 추천 활동에서 고르게 합니다.
        Navigator.pop(context);
    }
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('·  ', style: AppText.small),
            Expanded(child: Text(text, style: AppText.small.copyWith(fontSize: 12.5))),
          ],
        ),
      );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.result});
  final ReadinessResult result;

  @override
  Widget build(BuildContext context) {
    final t = result.target;
    final weights = result.shownAreas.map((a) => '${a.label} ${(a.weight * 100).round()}%').join(' · ');
    final lines = [
      if (result.source == ReadinessSource.ai)
        'AI가 활동 기록·성적·어학·진단 답을 보고 항목 점수와 준비도를 판단해요. 아래 비중과 기준을 AI에게 참고로 함께 줘요.',
      '준비도 = 항목 점수 × 비중을 모두 더한 값이에요. 80점 이상 "지원해 볼 만해요", 60~79점 "거의 다 왔어요", 60점 미만 "준비 중".',
      '지금 비중: $weights (관심 분야 ${t.field ?? '미정'} · 희망 기업 ${t.companyType ?? '고민 중'} 기준)',
      '항목 점수는 근거로 매겨요. 첨부·수료증이 있으면 1.0, 숫자로 된 결과가 있으면 0.6, 기록만 있으면 0.3. 100점은 신입 합격자 수준이라 처음엔 낮게 나와요.',
      '항목 배지: 80점 이상 충족, 40~79점 일부, 40점 미만 부족.',
      '"지금 채우면 좋은 것"은 채웠을 때 준비도가 가장 많이 오르는 항목이에요. 단, 생활 리듬이나 사람 만나기 단계라면 그 단계에 맞는 일부터 추천해요.',
      '목표 학점·어학: ${t.companyType ?? '고민 중'} 기준 학점 ${t.gpa45} / 4.5, 토익 ${t.toeic}점. (2025 상반기 공채 지원자 평균 학점 3.68, 토익 848점 · 자소설닷컴)',
      '직무 역량 비중을 가장 크게 둔 이유: 기업 74.6%가 신입 채용에서 "직무 관련 업무 경험"을 가장 중요하게 봐요. (경총 2024 신규채용 실태조사)',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final l in lines) _Bullet(l)],
    );
  }
}
