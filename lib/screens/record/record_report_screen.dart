// 경험 리포트 — 활동 기록(STAR)들을 섞어서 자기소개서 초안과 결과지형 리포트로 정리
//   1. 자기소개서 초안: 문항(직무 역량 · 협업 경험 · 문제 해결)과 길이(300 · 500 · 800자)를 고르고
//      '자기소개서 쓰기' 를 누르면 그때 한 번 글 한 편을 씀 (칩만 바꿔서는 글이 바뀌지 않음)
//   2. 결과지형 리포트: 요약 카드(활동 기록 '보기' → 기록별 역량 창) · 한 줄 강점 · 추천 직무 · 보완할 점
// 활동 기록 목록의 '경험 리포트·포트폴리오로 만들기' 에서 진입
// TODO(AI): 지금은 정해진 규칙으로 문장을 이어 붙이는 더미. LLM 연결 시 _ReportBuilder · _EssayBuilder 를 AI 결과로 교체
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RecordReportScreen extends StatefulWidget {
  const RecordReportScreen({super.key});

  @override
  State<RecordReportScreen> createState() => _RecordReportScreenState();
}

class _RecordReportScreenState extends State<RecordReportScreen> {
  // 칩은 '고르기'만 하고, 글은 '자기소개서 쓰기' 버튼을 눌렀을 때 한 번 써요
  _Question _question = _Question.job;
  int _limit = 500;
  _Essay? _essay; // 마지막으로 쓴 글 (아직 안 썼으면 null)
  _Question? _writtenQuestion;
  int? _writtenLimit;
  bool _writing = false;

  bool get _changed => _essay != null && (_question != _writtenQuestion || _limit != _writtenLimit);

  // TODO(AI): 버튼을 누를 때 문항과 글자 수를 AI에 한 번 보내 글을 받는다.
  //   지금은 잠깐 기다린 뒤 더미 규칙(_EssayBuilder)으로 씀. 칩을 바꿔도 다시 누르기 전까지 글은 그대로.
  Future<void> _write(_ReportBuilder report) async {
    final q = _question, n = _limit;
    setState(() => _writing = true);
    await Future<void>.delayed(const Duration(milliseconds: 600)); // TODO(AI): AI 응답 기다리는 자리
    if (!mounted) return;
    setState(() {
      _essay = _EssayBuilder(report, q).build(n);
      _writtenQuestion = q;
      _writtenLimit = n;
      _writing = false;
    });
  }

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
    final essay = _essay;

    return Scaffold(
      appBar: AppBar(title: const Text('경험 리포트')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TodoBox('AI 연결 전 더미예요. 내가 쓴 STAR 기록을 정해진 규칙으로 섞어 글을 만들었어요.'),
          const _SectionHeader(
            no: 1,
            title: '자기소개서 초안',
            desc: '여러 기록을 섞어 문항 하나에 맞는 글 한 편으로 썼어요',
          ),
          Text('문항', style: AppText.caption),
          const SizedBox(height: 6),
          ChipWrap(
            children: [
              for (final q in _Question.values)
                SelectChip(
                  label: q.label,
                  selected: q == _question,
                  onTap: () => setState(() => _question = q),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('글자 수', style: AppText.caption),
          const SizedBox(height: 6),
          ChipWrap(
            children: [
              for (final n in const [300, 500, 800])
                SelectChip(
                  label: '$n자',
                  selected: n == _limit,
                  onTap: () => setState(() => _limit = n),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AppButton(
            label: _writing
                ? '작성 중…'
                : essay == null
                    ? '자기소개서 쓰기'
                    : _changed
                        ? '이 조건으로 다시 쓰기'
                        : '다시 쓰기',
            icon: Icons.edit_note,
            variant: essay != null && !_changed ? ButtonVariant.outline : ButtonVariant.primary,
            onPressed: _writing ? null : () => _write(report),
          ),
          const SizedBox(height: 12),
          if (_writing)
            AppCard(
              child: Row(children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('내 기록을 섞어 자기소개서를 쓰고 있어요…', style: AppText.small)),
              ]),
            )
          else if (essay == null)
            AppCard(
              color: AppColors.soft,
              child: Text('문항과 글자 수를 고르고 쓰기를 눌러 주세요', style: AppText.small),
            )
          else ...[
            if (_changed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '조건을 바꿨어요. 아래 글은 ${_writtenQuestion!.label} · $_writtenLimit자로 쓴 글이에요.',
                  style: AppText.caption.copyWith(color: AppColors.amber),
                ),
              ),
            _EssayCard(
              essay: essay,
              limit: _writtenLimit!,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: essay.text));
                showToast(context, '자기소개서 초안을 복사했어요');
              },
            ),
          ],
          const _SectionHeader(
            no: 2,
            title: '결과지형 리포트',
            desc: '내 기록으로 본 강점과 어울리는 직무',
          ),
          _Overview(report: report),
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

/// 역량별 '배운 점' 문장 (STAR 에 배운 점 칸이 없어서 임시로 붙임)
const _learned = {
  '꾸준함': '작은 일이라도 꾸준히 이어 가면 눈에 보이는 결과가 된다는 것을 배웠습니다.',
  '소통·발표': '생각을 정리해 다른 사람 앞에서 전하는 자신감을 얻었습니다.',
  '데이터 활용': '반복되는 일을 데이터와 도구로 줄이는 방법을 배웠습니다.',
  '문제 해결': '작은 불편도 그냥 넘기지 않고 직접 방법을 찾는 태도를 배웠습니다.',
  '협업': '정해진 약속을 지키며 함께하는 것이 신뢰를 만든다는 것을 배웠습니다.',
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

  // ── 문장 다듬기: STAR 메모체(…음, …함, 명사로 끝남)를 자기소개서 문장(…습니다)으로

  static String _clean(String text) => text
      .split('→')
      .first // 결과 뒤의 '→ 자기소개서 활용' 메모는 뺌
      .trim()
      .replaceAll(RegExp(r'[.\s]+$'), '')
      .replaceAllMapped(RegExp(r'(이수|참여|가입|수강), '), (m) => '${m[1]}하고 ');

  static String sentence(String text) {
    final t = _clean(text);
    if (t.isEmpty) return '';
    if (t.endsWith('다')) return '$t.';
    const special = {'느낌': '느꼈습니다', '만들기': '만들고자 했습니다'};
    for (final MapEntry(key: end, value: to) in special.entries) {
      if (t.endsWith(end)) {
        return '${t.substring(0, t.length - end.length)}$to.';
      }
    }
    if (t.endsWith('었음') || t.endsWith('았음')) {
      return '${t.substring(0, t.length - 1)}습니다.';
    }
    if (t.endsWith('함')) return '${t.substring(0, t.length - 1)}했습니다.';
    if (t.endsWith('음')) return '${t.substring(0, t.length - 1)}었습니다.';
    return '$t했습니다.';
  }

  /// 목표 문장: '…을 목표로 설정' / '…만들기' 를 자연스럽게
  static String goal(String text) {
    final t = _clean(
      text,
    ).replaceFirst(RegExp(r'\s*[을를]?\s*목표로\s*(설정|삼음|정함)?$'), '');
    if (t.isEmpty) return '';
    if (t.endsWith(' 만들기')) {
      final obj = t.substring(0, t.length - 4);
      return '$obj${josa(obj, '을', '를')} 만들고 싶었습니다.';
    }
    return '$t${josa(t, '을', '를')} 목표로 삼았습니다.';
  }

  /// 받침이 있으면 a, 없으면 b (예: 을/를, 과/와, 은/는)
  static String josa(String word, String a, String b) {
    if (word.isEmpty) return b;
    final code = word.codeUnitAt(word.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return b;
    return (code - 0xAC00) % 28 == 0 ? b : a;
  }

  /// '청년센터 엑셀 워크숍 듣기' → '청년센터 엑셀 워크숍'
  static String place(ActivityRecord r) =>
      r.title.replaceFirst(RegExp(r'\s*(듣기|참여|참가|수강|하기|해보기)$'), '').trim();
}

// ───────────────────────── 자기소개서 한 편 만들기 (더미 규칙)

enum _Question {
  job('직무 역량'),
  team('협업 경험'),
  problem('문제 해결');

  const _Question(this.label);
  final String label;
}

/// 글 한 편 안의 문장. order = 글 속 위치, priority = 작을수록 먼저 넣음 (길이가 짧으면 뒤 번호부터 빠짐)
class _Line {
  _Line(this.order, this.priority, this.text, {this.block = 0, this.kind = ''});
  final int order;
  final int priority;
  final String text;
  final int block; // 같은 기록에서 나온 문장끼리 같은 번호
  final String kind; // s · goal · a · r · learn
}

typedef _Essay = ({String title, String body, String text, bool short});

class _EssayBuilder {
  _EssayBuilder(this.report, this.question);
  final _ReportBuilder report;
  final _Question question;

  /// 문항마다 강조할 역량
  List<String> get _focus => switch (question) {
    _Question.job => [
      report.jobs.isEmpty ? report.top : report.jobs.first.skill,
      '데이터 활용',
      '문제 해결',
    ],
    _Question.team => ['협업', '소통·발표'],
    _Question.problem => ['문제 해결', '데이터 활용'],
  };

  /// 강조 역량을 많이 담은 기록이 앞으로 (같으면 최근 기록 먼저)
  List<ActivityRecord> get _ranked {
    int s(ActivityRecord r) {
      var total = 0;
      for (final (i, f) in _focus.indexed) {
        total += _ReportBuilder.score(r, f) * (10 - i * 3);
      }
      return total;
    }

    return [...report.records]..sort((a, b) {
      final c = s(b).compareTo(s(a));
      return c != 0 ? c : b.date.compareTo(a.date);
    });
  }

  String _learnOf(ActivityRecord r) {
    for (final f in _focus) {
      if (_ReportBuilder.score(r, f) > 0) return _learned[f]!;
    }
    var best = report.top;
    var bestScore = 0;
    for (final k in _skillKeywords.keys) {
      final sc = _ReportBuilder.score(r, k);
      if (sc > bestScore) (best, bestScore) = (k, sc);
    }
    return _learned[best]!;
  }

  String get _title {
    final main = _ranked.first;
    final place = _ReportBuilder.place(main);
    final at = '$place에서';
    return switch (question) {
      _Question.job => '[$at ${_focus.first} 역량을 키운 경험]',
      _Question.team => '[$at 함께하는 법을 배운 경험]',
      _Question.problem => '[$at 익힌 방법으로 불편을 직접 해결한 경험]',
    };
  }

  List<_Line> _lines() {
    final ranked = _ranked;
    final main = ranked.first;
    final others = ranked.skip(1).toList();
    final job = report.jobs.isEmpty ? '희망' : report.jobs.first.name;
    final focus = _focus.first;

    // 첫 기록(주인공): 상황 → 목표 → 행동 → 결과 → 배운 점
    List<_Line> mainBlock(int base, {required int sP, required int learnP}) => [
      _Line(
        base,
        sP,
        _ReportBuilder.sentence(main.star.s),
        block: 1,
        kind: 's',
      ),
      _Line(
        base + 1,
        3,
        _ReportBuilder.goal(main.star.t),
        block: 1,
        kind: 'goal',
      ),
      _Line(
        base + 2,
        0,
        _ReportBuilder.sentence(main.star.a),
        block: 1,
        kind: 'a',
      ),
      _Line(
        base + 3,
        0,
        _ReportBuilder.sentence(main.star.r),
        block: 1,
        kind: 'r',
      ),
      _Line(base + 4, learnP, _learnOf(main), block: 1, kind: 'learn'),
    ];

    // 나머지 기록: '또한' 으로 이어서 행동 → 결과 → 배운 점 (상황은 길이가 넉넉할 때만)
    List<_Line> otherBlocks(int base) => [
      for (final (i, r) in others.indexed) ...[
        _Line(
          base + i * 10,
          7 + i * 4,
          _ReportBuilder.sentence(r.star.s),
          block: 2 + i,
          kind: 's',
        ),
        _Line(
          base + i * 10 + 1,
          2 + i * 4,
          _ReportBuilder.sentence(r.star.a),
          block: 2 + i,
          kind: 'a',
        ),
        _Line(
          base + i * 10 + 2,
          4 + i * 4,
          _ReportBuilder.sentence(r.star.r),
          block: 2 + i,
          kind: 'r',
        ),
        _Line(
          base + i * 10 + 3,
          6 + i * 4,
          _learnOf(r),
          block: 2 + i,
          kind: 'learn',
        ),
      ],
    ];

    return switch (question) {
      // 직무 역량: 주장 → 주인공 기록 → 또한 … → 직무 연결
      _Question.job => [
        _Line(0, 0, '$job 직무에 필요한 $focus 역량을 공백기 동안 직접 쌓아 왔습니다.'),
        ...mainBlock(10, sP: 1, learnP: 2),
        ...otherBlocks(100),
        _Line(900, 8, '처음에는 작은 시도였지만 하나씩 해내며 자신감을 되찾았습니다.'),
        _Line(1000, 1, '입사 후에도 이 역량을 살려 맡은 업무를 더 빠르고 정확하게 처리하겠습니다.'),
      ],
      // 협업 경험: 사람 → 주인공 기록 → 또한 … → 팀 기여
      _Question.team => [
        _Line(0, 1, '저는 사람들과 약속을 지키며 함께할 때 더 힘을 내는 사람입니다.'),
        ...mainBlock(10, sP: 0, learnP: 1),
        ...otherBlocks(100),
        _Line(900, 8, '혼자였다면 금방 멈췄을 일도 함께였기에 끝까지 해낼 수 있었습니다.'),
        _Line(1000, 1, '입사 후에도 동료와 먼저 소통하며 팀의 목표를 함께 이루겠습니다.'),
      ],
      // 문제 해결: 문제 상황부터 → 해결 → 배운 점 → 또한 … → 다짐
      _Question.problem => [
        ...mainBlock(0, sP: 0, learnP: 1),
        ...otherBlocks(100),
        _Line(900, 8, '문제를 발견하면 원인을 나누어 보고 할 수 있는 것부터 바로 시도합니다.'),
        _Line(1000, 1, '앞으로도 불편한 점을 먼저 발견하고 직접 개선하는 사람이 되겠습니다.'),
      ],
    };
  }

  /// 앞 문장에 맞춰 연결어 붙이기
  static String _lead(_Line l, _Line? prev, bool firstOfBlock) {
    if (l.block >= 2 && firstOfBlock) return l.kind == 's' ? '한편 ' : '또한 ';
    if (prev == null || prev.block != l.block || l.block == 0) return '';
    return switch (l.kind) {
      'goal' => '그래서 ',
      'a' => prev.kind == 'goal' ? '이를 위해 ' : '그래서 ',
      'r' => '그 결과 ',
      'learn' => '이 경험으로 ',
      _ => '',
    };
  }

  _Essay build(int limit) {
    final title = _title;
    final all = _lines().where((l) => l.text.isNotEmpty).toList();
    final byPriority = [...all]
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // 우선순위 순으로 넣어 보고, 글자 수(공백 포함)가 넘치면 그 문장은 뺌
    final chosen = <_Line>[];
    String compose(List<_Line> lines) {
      final sorted = [...lines]..sort((a, b) => a.order.compareTo(b.order));
      final out = <String>[];
      final seenBlocks = <int>{};
      _Line? prev;
      for (final l in sorted) {
        final first = seenBlocks.add(l.block);
        out.add('${_lead(l, prev, first)}${l.text}');
        prev = l;
      }
      return out.join(' ');
    }

    for (final l in byPriority) {
      final body = compose([...chosen, l]);
      if ('$title\n$body'.length <= limit) chosen.add(l);
    }
    final body = compose(chosen);
    final text = '$title\n$body';
    return (
      title: title,
      body: body,
      text: text,
      short: text.length < limit * 0.7,
    );
  }
}

// ───────────────────────── 화면 조각

class _EssayCard extends StatelessWidget {
  const _EssayCard({
    required this.essay,
    required this.limit,
    required this.onCopy,
  });
  final _Essay essay;
  final int limit;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            essay.title,
            style: AppText.bodyBold.copyWith(
              fontSize: 13.5,
              color: AppColors.greenDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              essay.body,
              style: AppText.body.copyWith(fontSize: 13, height: 1.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  essay.short
                      ? '기록을 더 쌓으면 더 길게 쓸 수 있어요'
                      : '공백 포함 · 내 상황에 맞게 고쳐 쓰세요',
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
              ),
              Text(
                '${essay.text.length}/$limit자',
                style: AppText.caption.copyWith(
                  color: AppColors.greenDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(
            label: '전체 복사',
            icon: Icons.copy,
            variant: ButtonVariant.outline,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

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
              Expanded(child: _Stat(value: report.days, label: '활동 기간(일)')),
              Expanded(child: _Stat(value: attachments, label: '첨부 자료')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 숫자 + 라벨 한 칸. tappable 이면 '보기 ›' 표시
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.tappable = false});
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                          child: Text(r.title, style: AppText.bodyBold.copyWith(fontSize: 13.5)),
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
                          const TagBadge('아직 연결된 역량 없음', tone: BadgeTone.gray),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.no,
    required this.title,
    required this.desc,
  });
  final int no;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$no',
              style: AppText.bodyBold.copyWith(
                fontSize: 12,
                color: AppColors.paper,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title),
                Text(desc, style: AppText.caption),
              ],
            ),
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
