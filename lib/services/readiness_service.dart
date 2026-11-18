// 홈 "준비도" 계산 (구조 3안: 부족한 것만 추천)
//
// 항목 5개(포트폴리오·성적·어학·직무 역량·자격증)를 각각 0~100점으로 매기고, 관심 분야·희망 기업 유형에 따라 다른 비중으로 더합니다.
//   준비도 = Σ (항목 점수 × 항목 비중)
//
// 항목 점수는 "근거"로 매깁니다. (기록만 있으면 0.3, 숫자 결과가 있으면 0.6, 첨부·수료증이 있으면 1.0)
// 100점 = 신입 합격자 수준. 처음 시작하는 사람은 대부분 0~20점이 나오도록 빡빡하게 잡았습니다. (2026-11-17 주아 요청)
// 목표 학점·어학 점수와 비중은 아래 근거를 바탕으로 정한 "앱 기준값"이라 바꿔 가며 다듬으면 됩니다.
//   - 경총 2024 신규채용 실태조사(100인 이상 500개사): 가장 중요한 평가 요소 1위 '직무 관련 업무 경험' 74.6%
//   - 자소설닷컴 2025 상반기 지원자 평균: 학점 3.68 / 4.5, 토익 848점
//   - 제로베이스 2026 IT 대기업 합격자 분석: 유관 직무 경험 96.3%, 프로젝트 경험 77.8%
//
// AI 판단은 readiness_ai.dart 에서 합니다. 이 파일의 규칙 계산은
//   1) AI 키가 없거나 AI가 실패할 때 대신 보여 주는 값, 2) AI에게 함께 주는 참고값으로 씁니다.

import '../models/diagnosis_profile.dart';
import '../models/models.dart';

/// 홈에 보이는 5개 항목
enum ReadinessArea { portfolio, grades, language, jobSkill, certificate }

const readinessAreaLabel = {
  ReadinessArea.portfolio: '포트폴리오',
  ReadinessArea.grades: '성적',
  ReadinessArea.language: '어학',
  ReadinessArea.jobSkill: '직무 역량',
  ReadinessArea.certificate: '자격증',
};

/// AI 와 저장소에서 쓰는 영문 키
const readinessAreaKey = {
  ReadinessArea.portfolio: 'portfolio',
  ReadinessArea.grades: 'grades',
  ReadinessArea.language: 'language',
  ReadinessArea.jobSkill: 'job_skill',
  ReadinessArea.certificate: 'certificate',
};

ReadinessArea? areaFromKey(String? key) {
  for (final e in readinessAreaKey.entries) {
    if (e.value == key) return e.key;
  }
  return null;
}

/// 준비도를 누가 판단했는지
enum ReadinessSource { ai, rule }

/// AI 가 추천한 방향 (분야·기업·직무를 모를 때)
class Direction {
  const Direction({required this.message, this.fields = const [], this.jobs = const [], this.companyTypes = const []});

  final String message;
  final List<String> fields;

  /// (이름, 이유)
  final List<({String name, String why})> jobs;
  final List<({String name, String why})> companyTypes;

  bool get isEmpty => message.isEmpty && jobs.isEmpty && companyTypes.isEmpty;

  static List<({String name, String why})> _pairs(Object? v) => [
        for (final e in (v as List? ?? const []))
          if (e is Map && '${e['name'] ?? ''}'.trim().isNotEmpty) (name: '${e['name']}'.trim(), why: '${e['why'] ?? ''}'.trim()),
      ];

  factory Direction.fromJson(Map<String, dynamic> j) => Direction(
        message: '${j['message'] ?? ''}'.trim(),
        fields: [for (final f in (j['fields'] as List? ?? const [])) if ('$f'.trim().isNotEmpty) '$f'.trim()],
        jobs: _pairs(j['jobs']),
        companyTypes: _pairs(j['company_types']),
      );

  Map<String, dynamic> toJson() => {
        'message': message,
        'fields': fields,
        'jobs': [for (final e in jobs) {'name': e.name, 'why': e.why}],
        'company_types': [for (final e in companyTypes) {'name': e.name, 'why': e.why}],
      };
}

/// 항목 상태 배지
enum AreaStatus { met, partial, lacking }

const areaStatusLabel = {
  AreaStatus.met: '충족',
  AreaStatus.partial: '일부',
  AreaStatus.lacking: '부족',
};

/// 하루 상태(진단 1번)에서 정하는 "지금 추천해도 되는 활동의 크기"
enum UserStage {
  /// 생활 리듬부터 (프로젝트·공모전 추천 X)
  rhythm,

  /// 사람 만나기·교류부터
  social,

  /// 수준에 맞는 교육·공모전 탐색
  explore,

  /// 부족한 항목을 바로 채우기
  ready,
}

const userStageLabel = {
  UserStage.rhythm: '생활 리듬 되찾는 중',
  UserStage.social: '사람들과 연결되는 중',
  UserStage.explore: '경험 쌓을 거리 찾는 중',
  UserStage.ready: '취업 준비 중',
};

/// 진단 1번 답 → 단계. 리듬이 돌아오면 이 답을 바꿔서 다음 단계로 넘어갑니다.
const stageAnswers = {
  UserStage.rhythm: '일상 리듬이 무너져 대부분 집에서 보내고 있어요.',
  UserStage.social: '다른 사람들과 교류할 기회가 많지 않아요.',
  UserStage.explore: '취업을 위해 교육이나 공모전을 알아보고 있어요.',
  UserStage.ready: '이력서나 포트폴리오를 준비하며 취업 준비 중이에요.',
};

UserStage stageOf(DiagnosisProfile d) {
  final status = d.currentStatus;
  for (final e in stageAnswers.entries) {
    if (e.value == status) return e.key;
  }
  // '잘 모르겠어요' 또는 미응답: 2번(먼저 도전하고 싶은 것)으로 정합니다.
  return switch (d.primaryGoal) {
    '생활 리듬 되찾기' => UserStage.rhythm,
    '사람 만나기' => UserStage.social,
    '바로 취업 준비' => UserStage.ready,
    _ => UserStage.explore,
  };
}

/// 근거 하나 (자세히 보기에 그대로 보여 줍니다)
class Evidence {
  const Evidence(this.title, this.weight, this.kind);

  final String title;

  /// 0.3 기록만 / 0.6 숫자 결과 / 1.0 첨부·수료·완료
  final double weight;
  final String kind;

  Map<String, dynamic> toJson() => {'title': title, 'weight': weight, 'kind': kind};

  factory Evidence.fromJson(Map<String, dynamic> j) =>
      Evidence('${j['title'] ?? ''}', (j['weight'] as num?)?.toDouble() ?? 0.5, '${j['kind'] ?? ''}');
}

class AreaResult {
  const AreaResult({
    required this.area,
    required this.score,
    required this.weight,
    required this.evidence,
    required this.gaps,
    required this.nextAction,
    required this.howScored,
    this.applicable = true,
    this.value,
    this.max,
    this.target,
  });

  final ReadinessArea area;

  /// false 면 이 사람에게 해당 없는 항목 (예: 대학을 안 다녔으면 성적). 비중 0.
  /// 비중이 0 인 항목(예: 자격증을 거의 안 보는 곳)도 화면에서 숨깁니다. ([ReadinessResult.shownAreas])
  final bool applicable;

  /// 실제 값 표시용 (성적: 학점, 어학: 토익 환산). 없으면 점수/100 으로 보여 줍니다.
  final double? value;
  final double? max;
  final double? target;

  /// 0~100
  final int score;

  /// 준비도에서 차지하는 비중 (0~1, 5개 합 1)
  final double weight;
  final List<Evidence> evidence;

  /// 부족한 점 (자세히 보기)
  final List<String> gaps;

  /// 이 항목을 채우려면 지금 할 일 한 줄
  final String nextAction;

  /// 점수를 어떻게 매겼는지 한 줄
  final String howScored;

  String get label => readinessAreaLabel[area]!;

  AreaStatus get status => score >= 80
      ? AreaStatus.met
      : score >= 40
          ? AreaStatus.partial
          : AreaStatus.lacking;

  /// 이 항목을 100점으로 채우면 준비도가 몇 점 오르는지
  int get gain => applicable ? ((100 - score) * weight).round() : 0;

  AreaResult copyWith({int? score, double? weight, List<String>? gaps, String? nextAction, List<Evidence>? evidence}) =>
      AreaResult(
        area: area,
        score: score ?? this.score,
        weight: weight ?? this.weight,
        evidence: evidence ?? this.evidence,
        gaps: gaps ?? this.gaps,
        nextAction: nextAction ?? this.nextAction,
        howScored: howScored,
        applicable: applicable,
        value: value,
        max: max,
        target: target,
      );

  Map<String, dynamic> toJson() => {
        'key': readinessAreaKey[area],
        'score': score,
        'weight': weight,
        'applicable': applicable,
        'evidence': [for (final e in evidence) e.toJson()],
        'gaps': gaps,
        'next_action': nextAction,
        'how_scored': howScored,
        'value': value,
        'max': max,
        'target': target,
      };

  static AreaResult? fromJson(Map<String, dynamic> j) {
    final area = areaFromKey(j['key'] as String?);
    if (area == null) return null;
    return AreaResult(
      area: area,
      score: ((j['score'] as num?) ?? 0).round().clamp(0, 100),
      weight: (j['weight'] as num?)?.toDouble() ?? 0,
      applicable: j['applicable'] as bool? ?? true,
      evidence: [for (final e in (j['evidence'] as List? ?? const [])) Evidence.fromJson(Map<String, dynamic>.from(e as Map))],
      gaps: [for (final g in (j['gaps'] as List? ?? const [])) '$g'],
      nextAction: '${j['next_action'] ?? ''}',
      howScored: '${j['how_scored'] ?? ''}',
      value: (j['value'] as num?)?.toDouble(),
      max: (j['max'] as num?)?.toDouble(),
      target: (j['target'] as num?)?.toDouble(),
    );
  }
}

/// 준비도 기준 (관심 분야 + 희망 기업 유형 + 직접 입력한 기업·직무)
class ReadinessTarget {
  const ReadinessTarget({
    required this.field,
    required this.companyType,
    required this.gpa45,
    required this.toeic,
    required this.toeicCutoff,
    this.companyName,
    this.jobName,
  });

  /// IT·데이터 / 디자인·영상 / 사무·행정 / null(모름)
  final String? field;

  /// 스타트업 / 중소기업 / 중견기업 / 대기업 / 공기업·공공기관 / null(고민 중)
  final String? companyType;

  /// 목표 학점 (4.5 만점 기준)
  final double gpa45;

  /// 목표 어학 (토익 환산). 이 점수면 100점
  final int toeic;

  /// 서류 커트라인 (토익 환산). 넘으면 어학은 최소 70점(충족에 가까움)
  final int toeicCutoff;
  final String? companyName;
  final String? jobName;

  /// "삼성전자 · 데이터 분석" / "대기업 · IT·데이터" 처럼 화면에 보이는 기준
  String get label {
    final where = companyName ?? companyType ?? '기업 고민 중';
    final what = jobName ?? field ?? '분야 탐색 중';
    return '$where · $what';
  }

  bool get isUndecided => companyType == null || field == null;
}

class ReadinessResult {
  const ReadinessResult({
    required this.score,
    required this.areas,
    required this.target,
    required this.stage,
    this.source = ReadinessSource.rule,
    this.fillArea,
    this.fillTitle,
    this.fillReason,
    this.summary,
    this.direction,
    this.judgedAt,
  });

  /// 종합 준비도 0~100
  final int score;
  final List<AreaResult> areas;
  final ReadinessTarget target;
  final UserStage stage;
  final ReadinessSource source;

  /// AI 가 고른 "지금 채우면 좋은 것" (없으면 규칙: 가장 많이 오르는 항목)
  final ReadinessArea? fillArea;
  final String? fillTitle;
  final String? fillReason;

  /// AI 한 줄 총평
  final String? summary;

  /// AI 가 추천한 방향 (분야·기업·직무를 모를 때만)
  final Direction? direction;
  final DateTime? judgedAt;

  List<AreaResult> get shownAreas => areas.where((a) => a.applicable && a.weight > 0).toList();

  int get metCount => shownAreas.where((a) => a.status == AreaStatus.met).length;

  String get levelLabel => score >= 80
      ? '지원해 볼 만해요'
      : score >= 60
          ? '거의 다 왔어요'
          : '준비 중';

  /// 가장 먼저 채우면 좋은 항목: 채웠을 때 준비도가 가장 많이 오르는 항목
  AreaResult get weakest {
    if (fillArea != null) {
      for (final a in areas) {
        if (a.area == fillArea && a.applicable && a.weight > 0) return a;
      }
    }
    final sorted = [...shownAreas]
      ..sort((a, b) {
        final g = b.gain.compareTo(a.gain);
        return g != 0 ? g : a.score.compareTo(b.score);
      });
    return sorted.first;
  }

  AreaResult area(ReadinessArea a) => areas.firstWhere((x) => x.area == a);

  Map<String, dynamic> toJson() => {
        'score': score,
        'source': source.name,
        'areas': [for (final a in areas) a.toJson()],
        'fill_area': fillArea == null ? null : readinessAreaKey[fillArea],
        'fill_title': fillTitle,
        'fill_reason': fillReason,
        'summary': summary,
        'direction': direction?.toJson(),
        'judged_at': judgedAt?.toIso8601String(),
      };

  /// 저장해 둔 결과 읽기. target·stage 는 저장하지 않고 현재 진단에서 다시 만듭니다.
  static ReadinessResult? fromJson(Map<String, dynamic> j, {required ReadinessTarget target, required UserStage stage}) {
    final areas = [
      for (final a in (j['areas'] as List? ?? const []))
        ?AreaResult.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
    if (areas.length != ReadinessArea.values.length) return null;
    return ReadinessResult(
      score: ((j['score'] as num?) ?? 0).round().clamp(0, 100),
      areas: areas,
      target: target,
      stage: stage,
      source: j['source'] == 'ai' ? ReadinessSource.ai : ReadinessSource.rule,
      fillArea: areaFromKey(j['fill_area'] as String?),
      fillTitle: j['fill_title'] as String?,
      fillReason: j['fill_reason'] as String?,
      summary: j['summary'] as String?,
      direction: j['direction'] is Map ? Direction.fromJson(Map<String, dynamic>.from(j['direction'] as Map)) : null,
      judgedAt: DateTime.tryParse('${j['judged_at'] ?? ''}'),
    );
  }
}

class ReadinessService {
  ReadinessService._();

  // ───────────── 기준값

  /// 기업 유형별 목표 (학점 4.5 만점, 어학 커트라인, 어학 목표 — 어학은 토익 환산)
  /// 대기업 목표는 2025 상반기 지원자 평균(3.68 / 848)을 반올림한 값, 나머지는 앱 기준값입니다.
  /// 어학은 "커트라인을 넘었는지"가 가장 중요합니다. (공기업은 보통 토익 700 정도 이상이면 지원 가능, 기관마다 다름)
  static const companyTargets = <String, (double, int, int)>{
    '대기업': (3.7, 700, 850),
    '공기업·공공기관': (3.5, 700, 800),
    '중견기업': (3.5, 600, 750),
    '중소기업': (3.2, 550, 650),
    '스타트업': (3.0, 500, 600),
  };
  static const _undecidedTarget = (3.3, 600, 700);

  /// 관심 분야별 비중 (포트폴리오, 성적, 어학, 직무 역량, 자격증)
  /// 직무 경험(직무 역량)은 어느 분야든 가장 중요하게 둡니다. (경총 조사 1위)
  /// 자격증은 사무·행정(컴활 등)에서 높게, 디자인처럼 결과물로 보는 분야에서는 낮게 둡니다.
  /// AI 판단에서는 AI 가 목표 회사·직무를 보고 비중을 다시 정합니다. (readiness_ai.dart)
  static const fieldWeights = <String, List<double>>{
    'IT·데이터': [0.30, 0.07, 0.08, 0.40, 0.15],
    '디자인·영상': [0.45, 0.05, 0.05, 0.40, 0.05],
    '사무·행정': [0.15, 0.15, 0.15, 0.35, 0.20],
  };
  static const _defaultWeights = [0.25, 0.10, 0.10, 0.40, 0.15];

  /// 분야별로 서류에서 많이 보는 자격증 (이름에 이 낱말이 있으면 "목표에 맞는 자격증")
  static const fieldCertificates = <String, List<String>>{
    'IT·데이터': ['정보처리', 'SQLD', 'SQL', 'ADsP', 'ADP', '빅데이터', '리눅스', '네트워크관리사', 'AWS', '정보보안'],
    '디자인·영상': ['GTQ', '컬러리스트', '시각디자인', '웹디자인', '컴퓨터그래픽', 'ACA', '영상'],
    '사무·행정': ['컴퓨터활용', '컴활', '전산회계', '전산세무', '회계', 'ERP', '워드프로세서', 'MOS', '비서', '사무자동화'],
  };

  /// 공기업에서 가산점이 흔한 자격증
  static const publicCertificates = ['한국사', '컴퓨터활용', '컴활'];

  /// 분야별로 처음 따기 좋은 자격증 (할 일 문장용)
  static const firstCertificate = <String, String>{
    'IT·데이터': 'SQLD',
    '디자인·영상': 'GTQ',
    '사무·행정': '컴퓨터활용능력 2급',
  };

  /// 분야별 "직무 관련" 기록을 찾는 낱말
  static const fieldKeywords = <String, List<String>>{
    'IT·데이터': ['데이터', '엑셀', 'SQL', '파이썬', 'Python', '코딩', '개발', '분석', '앱', '웹', 'AI', '자동화', '대시보드', '통계', 'ADsP', 'SQLD', '컴활'],
    '디자인·영상': ['디자인', '영상', '편집', '피그마', 'Figma', '포토샵', '일러스트', '촬영', '브랜딩', '썸네일', '프리미어', '콘텐츠'],
    '사무·행정': ['엑셀', '문서', '행정', '사무', '회계', '정리', '보고서', '컴활', 'ERP', '워드', '파워포인트', '민원', '자료'],
  };

  // ───────────── 계산

  static ReadinessTarget targetOf(DiagnosisProfile d, AppUser user) {
    final interest = d.interest;
    final field = (interest == null || interest == '아직 잘 모르겠어요')
        ? (user.interests.isEmpty ? null : user.interests.first)
        : interest;
    final company = companyTargets.containsKey(d.companyPreference) ? d.companyPreference : null;
    final (gpa, cutoff, toeic) = companyTargets[company] ?? _undecidedTarget;
    return ReadinessTarget(
      field: field,
      companyType: company,
      gpa45: gpa,
      toeic: toeic,
      toeicCutoff: cutoff,
      companyName: d.targetCompanyName,
      jobName: d.targetJobName,
    );
  }

  /// [hasGpa] 가 false 면(대학을 안 다님) 성적 비중을 어학으로 옮깁니다. 합은 항상 1.
  static List<double> weightsOf(ReadinessTarget t, {bool hasGpa = true}) {
    final w = [...(fieldWeights[t.field] ?? _defaultWeights)];
    switch (t.companyType) {
      // 대기업: 서류 기준(학점·어학)이 있는 곳이 많아 성적·어학 +
      case '대기업':
        w[1] += 0.025;
        w[2] += 0.025;
        w[0] -= 0.05;
      // 공기업: 블라인드라 포트폴리오는 거의 안 보고, 어학 커트라인·자격증 가산점이 중요
      case '공기업·공공기관':
        w[1] += 0.025;
        w[2] += 0.025;
        w[4] += 0.10;
        w[0] -= 0.15;
      // 스타트업: 결과물 위주, 자격증은 거의 안 봄
      case '스타트업':
        w[0] += 0.05 + w[4] / 2;
        w[1] -= 0.025;
        w[2] -= 0.025;
        w[4] /= 2;
    }
    if (!hasGpa) {
      w[2] += w[1];
      w[1] = 0;
    }
    return normalizeWeights(w);
  }

  /// 음수는 0 으로, 합은 1 로
  static List<double> normalizeWeights(List<double> w) {
    final c = [for (final x in w) x < 0 ? 0.0 : x];
    final sum = c.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return [for (final _ in c) 1 / c.length];
    return [for (final x in c) x / sum];
  }

  static ReadinessResult evaluate({
    required AppUser user,
    required DiagnosisProfile diagnosis,
    required List<ActivityRecord> records,
    required List<TeamPost> acceptedTeams,
    required Set<String> doneTeamIds,
  }) {
    final target = targetOf(diagnosis, user);
    final hasGpa = isUniversity(user.education);
    final w = weightsOf(target, hasGpa: hasGpa);

    final areas = [
      _portfolio(records, diagnosis, w[0]),
      _gpa(user, target, w[1]),
      _language(user, target, diagnosis, w[2]),
      _jobSkill(records, target, w[3]),
      _certificate(user, target, w[4]),
    ];

    final total = areas.fold<double>(0, (sum, a) => sum + a.score * a.weight);
    return ReadinessResult(
      score: total.round().clamp(0, 100),
      areas: areas,
      target: target,
      stage: stageOf(diagnosis),
    );
  }

  /// 기록 하나의 근거 점수
  static double evidenceWeight(ActivityRecord r) {
    if (r.attachments.isNotEmpty) return 1.0;
    final text = '${r.star.a} ${r.star.r} ${r.raw}';
    if (RegExp(r'\d').hasMatch(text)) return 0.6;
    return 0.3;
  }

  static String _kind(double w) => w >= 1.0 ? '첨부 있음' : (w >= 0.6 ? '숫자 결과' : '기록만');

  /// 항목별로 몇 개가 있어야 100점인지 (신입 합격자 수준)
  static const portfolioNeed = 5;
  static const jobSkillNeed = 3;
  static const certificateNeed = 2;

  static String _text(ActivityRecord r) => '${r.title} ${r.raw} ${r.star.s} ${r.star.t} ${r.star.a} ${r.star.r}';

  // 포트폴리오: 결과물이 붙은 기록 5개면 100점
  static AreaResult _portfolio(List<ActivityRecord> records, DiagnosisProfile d, double weight) {
    final ev = [for (final r in records) Evidence(r.title, evidenceWeight(r), _kind(evidenceWeight(r)))]
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final top = ev.take(portfolioNeed).fold<double>(0, (s, e) => s + e.weight);
    final score = (top / portfolioNeed * 100).round().clamp(0, 100);
    final withFile = ev.where((e) => e.weight >= 1.0).length;

    final gaps = <String>[
      if (ev.length < portfolioNeed) '정리된 활동 기록이 ${ev.length}개예요. 결과물이 붙은 기록 $portfolioNeed개가 목표예요.',
      if (withFile < portfolioNeed && ev.isNotEmpty) '결과물(파일·링크)이 붙은 기록이 $withFile개예요. 기록에 결과물을 붙이면 점수가 올라요.',
      if (ev.any((e) => e.weight < 0.6)) '숫자로 된 결과가 없는 기록이 있어요. "몇 번, 몇 %"처럼 결과를 적어 보세요.',
      if (d.hasPortfolio == true && ev.isEmpty) '진단에서 포트폴리오가 있다고 했어요. 활동 기록에 올리면 바로 반영돼요.',
    ];
    return AreaResult(
      area: ReadinessArea.portfolio,
      score: score,
      weight: weight,
      evidence: ev,
      gaps: gaps,
      nextAction: ev.isEmpty
          ? '해 본 활동 하나를 기록으로 남기기'
          : (withFile < ev.length ? '기록 하나에 결과물(파일·링크) 붙이기' : '새 활동 하나 기록하기'),
      howScored: '근거가 좋은 기록 $portfolioNeed개까지 더해요. (첨부 1.0 · 숫자 결과 0.6 · 기록만 0.3) ÷ $portfolioNeed',
    );
  }

  // 성적: 학점(대학 재학·졸업만)을 목표 대비로
  static AreaResult _gpa(AppUser user, ReadinessTarget t, double weight) {
    if (!isUniversity(user.education)) {
      return AreaResult(
        area: ReadinessArea.grades,
        score: 0,
        weight: 0,
        evidence: const [],
        gaps: const [],
        nextAction: '',
        howScored: '대학을 다니지 않았다면 학점은 보지 않아요. 비중은 어학으로 옮겨요.',
        applicable: false,
      );
    }
    final gpa = user.gpa;
    final gpa45 = gpa == null ? null : gpa * 4.5 / user.gpaScale;
    final score = gpa45 == null ? 0 : ((gpa45 / t.gpa45).clamp(0.0, 1.0) * 100).round();
    return AreaResult(
      area: ReadinessArea.grades,
      score: score,
      weight: weight,
      evidence: [if (gpa != null) Evidence('학점 ${_fmt(gpa)} / ${_fmt(user.gpaScale)}', 1.0, '입력함')],
      gaps: [
        if (gpa45 == null) '학점을 아직 입력하지 않았어요.',
        if (gpa45 != null && gpa45 < t.gpa45)
          '학점이 목표(${_fmt(t.gpa45)} / 4.5)보다 ${_fmt(t.gpa45 - gpa45)} 낮아요. 졸업했다면 다른 항목으로 채우는 게 빨라요.',
      ],
      nextAction: gpa == null ? '내 정보에 학점 입력하기' : '학점보다 다른 항목 먼저 채우기',
      howScored: '학점을 4.5 만점으로 바꿔 목표 대비로 계산 (목표: ${_fmt(t.gpa45)} / 4.5)',
      value: gpa45,
      max: 4.5,
      target: t.gpa45,
    );
  }

  // 어학: 가장 좋은 어학 성적을 토익으로 환산해서 "커트라인을 넘었는지" 먼저 봅니다.
  //   커트라인 미만: 0~60점 (커트라인 대비) / 커트라인 이상: 70점 + 목표까지 남은 만큼 최대 30점
  //   예) 공기업(커트라인 700, 목표 800)에 OPIc IM(토익 약 750) → 85점 = 충족
  static int languageScore(int? toeic, ReadinessTarget t) {
    if (toeic == null) return 0;
    if (toeic < t.toeicCutoff) return (60 * toeic / t.toeicCutoff).round().clamp(0, 60);
    final span = t.toeic - t.toeicCutoff;
    final over = span <= 0 ? 1.0 : ((toeic - t.toeicCutoff) / span).clamp(0.0, 1.0);
    return (70 + 30 * over).round();
  }

  static AreaResult _language(AppUser user, ReadinessTarget t, DiagnosisProfile d, double weight) {
    final best = bestLanguage(user.languages);
    final toeic = best?.$2;
    return AreaResult(
      area: ReadinessArea.language,
      score: languageScore(toeic, t),
      weight: weight,
      evidence: [
        if (best != null)
          Evidence('${best.$1.exam} ${best.$1.score}${best.$1.exam == 'TOEIC' ? '' : ' (토익 약 ${best.$2}점)'}', 1.0, '입력함'),
      ],
      gaps: [
        if (best == null)
          d.hasLanguageScore == true
              ? '진단에서 어학 성적이 있다고 했어요. 내 정보에 점수를 넣어 주세요.'
              : '어학 성적이 없어요. (보통 토익 ${t.toeicCutoff}점 정도 이상을 봐요)',
        if (toeic != null && toeic < t.toeicCutoff) '서류 커트라인(토익 ${t.toeicCutoff}점 정도)보다 ${t.toeicCutoff - toeic}점 낮아요.',
        if (toeic != null && toeic >= t.toeicCutoff && toeic < t.toeic) '커트라인은 넘었어요. 토익 ${t.toeic}점 정도면 더 좋아요.',
      ],
      nextAction: best == null
          ? (d.hasLanguageScore == true ? '내 정보에 어학 점수 넣기' : '토익스피킹·오픽 시험 일정 확인하기')
          : (toeic! < t.toeicCutoff ? '커트라인 넘길 시험 일정 확인하기' : '어학은 충분해요. 다른 항목 먼저 채우기'),
      howScored: '가장 좋은 어학 성적을 토익으로 바꿔(대략값) 커트라인(${t.toeicCutoff})을 넘으면 70점부터, 목표(${t.toeic})면 100점',
      value: toeic?.toDouble(),
      max: 990,
      target: t.toeicCutoff.toDouble(),
    );
  }

  // 직무 역량: 희망 직무(없으면 관심 분야)와 관련된 경험 3개면 100점.
  // 목표 직무가 없으면 무엇에 대한 역량인지 판단할 수 없어서 절반만 인정합니다. 분야도 없으면 0점.
  static AreaResult _jobSkill(List<ActivityRecord> records, ReadinessTarget t, double weight) {
    final words = [
      ...?fieldKeywords[t.field],
      if (t.jobName != null) ...t.jobName!.split(RegExp(r'\s+')),
    ];
    final related = words.isEmpty
        ? <ActivityRecord>[]
        : records.where((r) {
            final text = _text(r).toLowerCase();
            return words.any((w) => w.length > 1 && text.contains(w.toLowerCase()));
          }).toList();
    final ev = [for (final r in related) Evidence(r.title, evidenceWeight(r), _kind(evidenceWeight(r)))]
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final top = ev.take(jobSkillNeed).fold<double>(0, (s, e) => s + e.weight);
    final noJob = t.jobName == null;
    final score = (top / jobSkillNeed * 100 * (noJob ? 0.5 : 1.0)).round().clamp(0, 100);
    final what = t.jobName ?? t.field ?? '희망 직무';

    return AreaResult(
      area: ReadinessArea.jobSkill,
      score: score,
      weight: weight,
      evidence: ev,
      gaps: [
        if (t.field == null && noJob) '관심 분야·직무가 아직 없어서 직무 역량을 판단할 수 없어요. 먼저 해 보고 싶은 일을 정해요.'
        else if (noJob) '희망 직무가 없어서 $what 관련 경험을 절반만 인정했어요. 직무를 정하면 제대로 계산돼요.',
        if (ev.length < jobSkillNeed) '$what 관련 경험이 ${ev.length}개예요. $jobSkillNeed개가 목표예요.',
        if (ev.isNotEmpty && ev.every((e) => e.weight < 1.0)) '$what 관련 결과물(수료증·작업물)이 아직 없어요.',
      ],
      nextAction: '$what 관련 교육이나 공모전 하나 신청하기',
      howScored: '$what 관련 기록 $jobSkillNeed개까지 더해요. (첨부 1.0 · 숫자 결과 0.6 · 기록만 0.3) ÷ $jobSkillNeed · 희망 직무가 없으면 × 0.5',
    );
  }

  // 자격증: 목표(분야·공기업)에 맞는 자격증 2개면 100점, 다른 자격증은 1개당 15점(최대 30점)
  static AreaResult _certificate(AppUser user, ReadinessTarget t, double weight) {
    final words = [
      ...?fieldCertificates[t.field],
      if (t.companyType == '공기업·공공기관') ...publicCertificates,
    ];
    bool fits(Certificate c) {
      final name = c.name.replaceAll(' ', '').toUpperCase();
      return words.any((w) => name.contains(w.replaceAll(' ', '').toUpperCase()));
    }

    final good = [for (final c in user.certificates) if (fits(c)) c];
    final other = [for (final c in user.certificates) if (!fits(c)) c];
    final score = (good.length / certificateNeed * 100 + (other.length * 15).clamp(0, 30)).round().clamp(0, 100);
    final first = firstCertificate[t.field] ?? '컴퓨터활용능력 2급';
    final suggest = t.companyType == '공기업·공공기관' ? '$first·한국사능력검정' : first;

    return AreaResult(
      area: ReadinessArea.certificate,
      score: score,
      weight: weight,
      evidence: [
        for (final c in good) Evidence(c.name, 1.0, '목표에 맞음'),
        for (final c in other) Evidence(c.name, 0.3, '다른 자격증'),
      ],
      gaps: [
        if (user.certificates.isEmpty) '자격증이 없어요. 내 정보에 있으면 넣어 주세요.',
        if (good.length < certificateNeed) '목표에서 많이 보는 자격증($suggest 등)이 ${good.length}개예요.',
      ],
      nextAction: good.isEmpty ? '$suggest 시험 일정 확인하기' : '다음 자격증 시험 일정 확인하기',
      howScored: '목표에 맞는 자격증 1개당 50점 ($certificateNeed개면 100점), 다른 자격증은 1개당 15점(최대 30점)',
    );
  }

  // ───────────── 도우미

  static bool isUniversity(String education) =>
      education.contains('대학') || education.contains('대졸') || education.contains('석·박사');

  /// 가장 좋은 어학 성적과 토익 환산 점수 (대략값)
  static (LanguageScore, int)? bestLanguage(List<LanguageScore> list) {
    (LanguageScore, int)? best;
    for (final l in list) {
      final t = toeicEquivalent(l);
      if (t == null) continue;
      if (best == null || t > best.$2) best = (l, t);
    }
    return best;
  }

  /// 토익 환산 (대략값). 모르는 시험은 null.
  static int? toeicEquivalent(LanguageScore l) {
    final exam = l.exam.toUpperCase().replaceAll(' ', '');
    final s = l.score.toUpperCase().replaceAll(' ', '');
    final n = int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '');

    if (exam == 'TOEIC' || exam.contains('토익') && !exam.contains('스피킹')) {
      return n?.clamp(0, 990);
    }
    if (exam.contains('SPEAKING') || exam.contains('스피킹')) {
      if (n == null) return null;
      if (n <= 8) return const {8: 950, 7: 880, 6: 800, 5: 700, 4: 600, 3: 500}[n] ?? 400; // 레벨
      return n >= 160 ? 880 : n >= 130 ? 800 : n >= 110 ? 700 : 600; // 점수
    }
    if (exam.contains('OPIC') || exam.contains('오픽')) {
      const opic = {'AL': 950, 'IH': 880, 'IM3': 830, 'IM2': 780, 'IM1': 720, 'IM': 750, 'IL': 600, 'NH': 500};
      return opic[s];
    }
    if (exam.contains('TOEFL')) {
      if (n == null) return null;
      return n >= 100 ? 950 : n >= 90 ? 880 : n >= 80 ? 800 : n >= 70 ? 720 : 600;
    }
    return null;
  }

  static String _fmt(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
}

/// 관심 분야별 대표 직무 (기업·직무를 고민 중일 때 보여 줍니다)
const fieldJobs = <String, List<String>>{
  'IT·데이터': ['데이터 분석', '웹 개발', 'IT 지원'],
  '디자인·영상': ['영상 편집', 'UI 디자인', '콘텐츠 디자인'],
  '사무·행정': ['일반 사무', '회계 사무', '공공기관 행정'],
};

/// 관심 분야가 없을 때 "좋아하는 것 찾기"용 맛보기 활동
const fieldTasters = <String, String>{
  'IT·데이터': '엑셀로 한 달 지출 표 만들어 보기',
  '디자인·영상': '휴대폰으로 30초 영상 하나 편집해 보기',
  '사무·행정': '관심 있는 공고문 하나 요약해 보기',
};

/// 전공으로 어울리는 분야 추측 (의욕이 낮은 사용자 격려용). 모르면 null.
String? fieldFromMajor(String major) {
  const map = {
    'IT·데이터': ['컴퓨터', '소프트웨어', '정보', '통계', '데이터', '전자', '공학', '수학'],
    '디자인·영상': ['디자인', '미디어', '영상', '미술', '시각', '방송', '예술'],
    '사무·행정': ['경영', '행정', '경제', '회계', '법', '사회', '무역', '세무'],
  };
  for (final e in map.entries) {
    if (e.value.any(major.contains)) return e.key;
  }
  return null;
}

/// 받침에 따라 조사를 붙입니다. josa('포트폴리오', '이', '가') → '포트폴리오가'
String josa(String word, String withBatchim, String withoutBatchim) {
  if (word.isEmpty) return word;
  final code = word.runes.last;
  final hasBatchim = code >= 0xAC00 && code <= 0xD7A3 && (code - 0xAC00) % 28 != 0;
  return '$word${hasBatchim ? withBatchim : withoutBatchim}';
}
