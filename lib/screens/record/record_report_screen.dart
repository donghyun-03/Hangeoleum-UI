// 경험 리포트 — 활동 기록(STAR)으로 본 나의 강점 정리
//   첫 화면: 요약 카드(활동 기록 '보기' → 기록별 역량 창) → AI로 자기소개서 쓰기 → 한 줄 강점 · 추천 직무 · 보완할 점
//   자기소개서는 EssayScreen 에서 AI 가 써요 (목표 → 활동 고르기 → 문항·글자 수)
// 활동 기록 목록의 '경험 리포트·자기소개서' 에서 진입
// TODO(AI): 강점·추천 직무·보완할 점은 아직 정해진 규칙(_ReportBuilder). 나중에 AI 결과로 교체
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'essay_screen.dart';

class RecordReportScreen extends StatefulWidget {
  const RecordReportScreen({super.key});

  @override
  State<RecordReportScreen> createState() => _RecordReportScreenState();
}

class _RecordReportScreenState extends State<RecordReportScreen> {
  /// 홈 화면으로 돌아가서 STEP 탭의 해당 단계 열기
  void _goStep(int step) {
    Navigator.popUntil(context, (r) => r.isFirst);
    context.read<MainTabs>().go(MainTab.step, step: step);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.records.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('경험 리포트')),
        body: const EmptyState(
          icon: Icons.description_outlined,
          title: '아직 리포트를 만들 기록이 없어요',
          desc: '활동을 기록하면 자기소개서에 쓸 수 있게 정리해 드려요.',
        ),
      );
    }
    final report = _ReportBuilder(state.user, state.records);

    return Scaffold(
      appBar: AppBar(title: const Text('경험 리포트')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Overview(report: report),
          // AI 자기소개서 (목표 → 활동 고르기 → 문항)
          AppCard(
            margin: const EdgeInsets.only(top: 12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EssayScreen()),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.edit_note, color: AppColors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI로 자기소개서 쓰기', style: AppText.bodyBold),
                      Text(
                        '가고 싶은 곳과 넣고 싶은 활동을 고르면 AI가 글을 써요',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.subtle),
              ],
            ),
          ),
          _StrengthCard(text: report.strength),
          const _SubTitle('추천 직무'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, j) in report.jobs.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.work_outline,
                          size: 16,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                j.name,
                                style: AppText.bodyBold.copyWith(
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                '관심 분야 ${j.interest} · ${j.skill} 역량과 잘 맞아요',
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const _SubTitle('보완할 점'),
          if (report.gaps.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                '모든 역량에 근거 기록이 있어요. 지금처럼 꾸준히 기록해 보세요.',
                style: AppText.small,
              ),
            ),
          for (final g in report.gaps)
            _GapRow(
              gap: g,
              onTap: g.step == null ? null : () => _goStep(g.step!),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── 리포트 내용 만들기 (더미 규칙)

typedef _Skill = ({String name, List<ActivityRecord> records});
typedef _Job = ({String name, String interest, String skill});
typedef _Gap = ({String skill, String todo, int? step});

/// 기록 내용에 이 단어가 있으면 → 해당 역량 (AI 연결 전 임시 규칙)
const _skillKeywords = {
  '꾸준함': ['매주', '매일', '4주', '3회', '이수', '출석', '꾸준'],
  '소통·발표': ['발표', '질문', '소통', '설명'],
  '데이터 활용': ['엑셀', '피벗', '함수', '데이터', '시트'],
  '문제 해결': ['자동화', '해결', '개선', '부족'],
  '협업': ['동아리', '팀', '함께', '참가자', '모임'],
};

/// 역량이 비었을 때 해 볼 활동 (STEP 으로 연결)
const _gapTodo = {
  '꾸준함': (todo: 'STEP 1 미션을 매일 하나씩 이어 가기', step: 1),
  '소통·발표': (todo: '모임에서 5분 발표 맡아 보기', step: 2),
  '데이터 활용': (todo: '엑셀 · 데이터 기초 프로그램 들어 보기', step: 3),
  '문제 해결': (todo: '불편한 일 하나를 골라 직접 개선해 보기', step: 1),
  '협업': (todo: '미니 프로젝트 팀에 참여해 보기', step: 2),
};

/// 관심 분야 → 추천 직무 · 대표 역량 (더미 매핑)
const _interestJobs = {
  'IT·데이터': (jobs: ['데이터 분석 보조', '사무 자동화 담당'], skill: '데이터 활용'),
  '사무·행정': (jobs: ['사무 행정원', '데이터 입력원'], skill: '꾸준함'),
  '마케팅·기획': (jobs: ['마케팅 어시스턴트', '콘텐츠 기획 보조'], skill: '소통·발표'),
  '디자인·영상': (jobs: ['콘텐츠 디자인 보조', '영상 편집 보조'], skill: '문제 해결'),
  '서비스·판매': (jobs: ['고객 상담원', '매장 관리원'], skill: '소통·발표'),
};
const _defaultJobs = (jobs: ['사무 보조', '고객 상담원'], skill: '꾸준함');

class _ReportBuilder {
  _ReportBuilder(this.user, List<ActivityRecord> all)
    : records = [...all]..sort((a, b) => a.date.compareTo(b.date)); // 오래된 → 최근

  final AppUser user;
  final List<ActivityRecord> records;

  static String textOf(ActivityRecord r) =>
      [r.title, r.raw, r.star.s, r.star.t, r.star.a, r.star.r].join(' ');

  /// 이 기록이 이 역량 단어를 몇 개 담고 있는지
  static int score(ActivityRecord r, String skill) =>
      (_skillKeywords[skill] ?? const []).where(textOf(r).contains).length;

  /// 역량별 근거 기록 (근거가 많은 순, 근거 없는 역량은 빠짐)
  late final List<_Skill> skills =
      [
          for (final name in _skillKeywords.keys)
            (
              name: name,
              records: records.where((r) => score(r, name) > 0).toList(),
            ),
        ].where((s) => s.records.isNotEmpty).toList()
        ..sort((a, b) => b.records.length.compareTo(a.records.length));

  /// 이 기록이 근거가 되는 역량 (단어가 많이 맞는 순)
  List<String> skillsOf(ActivityRecord r) {
    final names = _skillKeywords.keys.where((k) => score(r, k) > 0).toList();
    return names..sort((a, b) => score(r, b).compareTo(score(r, a)));
  }

  String get top => skills.isEmpty ? '꾸준함' : skills.first.name;
  String get _second => skills.length < 2 ? '배우는 자세' : skills[1].name;

  String get headline =>
      '$top${josa(top, '과', '와')} $_second${josa(_second, '을', '를')} 갖춘 ${user.name}입니다';

  String get period => '${records.first.date} ~ ${records.last.date}';

  int get days {
    final a = DateTime.tryParse(records.first.date),
        b = DateTime.tryParse(records.last.date);
    return a == null || b == null ? 0 : b.difference(a).inDays + 1;
  }

  /// 한 줄 강점
  String get strength {
    final n = skills.isEmpty ? 0 : skills.first.records.length;
    return '기록 ${records.length}개 중 $n개에서 $top${josa(top, '이', '가')} 드러나요. '
        '배운 것을 바로 실행으로 옮기는 힘이 강점이에요.';
  }

  /// 관심 분야에 맞는 추천 직무 2~3개
  late final List<_Job> jobs = () {
    final picked = <_Job>[];
    final interests = user.interests.where(_interestJobs.containsKey).toList();
    for (final i in interests) {
      final m = _interestJobs[i]!;
      for (final j in m.jobs) {
        if (picked.length < 3 && !picked.any((p) => p.name == j)) {
          picked.add((name: j, interest: i, skill: m.skill));
        }
      }
    }
    if (picked.isEmpty) {
      for (final j in _defaultJobs.jobs) {
        picked.add((name: j, interest: '전체', skill: _defaultJobs.skill));
      }
    }
    return picked;
  }();

  /// 기록이 없는 역량 → 다음에 해 볼 활동
  late final List<_Gap> gaps = [
    for (final name in _skillKeywords.keys)
      if (!skills.any((s) => s.name == name))
        (skill: name, todo: _gapTodo[name]!.todo, step: _gapTodo[name]!.step),
  ];

  /// 받침이 있으면 a, 없으면 b (예: 을/를, 과/와, 은/는)
  static String josa(String word, String a, String b) {
    if (word.isEmpty) return b;
    final code = word.codeUnitAt(word.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return b;
    return (code - 0xAC00) % 28 == 0 ? b : a;
  }
}

// ───────────────────────── 화면 조각

class _Overview extends StatelessWidget {
  const _Overview({required this.report});
  final _ReportBuilder report;

  @override
  Widget build(BuildContext context) {
    final attachments = report.records.fold(
      0,
      (sum, r) => sum + r.attachments.length,
    );
    return AppCard(
      color: AppColors.greenLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.user.name}님의 경험 리포트',
            style: AppText.caption.copyWith(color: AppColors.greenDark),
          ),
          const SizedBox(height: 4),
          Text(
            '“${report.headline}”',
            style: AppText.h2.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(report.period, style: AppText.small),
          const SizedBox(height: 14),
          // 공통 StatRow 와 같은 모양. '활동 기록' 칸만 눌러서 기록별 역량 창을 열 수 있게 따로 만듦
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showRecordSkills(context, report),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: _Stat(
                    value: report.records.length,
                    label: '활동 기록',
                    tappable: true,
                  ),
                ),
              ),
              Expanded(
                child: _Stat(value: report.days, label: '활동 기간(일)'),
              ),
              Expanded(
                child: _Stat(value: attachments, label: '첨부 자료'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 숫자 + 라벨 한 칸. tappable 이면 '보기 ›' 표시
class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.tappable = false,
  });
  final int value;
  final String label;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$value', style: AppText.h2.copyWith(color: AppColors.green)),
            if (tappable) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '보기 ›',
                  style: AppText.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.greenDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        Text(label, style: AppText.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// 활동 기록마다 어떤 역량의 근거인지 보여 주는 아래 창
void _showRecordSkills(BuildContext context, _ReportBuilder report) {
  final records = report.records.reversed.toList(); // 최근 기록 먼저
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    // 창 높이는 화면의 70%까지. 제목은 위에 고정하고, 기록이 많으면 아래 목록만 스크롤
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('활동 기록별 역량 · ${records.length}개', style: AppText.title),
                  const SizedBox(height: 2),
                  Text('기록마다 어떤 역량의 근거가 되는지 보여 줘요', style: AppText.caption),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                key: const ValueKey('record-skills-list'),
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final r in records)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.soft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  r.title,
                                  style: AppText.bodyBold.copyWith(
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(r.date, style: AppText.caption),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final k in report.skillsOf(r)) TagBadge(k),
                              if (report.skillsOf(r).isEmpty)
                                const TagBadge(
                                  '아직 연결된 역량 없음',
                                  tone: BadgeTone.gray,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_outline, size: 18, color: AppColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.body.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: AppText.bodyBold.copyWith(fontSize: 13.5)),
  );
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap, this.onTap});
  final _Gap gap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${gap.skill} 기록이 없어요 · ',
                    style: AppText.small.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: '다음에 ${gap.todo}', style: AppText.small),
                ],
              ),
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: AppColors.subtle),
        ],
      ),
    );
  }
}
