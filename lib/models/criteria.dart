// 관심기업 · 지원 기준치 모델 (3안: 레벨·STEP 없이 부족한 것만 추천)
//
// 홈에서 "포트폴리오 · 성적/학력 · 직무연관성 · 어학 · 협업경험" 5개 영역이
// 관심기업 기준치를 충족하는지 보여 줄 때 쓰는 데이터입니다.
// 화면 코드는 여기 없고, 계산은 services/criteria_service.dart 에 있습니다.
//
// Flutter 를 import 하지 않는 순수 Dart 파일입니다. (테스트·백엔드 이전이 쉬움)

/// 기업 유형. 라벨은 진단(company_preference) 선택지와 같게 맞췄습니다.
enum CompanyTier {
  startup('스타트업'),
  small('중소기업'),
  mid('중견기업'),
  large('대기업'),
  public('공기업·공공기관');

  const CompanyTier(this.label);
  final String label;

  /// 진단 답변 등 라벨 문자열 → 유형. 모르면 null
  static CompanyTier? fromLabel(String? v) {
    for (final t in values) {
      if (t.label == v) return t;
    }
    return null;
  }
}

/// 직무 묶음. 기준치 보정과 '직무연관성' 판단(키워드)에 씁니다.
enum JobGroup {
  dev(
    '개발',
    ['개발', '프로그래밍', '코딩', '앱', '웹', '서버', '백엔드', '프론트', 'flutter', 'java', 'python', 'github', '깃허브', '알고리즘', 'sql'],
    ['컴퓨터', '소프트웨어', '정보', '전자', '전산', '공학'],
  ),
  data(
    '데이터·AI',
    ['데이터', '분석', '통계', 'sql', 'python', '엑셀', '시각화', '머신러닝', 'ai', '인공지능', '피벗'],
    ['통계', '수학', '컴퓨터', '산업공학', '데이터', '경제'],
  ),
  design(
    '디자인·영상',
    ['디자인', '피그마', 'figma', '포토샵', '일러스트', '영상', '편집', '브랜딩', 'ui', 'ux', '촬영'],
    ['디자인', '미술', '영상', '시각', '미디어'],
  ),
  office(
    '사무·행정',
    ['사무', '행정', '엑셀', '문서', '회계', '총무', '인사', '컴활', '워드', '기록물', '민원'],
    ['경영', '행정', '회계', '경제', '법', '세무'],
  ),
  marketing(
    '마케팅·기획',
    ['마케팅', '기획', '홍보', 'sns', '콘텐츠', '브랜드', '광고', '캠페인', '공모전', '발표'],
    ['경영', '광고', '홍보', '미디어', '신문방송', '마케팅'],
  );

  const JobGroup(this.label, this.keywords, this.majorKeywords);
  final String label;

  /// 활동 기록 제목·내용에 이 단어가 있으면 직무 관련 경험으로 봅니다 (소문자로 비교)
  final List<String> keywords;

  /// 전공(학부) 이름에 이 단어가 있으면 전공 연관으로 봅니다
  final List<String> majorKeywords;

  /// 진단·회원가입의 관심 분야 → 직무 묶음 (모르면 null)
  static JobGroup? fromInterest(String? interest) => switch (interest) {
        'IT·데이터' => JobGroup.dev,
        '디자인·영상' => JobGroup.design,
        '사무·행정' => JobGroup.office,
        _ => null,
      };
}

/// 홈에 보여 줄 5개 영역
enum CriteriaArea {
  portfolio('포트폴리오'),
  academic('성적·학력'),
  jobFit('직무연관성'),
  language('어학'),
  teamwork('협업경험');

  const CriteriaArea(this.label);
  final String label;
}

/// 학력 단계. rank 가 클수록 높은 학력입니다.
enum EduLevel {
  none(0, '학력무관'),
  high(1, '고졸 이상'),
  college(2, '초대졸 이상'),
  univ(3, '4년제 대졸(예정) 이상'),
  graduate(4, '석사 이상');

  const EduLevel(this.rank, this.label);
  final int rank;
  final String label;
}

/// 관심기업 (사용자가 정한 목표)
class TargetCompany {
  const TargetCompany({
    required this.name,
    required this.tier,
    required this.jobGroup,
    this.jobTitle = '',
  });

  /// 기업 이름 (예: 네이버). 비워 두면 '대기업 개발' 처럼 유형만으로 기준을 잡습니다.
  final String name;
  final CompanyTier tier;
  final JobGroup jobGroup;

  /// 구체적인 직무 이름 (선택, 예: 백엔드 개발)
  final String jobTitle;

  String get jobLabel => jobTitle.isEmpty ? jobGroup.label : jobTitle;

  /// 화면 표시용 (예: 네이버 · 백엔드 개발)
  String get label => [name.isEmpty ? tier.label : name, jobLabel].join(' · ');

  TargetCompany copyWith({String? name, CompanyTier? tier, JobGroup? jobGroup, String? jobTitle}) =>
      TargetCompany(
        name: name ?? this.name,
        tier: tier ?? this.tier,
        jobGroup: jobGroup ?? this.jobGroup,
        jobTitle: jobTitle ?? this.jobTitle,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'tier': tier.name,
        'jobGroup': jobGroup.name,
        'jobTitle': jobTitle,
      };

  factory TargetCompany.fromJson(Map<String, dynamic> json) => TargetCompany(
        name: json['name'] as String? ?? '',
        tier: CompanyTier.values.byName(json['tier'] as String),
        jobGroup: JobGroup.values.byName(json['jobGroup'] as String),
        jobTitle: json['jobTitle'] as String? ?? '',
      );
}

/// 기준치를 어디서 가져왔는지
enum CriteriaSource {
  /// 기업 유형 × 직무로 우리가 정한 대략적인 기준 (data/criteria_data.dart)
  rough('기본 기준');

  const CriteriaSource(this.label);
  final String label;
}

/// 관심기업 하나의 지원 기준치
class CompanyCriteria {
  const CompanyCriteria({
    required this.target,
    required this.minEducation,
    required this.minGpa,
    required this.minEnglish,
    required this.minPortfolio,
    required this.minJobFit,
    required this.minTeamwork,
    this.sources = const {},
    this.note = '',
  });

  final TargetCompany target;

  /// 최소 학력 (EduLevel.none = 학력 안 봄)
  final EduLevel minEducation;

  /// 최소 학점 (4.5 만점 환산). null = 학점 안 봄
  final double? minGpa;

  /// 최소 영어 점수 (TOEIC 환산). null = 어학 필요 없음
  final int? minEnglish;

  /// 증빙(첨부·깃허브)이 있는 결과물 수
  final int minPortfolio;

  /// 직무 관련 경험 수 (전공 1 + 직무 키워드가 들어간 활동 기록)
  final int minJobFit;

  /// 팀 활동 수 (팀 프로젝트 + 협업 내용이 들어간 기록)
  final int minTeamwork;

  /// 영역별 출처. 없는 영역은 기본 기준(rough)
  final Map<CriteriaArea, CriteriaSource> sources;

  /// 기준 설명 (화면 하단 안내 문구)
  final String note;

  CriteriaSource sourceOf(CriteriaArea area) => sources[area] ?? CriteriaSource.rough;

  CompanyCriteria copyWith({
    EduLevel? minEducation,
    double? minGpa,
    bool clearGpa = false,
    int? minEnglish,
    bool clearEnglish = false,
    int? minPortfolio,
    int? minJobFit,
    int? minTeamwork,
    Map<CriteriaArea, CriteriaSource>? sources,
    String? note,
  }) =>
      CompanyCriteria(
        target: target,
        minEducation: minEducation ?? this.minEducation,
        minGpa: clearGpa ? null : (minGpa ?? this.minGpa),
        minEnglish: clearEnglish ? null : (minEnglish ?? this.minEnglish),
        minPortfolio: minPortfolio ?? this.minPortfolio,
        minJobFit: minJobFit ?? this.minJobFit,
        minTeamwork: minTeamwork ?? this.minTeamwork,
        sources: sources ?? this.sources,
        note: note ?? this.note,
      );
}

/// 영역별 충족 상태
enum AreaStatus {
  met('충족'),
  partial('조금 부족'),
  unmet('부족'),
  notRequired('필수 아님'),
  unknown('입력 필요');

  const AreaStatus(this.label);
  final String label;

  /// 기준을 넘었다고 봐도 되는 상태 (충족 · 필수 아님)
  bool get ok => this == met || this == notRequired;
}

/// 영역 하나의 판단 결과
class AreaResult {
  const AreaResult({
    required this.area,
    required this.status,
    required this.required,
    required this.current,
    this.hint = '',
    this.source = CriteriaSource.rough,
  });

  final CriteriaArea area;
  final AreaStatus status;

  /// 기준치 문장 (예: TOEIC 750 이상)
  final String required;

  /// 내 현재 상태 문장 (예: TOEIC 700)
  final String current;

  /// 부족할 때 할 일 한 줄 (추천 활동의 근거)
  final String hint;

  final CriteriaSource source;
}

/// 관심기업 기준 대비 5개 영역 결과
class ReadinessReport {
  const ReadinessReport({required this.criteria, required this.results});

  final CompanyCriteria criteria;

  /// CriteriaArea 순서대로 5개
  final List<AreaResult> results;

  AreaResult of(CriteriaArea area) => results.firstWhere((r) => r.area == area);

  /// 기준을 넘은 영역 수 (필수 아님 포함)
  int get okCount => results.where((r) => r.status.ok).length;

  bool get allOk => okCount == results.length;

  /// 부족하거나 입력이 필요한 영역 (홈의 '지금 하면 좋은 활동' 추천 근거)
  List<AreaResult> get gaps => results.where((r) => !r.status.ok).toList();
}
