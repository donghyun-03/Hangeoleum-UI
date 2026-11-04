// 화면에서 쓰는 데이터 모델.
// 백엔드 API 응답 모양이 정해지면 여기에 fromJson 을 추가하고, mock_data.dart 는 개발용으로만 남깁니다.

enum UserRole { youth, institution } // 청년 / 활동기관

/// 회원가입 학력 선택지. 사용자 모델에는 기존처럼 표시 문자열을 저장합니다.
enum Education {
  belowHigh('고졸 미만'),
  highStudent('고교 재학'),
  highExpected('고졸 예정'),
  highGrad('고교 졸업'),
  univStudent('대학 재학'),
  univExpected('대졸 예정'),
  univGrad('대학 졸업'),
  graduate('석·박사'),
  other('기타');

  const Education(this.label);

  final String label;
}

class AppUser {
  final String id;
  final UserRole role;
  final String email;
  final String name;
  final int age;
  final String gender; // 'female' | 'male'
  final String phone;
  final String major; // 학부
  final String education; // 학력
  final String address;
  final String addressDetail;
  final List<String> interests;
  final Map<String, bool> alerts; // policy, camp, saving, project
  final bool diagnosed; // AI 진단 완료 여부
  final int currentStep; // 1~4
  final String intro;

  const AppUser({
    required this.id,
    required this.role,
    required this.email,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.major,
    required this.education,
    required this.address,
    required this.addressDetail,
    required this.interests,
    required this.alerts,
    required this.diagnosed,
    required this.currentStep,
    this.intro = '',
  });

  AppUser copyWith({
    UserRole? role,
    String? email,
    String? name,
    int? age,
    String? gender,
    String? phone,
    String? major,
    String? education,
    String? address,
    String? addressDetail,
    List<String>? interests,
    Map<String, bool>? alerts,
    bool? diagnosed,
    int? currentStep,
    String? intro,
  }) {
    return AppUser(
      id: id,
      role: role ?? this.role,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      major: major ?? this.major,
      education: education ?? this.education,
      address: address ?? this.address,
      addressDetail: addressDetail ?? this.addressDetail,
      interests: interests ?? this.interests,
      alerts: alerts ?? this.alerts,
      diagnosed: diagnosed ?? this.diagnosed,
      currentStep: currentStep ?? this.currentStep,
      intro: intro ?? this.intro,
    );
  }
}

// ── STEP 1 · 작은 성취
enum MissionStatus { todo, doing, done }

class Mission {
  final String id;
  final String title;
  final int minutes;
  final String category; // 취업, 돈, 모임, 정책 …
  final MissionStatus status;

  /// 진행 중 미션의 마감일. 미션 수정 화면에서 바꿉니다.
  final DateTime? due;

  const Mission({
    required this.id,
    required this.title,
    required this.minutes,
    required this.category,
    this.status = MissionStatus.todo,
    this.due,
  });

  Mission copyWith({
    MissionStatus? status,
    DateTime? due,
    bool clearDue = false,
  }) {
    return Mission(
      id: id,
      title: title,
      minutes: minutes,
      category: category,
      status: status ?? this.status,
      due: clearDue ? null : (due ?? this.due),
    );
  }
}

/// 완료한 미션 기록 (팀원 프로필 → 활동 자세히 보기)
class DoneMission {
  final int step;
  final String title;
  final String category;
  final int minutes;
  final DateTime doneAt;
  const DoneMission({
    required this.step,
    required this.title,
    required this.category,
    required this.minutes,
    required this.doneAt,
  });
}

// ── 활동 기록 (STAR)
class Star {
  final String s; // 상황
  final String t; // 목표
  final String a; // 행동
  final String r; // 결과
  const Star({
    required this.s,
    required this.t,
    required this.a,
    required this.r,
  });

  Star copyWith({String? s, String? t, String? a, String? r}) =>
      Star(s: s ?? this.s, t: t ?? this.t, a: a ?? this.a, r: r ?? this.r);
}

enum AttachmentType { file, github }

class Attachment {
  final String id;
  final AttachmentType type;
  final String name; // 파일명 또는 저장소 이름
  final String uri; // 파일 경로 또는 https://github.com/...
  final int? size; // bytes (파일만)
  const Attachment({
    required this.id,
    required this.type,
    required this.name,
    required this.uri,
    this.size,
  });
}

class ActivityRecord {
  final String id;
  final int step;
  final String title;
  final String date; // YYYY-MM-DD (예: 2026-10-16)
  final String raw; // 사용자가 쓴 원문
  final Star star; // AI 정리 결과
  final List<Attachment> attachments;

  const ActivityRecord({
    required this.id,
    required this.step,
    required this.title,
    required this.date,
    required this.raw,
    required this.star,
    this.attachments = const [],
  });

  ActivityRecord copyWith({String? title, Star? star}) => ActivityRecord(
    id: id,
    step: step,
    title: title ?? this.title,
    date: date,
    raw: raw,
    star: star ?? this.star,
    attachments: attachments,
  );
}

// ── STEP 2 · 연결 (미니 프로젝트 팀)
class TeamPost {
  final String id;
  final String category;
  final String title;
  final String desc; // 한 줄 소개 (목록 카드에 표시)
  final int current;
  final int max;
  final int weeks;
  final int perWeek;
  final String mode; // 온라인 / 오프라인 / 온·오프라인
  final String leaderId;
  final String postedAgo;

  /// 팀장을 뺀 현재 팀원 id 목록
  final List<String> memberIds;

  /// 프로젝트 설명 (팀 신청 화면에 표시하는 긴 글)
  final String description;

  /// 구하는 팀원 (예: 디자이너, 백엔드, 상관없음)
  final List<String> wantedRoles;

  /// 모집 마감일 (YYYY-MM-DD). 없으면 상시 모집
  final String? deadline;

  /// 연락용 오픈채팅 링크 (선택)
  final String? contactLink;

  const TeamPost({
    required this.id,
    required this.category,
    required this.title,
    required this.desc,
    required this.current,
    required this.max,
    required this.weeks,
    required this.perWeek,
    required this.mode,
    required this.leaderId,
    required this.postedAgo,
    this.memberIds = const [],
    this.description = '',
    this.wantedRoles = const [],
    this.deadline,
    this.contactLink,
  });

  bool get isFull => current >= max;
}

class TeamMember {
  final String id;
  final String name;
  final String intro;
  final List<String> interests;
  final int step;
  final int missionsDone;
  final int records;
  final List<String> badges;

  const TeamMember({
    required this.id,
    required this.name,
    required this.intro,
    required this.interests,
    required this.step,
    required this.missionsDone,
    required this.records,
    this.badges = const [],
  });
}

enum ApplicationStatus { pending, accepted, rejected }

class TeamApplication {
  final String postId;
  final String role;
  final String availableTime;
  final String message;
  final List<String> sharedRecordIds;
  final ApplicationStatus status;
  final DateTime? appliedAt;

  const TeamApplication({
    required this.postId,
    required this.role,
    required this.availableTime,
    required this.message,
    this.sharedRecordIds = const [],
    this.status = ApplicationStatus.pending,
    this.appliedAt,
  });
}

const applicationStatusLabel = {
  ApplicationStatus.pending: '응답 대기',
  ApplicationStatus.accepted: '참여 확정',
  ApplicationStatus.rejected: '아쉽게 마감',
};

// ── STEP 3 · 도전 / STEP 4 · 취업 (공고)
enum OpportunityKind { bootcamp, contest, activity, education, job }

const kindLabel = {
  OpportunityKind.bootcamp: '부트캠프',
  OpportunityKind.contest: '공모전',
  OpportunityKind.activity: '대외활동',
  OpportunityKind.education: '교육',
  OpportunityKind.job: '채용',
};

class Opportunity {
  final String id;
  final int step; // 3 또는 4
  final OpportunityKind kind;
  final String field; // 직무·분야
  final String title;
  final String org;
  final String region;
  final int dday;
  final String? period;
  // STEP 4 (채용) 전용
  final String? employment; // 정규직 / 계약직 / 인턴
  final String? career; // 신입 / 경력무관

  const Opportunity({
    required this.id,
    required this.step,
    required this.kind,
    required this.field,
    required this.title,
    required this.org,
    required this.region,
    required this.dday,
    this.period,
    this.employment,
    this.career,
  });
}

/// 취업 지원 진행 단계 (지원현황 화면)
enum ApplyStage {
  applied('지원 완료'),
  document('서류 심사'),
  interview('면접'),
  passed('최종 합격'),
  failed('불합격');

  const ApplyStage(this.label);
  final String label;

  /// 진행 중(합격·불합격 전) 단계인지
  bool get inProgress => this != passed && this != failed;
}

/// 활동 스크랩 + 지원 여부 (취업 지원 현황)
class Scrap {
  final String opportunityId;
  final bool applied;
  final DateTime scrappedAt;

  /// 지원한 날짜 (applied 일 때만)
  final DateTime? appliedAt;

  /// 지원 진행 단계 (applied 일 때만)
  final ApplyStage? stage;

  /// 지원현황 메모 (면접 일정 등)
  final String memo;

  /// 스크랩 탭에 보이는지 (북마크 상태).
  /// 지원한 공고는 스크랩을 지워도 지원현황에 남도록, 지우지 않고 false 로만 바꿉니다.
  final bool bookmarked;

  const Scrap({
    required this.opportunityId,
    this.applied = false,
    required this.scrappedAt,
    this.appliedAt,
    this.stage,
    this.memo = '',
    this.bookmarked = true,
  });

  Scrap copyWith({
    bool? applied,
    DateTime? appliedAt,
    ApplyStage? stage,
    String? memo,
    bool? bookmarked,
    bool clearApply = false,
  }) => Scrap(
    opportunityId: opportunityId,
    applied: applied ?? this.applied,
    scrappedAt: scrappedAt,
    appliedAt: clearApply ? null : (appliedAt ?? this.appliedAt),
    stage: clearApply ? null : (stage ?? this.stage),
    memo: memo ?? this.memo,
    bookmarked: bookmarked ?? this.bookmarked,
  );
}

// ── 기관 프로그램 등록
class Program {
  final String id;
  final int step; // 3 또는 4
  final OpportunityKind kind;
  final String title;
  final String org;
  final String region;
  final String capacity;
  final String deadline;
  final String startDate;
  final String endDate;
  final String target;
  final String desc;
  final String link;

  const Program({
    required this.id,
    required this.step,
    required this.kind,
    required this.title,
    required this.org,
    required this.region,
    required this.capacity,
    required this.deadline,
    required this.startDate,
    required this.endDate,
    required this.target,
    required this.desc,
    required this.link,
  });
}

// ── 알림
/// 알림을 눌렀을 때 가는 곳
///   deadline 그룹(마감 임박) → 홈
///   step == 1 → STEP 1 화면
///   그 밖 → programId 의 프로그램 상세
class Notice {
  final String id;
  final String group; // 'deadline' | 'new'
  final String category; // 정책, 미션, 교육 …
  final String title;
  final String meta;
  final int? dday;
  final bool read;

  /// STEP 관련 알림이면 단계 (1 이면 STEP 1 화면으로 이동)
  final int? step;

  /// 상세 화면으로 갈 프로그램 id (공고 id 또는 온통청년 정책번호)
  final String? programId;

  const Notice({
    required this.id,
    required this.group,
    required this.category,
    required this.title,
    required this.meta,
    this.dday,
    this.read = false,
    this.step,
    this.programId,
  });

  Notice markRead() => Notice(
    id: id,
    group: group,
    category: category,
    title: title,
    meta: meta,
    dday: dday,
    read: true,
    step: step,
    programId: programId,
  );
}

// ── 프로그램 상세 (온통청년 → 한걸음 '프로그램' 테이블 v3)
// hangeoreum_data/programs_ontong_v3.json 의 programs[] 한 건과 같은 모양입니다. (hangeoreum_data/README.md '필드 사전' 참고)
// 규칙: 값이 없으면 null, 날짜는 'YYYY-MM-DD', 자격 조건 배열이 [] 이면 '제한 없음'.
// 앱 화면에 안 쓰는 v3 필드(orgCodes, basicPlan, categoriesRaw, subCategoriesRaw, ageLimitYnRaw)는 읽지 않습니다.

/// 시도 코드 2자리 → 짧은 이름 (강원·전북은 특별자치도 전환 전후 코드 모두)
const sidoNames = {
  '11': '서울', '26': '부산', '27': '대구', '28': '인천', '29': '광주', '30': '대전', '31': '울산', '36': '세종',
  '41': '경기', '42': '강원', '43': '충북', '44': '충남', '45': '전북', '46': '전남', '47': '경북', '48': '경남',
  '50': '제주', '51': '강원', '52': '전북',
};

/// 주소가 '경상북도 …' 처럼 긴 이름으로 시작하는 시도
const _sidoLongNames = {'충북': '충청북도', '충남': '충청남도', '전북': '전라북도', '전남': '전라남도', '경북': '경상북도', '경남': '경상남도'};

List<String> _strList(dynamic v) => v is List ? [for (final x in v) if (x != null) x.toString()] : const [];
String? _nz(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 신청기간 한 구간 (v3 applyPeriods 의 원소)
class ApplyPeriod {
  final String start; // YYYY-MM-DD
  final String end;
  const ApplyPeriod(this.start, this.end);
}

class ProgramDetail {
  /// 앱 안에서 쓰는 id. 온통청년 정책은 정책번호(originalId)와 같음
  final String id;

  // 식별
  final String source; // 'API' / 'MOCK' / '기관'
  final String sourceName; // '온통청년' 등 — 화면에 출처로 표시
  final String? originalId; // 정책번호
  final String? firstRegistered; // 'YYYY-MM-DD HH:MM:SS'
  final String? lastModified;

  // 정책 내용
  final String name;
  final String? description; // 정책 설명
  final String? benefit; // 지원 내용
  final String? providerGroup; // 중앙부처 / 지자체
  final String? provisionMethod; // 프로그램, 보조금, 바우처 …

  // 기관
  final String? organization; // 화면 표시용 (운영기관, 없으면 주관기관)
  final String? organizationRole; // 운영기관 / 주관기관
  final String? operatingOrg;
  final String? supervisingOrg;
  final String? registeringOrg;
  final String? regionTopOrg;

  // 분류
  final String? category;
  final List<String> categories;
  final String? subCategory;
  final List<String> subCategories;
  final List<String> keywords;

  // 지역
  final bool isNationwide;
  final List<String> regionSidoCodes;
  final List<String> regionZipCodes;

  // 자격 (null·[] = 제한 없음)
  final int? minAge;
  final int? maxAge;
  final List<String> jobConditions;
  final List<String> educationConditions;
  final List<String> majorConditions;
  final List<String> specialConditions;
  final String? marriageCondition;
  final String? incomeConditionType; // 무관 / 연소득 / 기타
  final int? incomeMin; // 만 원
  final int? incomeMax; // 만 원
  final String? incomeConditionText;
  final String? extraEligibility;
  final String? excludedTargets;

  // 모집 규모·인기도
  final bool? isFirstComeFirstServed;
  final int? supportCount;
  final int? viewCount;

  // 기간
  final String? applyPeriodType; // 특정기간 / 상시 / 마감
  final List<ApplyPeriod> applyPeriods;
  final String? applyStart; // 현재 또는 다음 신청기간
  final String? applyEnd;
  final String? bizPeriodType;
  final String? bizStart;
  final String? bizEnd;
  final String? bizPeriodText;

  // 신청
  final String? applyUrl; // 바로 신청 링크 (있을 때만)
  final List<String> refUrls; // 참고 링크 (최대 2개)
  final String? applyMethod;
  final String? screeningMethod;
  final String? documents;
  final String? etc;

  // 한걸음 서비스용 (LLM 분류 단계에서 채움)
  final int? step;
  final String? difficulty;
  final int? durationMinutes;
  final double? aiConfidence; // 0~1
  final String? reviewStatus; // 검수 대기 / 공개 / 반려
  final bool closed;
  final String? closedReason;

  const ProgramDetail({
    required this.id,
    this.source = 'API',
    this.sourceName = '온통청년',
    this.originalId,
    this.firstRegistered,
    this.lastModified,
    required this.name,
    this.description,
    this.benefit,
    this.providerGroup,
    this.provisionMethod,
    this.organization,
    this.organizationRole,
    this.operatingOrg,
    this.supervisingOrg,
    this.registeringOrg,
    this.regionTopOrg,
    this.category,
    this.categories = const [],
    this.subCategory,
    this.subCategories = const [],
    this.keywords = const [],
    this.isNationwide = false,
    this.regionSidoCodes = const [],
    this.regionZipCodes = const [],
    this.minAge,
    this.maxAge,
    this.jobConditions = const [],
    this.educationConditions = const [],
    this.majorConditions = const [],
    this.specialConditions = const [],
    this.marriageCondition,
    this.incomeConditionType,
    this.incomeMin,
    this.incomeMax,
    this.incomeConditionText,
    this.extraEligibility,
    this.excludedTargets,
    this.isFirstComeFirstServed,
    this.supportCount,
    this.viewCount,
    this.applyPeriodType,
    this.applyPeriods = const [],
    this.applyStart,
    this.applyEnd,
    this.bizPeriodType,
    this.bizStart,
    this.bizEnd,
    this.bizPeriodText,
    this.applyUrl,
    this.refUrls = const [],
    this.applyMethod,
    this.screeningMethod,
    this.documents,
    this.etc,
    this.step,
    this.difficulty,
    this.durationMinutes,
    this.aiConfidence,
    this.reviewStatus,
    this.closed = false,
    this.closedReason,
  });

  /// programs_ontong_v3.json 의 programs[] 한 건 → ProgramDetail (서버 응답도 같은 모양이면 그대로 사용)
  factory ProgramDetail.fromJson(Map<String, dynamic> j) {
    String? str(String k) => _nz(j[k]?.toString());
    int? integer(String k) => (j[k] as num?)?.toInt();
    final periods = j['applyPeriods'];
    return ProgramDetail(
      id: str('id') ?? str('originalId') ?? '',
      source: str('source') ?? 'API',
      sourceName: str('sourceName') ?? '온통청년',
      originalId: str('originalId'),
      firstRegistered: str('firstRegistered'),
      lastModified: str('lastModified'),
      name: str('name') ?? '(이름 없음)',
      description: str('description'),
      benefit: str('benefit'),
      providerGroup: str('providerGroup'),
      provisionMethod: str('provisionMethod'),
      organization: str('organization'),
      organizationRole: str('organizationRole'),
      operatingOrg: str('operatingOrg'),
      supervisingOrg: str('supervisingOrg'),
      registeringOrg: str('registeringOrg'),
      regionTopOrg: str('regionTopOrg'),
      category: str('category'),
      categories: _strList(j['categories']),
      subCategory: str('subCategory'),
      subCategories: _strList(j['subCategories']),
      keywords: _strList(j['keywords']),
      isNationwide: j['isNationwide'] == true,
      regionSidoCodes: _strList(j['regionSidoCodes']),
      regionZipCodes: _strList(j['regionZipCodes']),
      minAge: integer('minAge'),
      maxAge: integer('maxAge'),
      jobConditions: _strList(j['jobConditions']),
      educationConditions: _strList(j['educationConditions']),
      majorConditions: _strList(j['majorConditions']),
      specialConditions: _strList(j['specialConditions']),
      marriageCondition: str('marriageCondition'),
      incomeConditionType: str('incomeConditionType'),
      incomeMin: integer('incomeMin'),
      incomeMax: integer('incomeMax'),
      incomeConditionText: str('incomeConditionText'),
      extraEligibility: str('extraEligibility'),
      excludedTargets: str('excludedTargets'),
      isFirstComeFirstServed: j['isFirstComeFirstServed'] as bool?,
      supportCount: integer('supportCount'),
      viewCount: integer('viewCount'),
      applyPeriodType: str('applyPeriodType'),
      applyPeriods: [
        if (periods is List)
          for (final x in periods)
            if (x is Map && x['start'] != null && x['end'] != null) ApplyPeriod('${x['start']}', '${x['end']}'),
      ],
      applyStart: str('applyStart'),
      applyEnd: str('applyEnd'),
      bizPeriodType: str('bizPeriodType'),
      bizStart: str('bizStart'),
      bizEnd: str('bizEnd'),
      bizPeriodText: str('bizPeriodText'),
      applyUrl: str('applyUrl'),
      refUrls: _strList(j['refUrls']),
      applyMethod: str('applyMethod'),
      screeningMethod: str('screeningMethod'),
      documents: str('documents'),
      etc: str('etc'),
      step: integer('step'),
      difficulty: str('difficulty'),
      durationMinutes: integer('durationMinutes'),
      aiConfidence: (j['aiConfidence'] as num?)?.toDouble(),
      reviewStatus: str('reviewStatus'),
      closed: j['closed'] == true,
      closedReason: str('closedReason'),
    );
  }

  /// 상세 데이터가 아직 없는 공고 → 카드 정보로만 채운 상세 (STEP 4 채용은 워크넷 API 연결 전)
  factory ProgramDetail.fromOpportunity(Opportunity o) {
    final today = DateTime.now();
    return ProgramDetail(
      id: o.id,
      source: 'MOCK',
      sourceName: '한걸음 샘플',
      name: o.title,
      organization: o.org,
      category: kindLabel[o.kind],
      subCategory: o.field,
      subCategories: [o.field],
      provisionMethod: o.employment,
      regionTopOrg: o.region,
      applyPeriodType: '특정기간',
      applyEnd: _ymd(DateTime(today.year, today.month, today.day + o.dday)),
      bizPeriodText: o.period == null ? null : '진행 ${o.period}',
      extraEligibility: o.career == null ? null : '경력 조건: ${o.career}',
    );
  }

  /// 기관이 등록한 프로그램 → 상세 (검수 전)
  factory ProgramDetail.fromRegistered(Program p) {
    final eligibility = [
      ?_nz(p.target),
      if (_nz(p.capacity) case final c?) '모집 인원 $c',
    ].join('\n');
    final link = _nz(p.link);
    return ProgramDetail(
      id: p.id,
      source: '기관',
      sourceName: '기관 등록',
      name: p.title,
      organization: _nz(p.org),
      category: kindLabel[p.kind],
      description: _nz(p.desc),
      regionTopOrg: _nz(p.region),
      applyPeriodType: '특정기간',
      applyEnd: _nz(p.deadline),
      bizPeriodType: '특정기간',
      bizStart: _nz(p.startDate),
      bizEnd: _nz(p.endDate),
      extraEligibility: _nz(eligibility),
      applyUrl: link,
      refUrls: [?link],
      step: p.step,
      reviewStatus: '검수 대기',
    );
  }

  /// 설명과 지원 내용이 같은 정책이 많아서(원본 특성), 같으면 지원 내용은 숨김
  bool get benefitDiffers => benefit != null && benefit != description;

  /// 원문 링크 (신청 링크가 없으면 참고 링크)
  String? get linkUrl => applyUrl ?? (refUrls.isEmpty ? null : refUrls.first);

  DateTime? get applyStartDate => applyStart == null ? null : DateTime.tryParse(applyStart!);
  DateTime? get applyEndDate => applyEnd == null ? null : DateTime.tryParse(applyEnd!);

  /// 오늘 기준 마감 여부. 변환일 기준 closed 와, 그 뒤에 지난 신청 마감일을 함께 봄
  bool isClosedOn(DateTime today) {
    if (closed || applyPeriodType == '마감') return true;
    final end = applyEndDate;
    return applyPeriodType == '특정기간' && end != null && end.isBefore(today);
  }

  /// 신청 시작 전인지
  bool isUpcomingOn(DateTime today) {
    final start = applyStartDate;
    return start != null && start.isAfter(today);
  }

  /// 신청 마감까지 남은 날 (마감일 없으면 null)
  int? ddayOn(DateTime today) => applyEndDate?.difference(today).inDays;

  List<String> get regionNames => {
        for (final c in regionSidoCodes)
          ?sidoNames[c],
      }.toList();

  String get regionLabel {
    if (isNationwide) return '전국';
    final names = regionNames;
    if (names.isEmpty) return regionTopOrg ?? '정보 없음';
    if (names.length <= 3) return names.join(' · ');
    return '${names.take(2).join(' · ')} 외 ${names.length - 2}곳';
  }

  String get ageLabel {
    final a = minAge, b = maxAge;
    if (a != null && b != null) return '만 $a~$b세';
    if (a != null) return '만 $a세 이상';
    if (b != null) return '만 $b세 이하';
    return '제한 없음';
  }

  bool ageMatches(int age) {
    final a = minAge, b = maxAge;
    return (a == null || age >= a) && (b == null || age <= b);
  }

  /// 주소('서울특별시 마포구 …')가 지원 지역에 드는지. 지역 정보가 없으면 null (판단 불가)
  bool? regionMatches(String address) {
    if (isNationwide) return true;
    final names = regionNames;
    if (names.isEmpty) return null;
    return names.any((n) => address.startsWith(n) || address.startsWith(_sidoLongNames[n] ?? n));
  }

  /// 한걸음 분류 정보(STEP·난이도·소요시간·AI 확신도)가 있는지
  bool get hasServiceInfo => step != null || difficulty != null || durationMinutes != null || aiConfidence != null;
}
