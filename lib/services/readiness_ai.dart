// 준비도 AI 판단 — 준비도, 5개 항목(포트폴리오·성적·어학·직무 역량·자격증)과 항목 비중, 지금 채우면 좋은 것을 AI(BAZE)가 정합니다.
// 키는 실행할 때만 넣어요: flutter run --dart-define=LLM_KEY=BAZE키 --dart-define=LLM_MODEL=모델이름
// 키가 없거나 AI가 실패하면 규칙 계산(readiness_service.dart) 결과를 그대로 씁니다.
//
// 비용: 한 번 판단에 BAZE 1회 호출. 홈 추천 활동도 같은 호출에서 함께 고릅니다(예전엔 2번 → 1번, 2026-11-18 주아: 느려서).
// 진단 답·학점·어학·자격증·기록·팀이 바뀌었을 때만 다시 물어봅니다. (AppState.refreshReadiness)

import 'dart:convert';

import '../models/diagnosis_profile.dart';
import '../models/models.dart';
import 'llm_client.dart';
import 'readiness_service.dart';
import 'recommend_ai.dart';

/// AI 에게 넘기는 재료
class ReadinessInput {
  const ReadinessInput({
    required this.user,
    required this.diagnosis,
    required this.records,
    required this.acceptedTeams,
    required this.doneTeamIds,
    this.likes = const [],
    this.needsDirection = false,
    this.candidates = const [],
  });

  /// 홈 추천 활동 후보(STEP 1~4). 있으면 같은 호출에서 AI 가 최대 3개를 같이 고릅니다.
  /// signature 에는 넣지 않습니다. (후보 목록은 준비도 결과로 만들어져서 넣으면 서로 물고 돕니다)
  final List<HomeRecommendation> candidates;

  ReadinessInput withCandidates(List<HomeRecommendation> c) => ReadinessInput(
        user: user,
        diagnosis: diagnosis,
        records: records,
        acceptedTeams: acceptedTeams,
        doneTeamIds: doneTeamIds,
        likes: likes,
        needsDirection: needsDirection,
        candidates: c,
      );

  /// 분야·기업·직무를 정말 모르는 사람인지 (AppState.needsDirection). true 일 때만 방향 추천을 받습니다.
  final bool needsDirection;

  final AppUser user;

  /// 관심 찾기 카드에서 적은 "끌리는 것" (분야·기업을 모를 때 AI 추천 재료)
  final List<String> likes;
  final DiagnosisProfile diagnosis;
  final List<ActivityRecord> records;
  final List<TeamPost> acceptedTeams;
  final Set<String> doneTeamIds;

  /// 재료가 바뀌었는지 비교하는 값. 같으면 AI를 다시 부르지 않습니다.
  String get signature => jsonEncode({
        'd': diagnosis.answers,
        'e': user.education,
        'm': user.major,
        'g': [user.gpa, user.gpaScale, user.schoolGrade],
        'l': [for (final l in user.languages) '${l.exam}:${l.score}'],
        'c': [for (final c in user.certificates) c.name],
        'r': [for (final r in records) '${r.id}:${r.title}:${r.star.r}:${r.attachments.length}'],
        't': [for (final p in acceptedTeams) '${p.id}:${doneTeamIds.contains(p.id)}'],
        'k': likes,
      });

  ReadinessResult ruleResult() => ReadinessService.evaluate(
        user: user,
        diagnosis: diagnosis,
        records: records,
        acceptedTeams: acceptedTeams,
        doneTeamIds: doneTeamIds,
      );
}

abstract class ReadinessJudge {
  /// 실패하면 예외를 던집니다. (부르는 쪽에서 규칙 결과를 계속 씁니다)
  Future<ReadinessResult> judge(ReadinessInput input);
}

class BazeReadinessJudge implements ReadinessJudge {
  BazeReadinessJudge({LlmClient? client}) : _client = client ?? LlmClient();
  final LlmClient _client;

  static const system = '''너는 쉬었음 청년의 취업 준비도를 판단하는 커리어 코치야.
사용자 정보와 활동 기록을 보고, 목표(희망 기업 유형·기업·직무, 없으면 관심 분야)에 비춰 항목별로 얼마나 준비됐는지 판단해.

항목 5개 (key): portfolio(포트폴리오: 결과물로 보여 줄 수 있는 활동), grades(성적: 학점), language(어학), job_skill(직무 역량: 희망 직무와 관련된 경험·교육, 공기업이면 NCS 같은 필기 준비 포함), certificate(자격증)
- weight: 이 목표(기업·직무)가 실제 채용에서 그 항목을 얼마나 보는지 0~100. 5개를 더하면 100.
  · 목표 회사·직무를 보고 정해. 자격증을 거의 안 보는 곳(스타트업, 디자인·영상 등)은 certificate 를 0~5, 자격증이 필수이거나 가산점이 큰 곳(공기업 사무 등)은 높게.
  · 공기업은 블라인드 채용이라 portfolio 를 낮게. 학력 무관 채용이면 grades 를 낮게.
  · 참고 비중을 출발점으로 쓰고, 크게 다르게 줄 때는 이유가 분명해야 해.
- score: 0~100. 100 = 목표 기업 신입 합격자 수준. 80 이상 충족, 40~79 일부, 40 미만 부족.
- 아주 엄격하게 매겨. 후하게 주지 마. 처음 시작하는 사람은 대부분 0~20점이야.
  · 근거가 없으면 0점. 말로만 한 기록 하나는 최대 10점, 숫자 결과가 있는 기록은 최대 20점, 첨부·수료증·완료가 있는 결과물이 여러 개 쌓여야 60점을 넘을 수 있어.
  · 생활 습관·동네 모임·단순 교육 수강처럼 직무와 거리가 먼 기록은 job_skill·portfolio 에 거의 반영하지 마.
  · 희망 직무가 없으면 job_skill 은 최대 30점. 분야도 없으면 최대 10점.
  · 학점·어학은 목표 대비로만 판단하고, 입력이 없으면 0점.
  · 어학은 서류 커트라인을 넘으면 기본 충족(70점 이상)이야. 커트라인을 넘었는데 낮게 주지 마. 아래 "규칙 참고 점수"에서 10점 넘게 벗어나지 마. 성적도 마찬가지.
  · 자격증은 목표 회사·직무가 실제로 보는 자격증인지로 판단해. 상관없는 자격증은 조금만.
- 없는 경험을 지어내지 마.
- 대학을 다니지 않았으면 grades 는 applicable=false.
- gaps: 부족한 점 최대 3개, 쉬운 말 한 문장씩. evidence: 반영한 기록·성적 제목.
- next_action: 이 항목을 채우려면 지금 할 일 한 줄 (25자 이내).

종합 준비도 score: 항목 점수에 "참고 비중"을 곱해 더한 값. 그보다 높게 주지 마.
fill: 지금 채우면 좋은 것 하나. 채웠을 때 준비도가 가장 많이 오르고 지금 해볼 만한 항목.
- 사용자 단계가 "생활 리듬" 이면 큰 활동(프로젝트·공모전) 대신 생활 리듬 활동을, "사람 만나기" 면 교류 활동을 title 로 줘.
- title 은 "항목: 할 일" 형식 30자 이내, reason 은 왜 이걸 먼저 하면 좋은지 한 문장.
summary: 사용자에게 건네는 격려 섞인 총평 한 문장. 점수가 낮아도 기죽지 않게.

direction: [방향 추천 필요] 가 "예"일 때만 채워. "아니오"면 null.
- 사용자가 적은 "끌리는 것", 전공, 학력, 하루 상태를 보고 완전 처음부터 방향을 잡아 줘.
- fields: 어울리는 분야 1~2개 (IT·데이터 / 디자인·영상 / 사무·행정 중에서).
- jobs: 처음 해 보기 좋은 구체적인 직무 3개. why 는 그 사람 정보와 연결해 한 문장.
- company_types: 시작하기 좋은 기업 유형 1~2개 (스타트업 / 중소기업 / 중견기업 / 대기업 / 공기업·공공기관 중에서), why 한 문장.
- message: 부담 없이 "한 달만 해 봐요" 하고 격려하는 두 문장. 의욕이 낮아 보이면(생활 리듬 단계·하루 10분) 더 작게 시작하자고 해.

picks: [추천 후보] 가 있으면 그중에서 지금 이 사람에게 맞는 활동을 골라. 없으면 [].
${BazeRecommendJudge.rules}
말투는 "~해요" 체.''';

  static const _shape = '''{"score":0,"summary":"",
"areas":[{"key":"portfolio","score":0,"weight":25,"applicable":true,"gaps":[""],"evidence":[""],"next_action":""}],
"fill":{"key":"portfolio","title":"","reason":""},
"direction":{"message":"","fields":[""],"jobs":[{"name":"","why":""}],"company_types":[{"name":"","why":""}]},
"picks":[{"id":"","reason":""}]}''';

  static String userPrompt(ReadinessInput i, ReadinessResult rule) {
    final u = i.user;
    final t = rule.target;
    final records = [
      for (final r in i.records)
        '- ${r.date} ${r.title} | 행동: ${r.star.a} | 결과: ${r.star.r}'
            '${r.attachments.isEmpty ? '' : ' | 첨부 ${r.attachments.length}개'}',
    ];
    final teams = [
      for (final p in i.acceptedTeams) '- ${p.title} (${i.doneTeamIds.contains(p.id) ? '완료' : '진행 중'})',
    ];
    final weights = [for (final a in rule.areas) '${readinessAreaKey[a.area]} ${(a.weight * 100).round()}'].join(', ');
    final lang = ReadinessService.bestLanguage(u.languages);
    return '''${i.diagnosis.toPromptContext()}

[사용자 정보]
- 학력: ${u.education} / 전공: ${u.major}
- 학점: ${u.gpa == null ? '미입력' : '${u.gpa} / ${u.gpaScale}'}${ReadinessService.isHighSchool(u.education) ? '\n- 고교 내신 평균: ${u.schoolGrade == null ? '미입력' : '${u.schoolGrade}등급 (1~9등급, 낮을수록 좋음)'}' : ''}
- 어학: ${u.languages.isEmpty ? '없음' : u.languages.map((l) => '${l.exam} ${l.score}').join(', ')}${lang == null ? '' : ' (가장 좋은 성적 토익 환산 약 ${lang.$2}점)'}
- 자격증: ${u.certificates.isEmpty ? '없음' : u.certificates.map((c) => c.name).join(', ')}
- 지금 단계: ${userStageLabel[rule.stage]}
- 끌리는 것(직접 적음): ${i.likes.isEmpty ? '없음' : i.likes.join(', ')}

[목표 기준]
- 기준: ${t.label}
- 목표 학점 ${t.gpa45} / 4.5
- 어학: 서류 커트라인 토익 ${t.toeicCutoff}점 정도, 목표 ${t.toeic}점 (목표 회사를 알면 그 회사 기준으로 판단해)
- 방향 추천 필요: ${i.needsDirection ? '예' : '아니오'}
- 참고 비중(합 100): $weights

[활동 기록 ${records.length}개]
${records.isEmpty ? '- 없음' : records.join('\n')}

[한걸음 팀 프로젝트]
${teams.isEmpty ? '- 없음' : teams.join('\n')}

[규칙으로 계산한 참고 점수] 준비도 ${rule.score}, ${[for (final a in rule.areas) '${readinessAreaKey[a.area]} ${a.score}'].join(', ')}

[추천 후보 ${i.candidates.length}개]
${i.candidates.isEmpty ? '- 없음' : BazeRecommendJudge.candidateLines(i.candidates).join('\n')}

아래 모양의 JSON 으로 답해. areas 는 5개 key 를 모두 넣어.
$_shape''';
  }

  @override
  Future<ReadinessResult> judge(ReadinessInput input) async {
    final rule = input.ruleResult();
    final json = await _client.askJson(system: system, user: userPrompt(input, rule), temperature: 0.2);
    return parse(json, rule);
  }

  /// AI 답을 결과로 바꿉니다. 빠진 항목은 규칙 값으로 채웁니다.
  static ReadinessResult parse(Map<String, dynamic> json, ReadinessResult rule) {
    final byKey = <ReadinessArea, Map<String, dynamic>>{};
    for (final a in (json['areas'] as List? ?? const [])) {
      if (a is! Map) continue;
      final area = areaFromKey('${a['key']}');
      if (area != null) byKey[area] = Map<String, dynamic>.from(a);
    }
    if (byKey.isEmpty) throw const LlmException('AI 답에 항목이 없어요');

    // 비중: AI 가 준 값을 합 1 로 맞춥니다. 안 줬거나 이상하면 규칙 비중. 해당 없는 항목(대학 안 다님 성적)은 0.
    final aiWeights = [
      for (final r in rule.areas)
        !r.applicable ? 0.0 : (((byKey[r.area]?['weight'] as num?)?.toDouble() ?? -1).clamp(-1.0, 100.0)),
    ];
    final weights = aiWeights.any((w) => w < 0) || aiWeights.every((w) => w == 0)
        ? [for (final r in rule.areas) r.weight]
        : ReadinessService.normalizeWeights(aiWeights);

    // 성적·어학은 숫자로 정해지는 항목이라 규칙 점수 ±10 안에서만 AI 판단을 받습니다.
    int scoreOf(AreaResult r, Map<String, dynamic> a) {
      final s = ((a['score'] as num?) ?? r.score).round().clamp(0, 100);
      if (r.area == ReadinessArea.grades || r.area == ReadinessArea.language) {
        return s.clamp((r.score - 10).clamp(0, 100), (r.score + 10).clamp(0, 100));
      }
      return s;
    }

    var idx = 0;
    final areas = [
      for (final r in rule.areas)
        if (byKey[r.area] case final a? when r.applicable)
          r.copyWith(
            weight: weights[idx++],
            score: scoreOf(r, a),
            gaps: [for (final g in (a['gaps'] as List? ?? const [])) if ('$g'.trim().isNotEmpty) '$g'],
            evidence: [
              for (final e in (a['evidence'] as List? ?? const []))
                if ('$e'.trim().isNotEmpty) Evidence('$e', 1.0, 'AI 반영'),
            ],
            nextAction: '${a['next_action'] ?? ''}'.trim().isEmpty ? r.nextAction : '${a['next_action']}',
          )
        else
          r.copyWith(weight: weights[idx++]),
    ];

    final fill = json['fill'] is Map ? Map<String, dynamic>.from(json['fill'] as Map) : const <String, dynamic>{};
    String? text(Object? v) => (v == null || '$v'.trim().isEmpty) ? null : '$v'.trim();

    // 종합 점수는 AI 가 매긴 항목 점수 × 비중 합보다 5점 넘게 높을 수 없게 막습니다. (후하게 주지 않기)
    final weighted = areas.fold<double>(0, (sum, a) => sum + a.score * a.weight).round();
    final aiScore = ((json['score'] as num?) ?? weighted).round();
    return ReadinessResult(
      score: (aiScore > weighted + 5 ? weighted + 5 : aiScore).clamp(0, 100),
      areas: areas,
      target: rule.target,
      stage: rule.stage,
      source: ReadinessSource.ai,
      fillArea: areaFromKey(fill['key'] as String?),
      fillTitle: text(fill['title']),
      fillReason: text(fill['reason']),
      summary: text(json['summary']),
      direction: json['direction'] is Map ? Direction.fromJson(Map<String, dynamic>.from(json['direction'] as Map)) : null,
      judgedAt: DateTime.now(),
      picks: [
        for (final p in (json['picks'] as List? ?? const []))
          if (p is Map && '${p['id'] ?? ''}'.trim().isNotEmpty) (id: '${p['id']}'.trim(), reason: '${p['reason'] ?? ''}'.trim()),
      ],
    );
  }
}
