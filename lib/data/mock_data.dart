// 개발용 샘플 데이터 (화면 흐름도 시안 내용 기준). 실제 데이터는 API 연결 후 교체합니다.
import '../models/models.dart';

const interestOptions = ['IT·데이터', '디자인·영상', '사무·행정', '마케팅·기획', '서비스·판매', '아직 잘 모르겠어요'];

const stepInfo = {
  1: (title: '작은 성취', desc: '하고 싶은 미션을 골라 시작해 보세요.'),
  2: (title: '연결', desc: '함께할 프로젝트를 찾아보세요.'),
  3: (title: '도전', desc: '공식 프로그램을 골라 도전해 보세요.'),
  4: (title: '취업', desc: '쌓은 경험으로 지원해 보세요.'),
};

const mockUser = AppUser(
  id: 'u1',
  role: UserRole.youth,
  email: 'jieun@email.com',
  name: '김지은',
  age: 26,
  gender: 'female',
  phone: '010-1234-5678',
  major: '경영학부',
  education: '대학교 졸업',
  address: '서울특별시 마포구 월드컵북로',
  addressDetail: '101동 202호',
  interests: ['IT·데이터', '사무·행정'],
  alerts: {'policy': true, 'camp': true, 'saving': false, 'project': true},
  diagnosed: true,
  currentStep: 1,
);

final mockMissions = <Mission>[
  const Mission(id: 'm1', title: '취업 유튜브 하나 보기', minutes: 10, category: '취업', status: MissionStatus.done),
  Mission(id: 'm2', title: '청년 적금 알아보기', minutes: 5, category: '돈', status: MissionStatus.doing, due: DateTime(2026, 10, 18)),
  Mission(id: 'm3', title: '동네 청년센터 동아리 찾아보기', minutes: 20, category: '모임', status: MissionStatus.doing, due: DateTime(2026, 10, 20)),
  const Mission(id: 'm4', title: '관심 기업 공고 하나 읽어보기', minutes: 10, category: '취업'),
  const Mission(id: 'm5', title: '청년 지원 정책 하나 읽어보기', minutes: 10, category: '정책'),
  const Mission(id: 'm6', title: '청년센터 프로그램 둘러보기', minutes: 15, category: '모임'),
  const Mission(id: 'm7', title: '매일 정해진 시간에 일어나기', minutes: 5, category: '생활'),
];

const mockRecords = <ActivityRecord>[
  ActivityRecord(
    id: 'r1',
    step: 1,
    title: '청년센터 독서 동아리 참여',
    date: '2026-02-10',
    raw: '',
    star: Star(
      s: '쉬는 동안 사람들과 만날 기회가 거의 없었음',
      t: '사람들과 정기적으로 교류하는 경험 만들기',
      a: '청년센터 독서 동아리에 가입해 4주간 매주 참여, 마지막 주에 읽은 책을 10분간 발표',
      r: "발표 후 참가자들의 질문에 답하며 발표 경험을 얻음 → 자기소개서 '소통·발표 경험'으로 활용",
    ),
  ),
  ActivityRecord(
    id: 'r2',
    step: 1,
    title: '청년센터 엑셀 워크숍 듣기',
    date: '2026-02-16',
    raw: '',
    star: Star(
      s: '공백기 중 실무 데이터 활용 역량이 부족하다고 느낌',
      t: '업무에 바로 쓸 수 있는 엑셀 역량을 목표로 설정',
      a: '청년센터 워크숍 3회 이수, 함수·피벗을 익혀 가계부 자동 정리 시트를 직접 제작',
      r: "매달 손으로 하던 지출 정리를 자동화 → 자기소개서 '문제 해결 경험'으로 활용",
    ),
    attachments: [
      Attachment(id: 'a1', type: AttachmentType.github, name: 'jieun/excel-budget', uri: 'https://github.com/jieun/excel-budget'),
    ],
  ),
];

const mockMembers = <TeamMember>[
  TeamMember(
    id: 'tm1',
    name: '서연',
    intro: '엑셀로 반복 업무 줄이는 걸 좋아해요. 같이 꾸준히 해볼 분 찾아요!',
    interests: ['IT·데이터', '사무·행정'],
    step: 2,
    missionsDone: 18,
    records: 9,
    badges: ['꾸준함 4주', '첫 발표'],
  ),
  TeamMember(
    id: 'tm2',
    name: '민준',
    intro: '공모전 처음 도전해 봐요. 기획 위주로 맡을 수 있어요.',
    interests: ['마케팅·기획'],
    step: 2,
    missionsDone: 11,
    records: 5,
    badges: ['첫 팀 프로젝트'],
  ),
  TeamMember(
    id: 'tm3',
    name: '하은',
    intro: '인스타 콘텐츠 만드는 거 좋아해요.',
    interests: ['디자인·영상', '마케팅·기획'],
    step: 3,
    missionsDone: 24,
    records: 14,
    badges: ['꾸준함 8주'],
  ),
  TeamMember(id: 'tm4', name: '도윤', intro: '포트폴리오 같이 다듬어요.', interests: ['디자인·영상'], step: 2, missionsDone: 9, records: 3),
  TeamMember(id: 'tm5', name: '지우', intro: '피그마로 화면 그리는 걸 좋아해요.', interests: ['디자인·영상'], step: 2, missionsDone: 12, records: 6, badges: ['첫 발표']),
  TeamMember(id: 'tm6', name: '현우', intro: '파이썬 조금 할 줄 알아요. 데이터 정리 맡을게요.', interests: ['IT·데이터'], step: 3, missionsDone: 20, records: 11),
];

const mockTeamPosts = <TeamPost>[
  TeamPost(
    id: 'p1',
    category: '데이터·엑셀',
    title: '엑셀로 가계부 자동화 시트 같이 만들어요',
    desc: '엑셀 처음이어도 괜찮아요, 같이 공부하면서 만들어요',
    current: 1,
    max: 3,
    weeks: 4,
    perWeek: 2,
    mode: '온라인',
    leaderId: 'tm1',
    postedAgo: '2시간 전',
    description: '매달 손으로 하던 지출 정리를 엑셀로 자동화해 보려고 해요.\n'
        '1~2주차에는 함수·피벗을 같이 익히고, 3~4주차에는 각자 가계부 시트를 완성해서 서로 피드백해요.\n'
        '결과물은 포트폴리오와 활동 기록에 넣을 수 있게 정리할 예정이에요.',
    wantedRoles: ['엑셀·데이터', '기획', '상관없음'],
    deadline: '2026-10-25',
  ),
  TeamPost(
    id: 'p2',
    category: '공모전',
    title: '청년 아이디어 공모전 같이 나갈 분',
    desc: '혼자 나가기엔 막막해서 팀을 구해요. 발표 준비까지 같이 해봐요',
    current: 2,
    max: 3,
    weeks: 6,
    perWeek: 1,
    mode: '온라인',
    leaderId: 'tm2',
    postedAgo: '5시간 전',
    memberIds: ['tm6'],
    description: '청년 정책 아이디어 공모전(11월 마감)에 함께 나갈 팀원을 구해요.\n'
        '아이디어는 같이 정하고, 자료 조사 → 기획서 → 발표 자료 순서로 진행할 거예요.\n'
        '디자인을 맡아 줄 분이 있으면 정말 좋겠어요!',
    wantedRoles: ['디자이너', '발표'],
    deadline: '2026-10-22',
  ),
  TeamPost(
    id: 'p3',
    category: '마케팅·기획',
    title: '인스타 계정 하나 같이 운영해 봐요',
    desc: '포트폴리오에 넣을 결과물을 같이 만들어요',
    current: 1,
    max: 3,
    weeks: 4,
    perWeek: 2,
    mode: '온·오프라인',
    leaderId: 'tm3',
    postedAgo: '1일 전',
    description: '동네 청년 활동을 소개하는 인스타 계정을 4주 동안 운영해 봐요.\n'
        '콘텐츠 기획, 카드뉴스 제작, 업로드·분석까지 나눠서 해요. 마지막 주에는 성과를 정리해요.',
    wantedRoles: ['디자이너', '콘텐츠 기획', '상관없음'],
  ),
  TeamPost(
    id: 'p4',
    category: '디자인',
    title: '포트폴리오 같이 만들어요',
    desc: '피드백 주고받으면서 하나씩 완성해요',
    current: 2,
    max: 3,
    weeks: 4,
    perWeek: 1,
    mode: '온라인',
    leaderId: 'tm4',
    postedAgo: '2일 전',
    memberIds: ['tm5'],
    description: '각자 포트폴리오를 만들되 매주 한 번 모여서 서로 피드백해요.\n'
        '디자인·개발·기획 누구든 괜찮아요. 노션이나 피그마로 완성하는 게 목표예요.',
    wantedRoles: ['상관없음'],
    deadline: '2026-10-30',
  ),
];

const mockOpportunities = <Opportunity>[
  // STEP 3 · 도전
  Opportunity(id: 'o1', step: 3, kind: OpportunityKind.bootcamp, field: '데이터 분석', title: '데이터 분석 입문 부트캠프', org: '서울청년센터', region: '온라인', dday: 5, period: '10.01 - 10.24'),
  Opportunity(id: 'o2', step: 3, kind: OpportunityKind.contest, field: '기획', title: '공공데이터 활용 아이디어 공모전', org: '행정안전부', region: '온라인', dday: 12, period: '10.05 - 10.27'),
  Opportunity(id: 'o3', step: 3, kind: OpportunityKind.activity, field: '데이터', title: '청년 데이터 서포터즈 3기 모집 (전국 대학생·청년 대상 온라인 활동)', org: '청년재단', region: '서울', dday: 20, period: '10.15 - 11.04'),
  Opportunity(id: 'o4', step: 3, kind: OpportunityKind.education, field: '엑셀·파이썬', title: '엑셀·파이썬 기초 과정', org: '고용노동부', region: '서울', dday: 15, period: '10.10 - 10.30'),
  // STEP 4 · 취업
  Opportunity(id: 'o5', step: 4, kind: OpportunityKind.job, field: '데이터 입력', title: '데이터 입력 사원 모집', org: '서울청년센터', region: '서울', dday: 5, employment: '계약직', career: '신입'),
  Opportunity(id: 'o6', step: 4, kind: OpportunityKind.job, field: '사무 보조', title: '사무 보조 (문서·자료 정리)', org: '한빛물류', region: '경기', dday: 9, employment: '정규직', career: '신입'),
  Opportunity(id: 'o7', step: 4, kind: OpportunityKind.job, field: '데이터 관리', title: '청년 데이터 모니터링 요원 (공공데이터 포털 운영 지원 및 품질 점검 업무 담당)', org: '청년재단', region: '서울', dday: 14, employment: '계약직', career: '경력무관'),
  Opportunity(id: 'o8', step: 4, kind: OpportunityKind.job, field: '데이터 검수', title: 'AI 학습용 데이터 검수 담당', org: '가온데이터', region: '서울', dday: 20, employment: '인턴', career: '신입'),
];

final mockScraps = <Scrap>[
  Scrap(opportunityId: 'o5', applied: true, scrappedAt: DateTime(2026, 10, 12), appliedAt: DateTime(2026, 10, 13), stage: ApplyStage.document),
  Scrap(opportunityId: 'o6', applied: true, scrappedAt: DateTime(2026, 10, 8), appliedAt: DateTime(2026, 10, 9), stage: ApplyStage.interview, memo: '10/22(수) 오후 2시 대면 면접'),
  Scrap(opportunityId: 'o7', scrappedAt: DateTime(2026, 10, 14)),
];

const mockNotices = <Notice>[
  Notice(id: 'n1', group: 'deadline', category: '정책', title: '청년도전지원사업 참여자 모집', meta: '서울 · 만 19-34세', dday: 3),
  Notice(id: 'n2', group: 'deadline', category: '적금', title: '청년도약계좌 가입 신청', meta: '만 19-34세 · 소득 조건 충족', dday: 5),
  Notice(id: 'n3', group: 'new', category: '캠프', title: '청년 리더십 캠프 참가자 모집', meta: '서울 · 2박 3일 · 무료'),
  Notice(id: 'n4', group: 'new', category: '정책', title: '청년 월세 지원 신청 안내', meta: '서울 · 만 19-34세'),
  Notice(id: 'n5', group: 'new', category: '적금', title: '청년내일저축계좌 모집', meta: '소득 조건 충족 · 전국', read: true),
  Notice(id: 'n6', group: 'new', category: '정책', title: '청년 면접 수당 신청 안내', meta: '서울 · 만 19-34세', read: true),
  Notice(id: 'n7', group: 'new', category: '캠프', title: '청년 커리어 캠프 참가자 모집', meta: '서울 · 1박 2일 · 무료', read: true),
];

// ── 조회 도우미 (API 연결 시 서버 조회로 교체)
TeamMember? findMember(String id) {
  for (final m in mockMembers) {
    if (m.id == id) return m;
  }
  return null;
}

TeamPost? findTeamPost(String id) {
  for (final p in mockTeamPosts) {
    if (p.id == id) return p;
  }
  return null;
}

Opportunity? findOpportunity(String id) {
  for (final o in mockOpportunities) {
    if (o.id == id) return o;
  }
  return null;
}

// ── 팀원 활동 (팀원 프로필 → 완료한 미션 · 활동 기록)
// 샘플이라 팀원마다 아래 목록을 돌려 쓰며 TeamMember.missionsDone / records 개수만큼 만들어요.
// TODO(API): 팀원 공개 활동 조회로 교체
const _missionPool = [
  (1, '취업 유튜브 하나 보기', '취업', 10),
  (1, '청년 적금 알아보기', '돈', 5),
  (1, '매일 정해진 시간에 일어나기', '생활', 5),
  (1, '동네 청년센터 동아리 찾아보기', '모임', 20),
  (1, '청년 지원 정책 하나 읽어보기', '정책', 10),
  (1, '관심 기업 공고 하나 읽어보기', '취업', 10),
  (2, '미니 프로젝트 첫 회의 참여하기', '연결', 60),
  (2, '팀원에게 맡은 부분 공유하기', '연결', 20),
  (2, '프로젝트 중간 결과물 올리기', '연결', 90),
  (3, '공모전 기획서 초안 쓰기', '도전', 120),
  (3, '부트캠프 1주차 과제 제출', '도전', 90),
  (4, '이력서 한 장 완성하기', '취업', 60),
];

const _recordPool = [
  (
    1,
    '청년센터 독서 동아리 참여',
    Star(
      s: '쉬는 동안 사람들과 만날 기회가 거의 없었음',
      t: '사람들과 정기적으로 교류하는 경험 만들기',
      a: '동아리에 4주간 매주 참여하고 마지막 주에 읽은 책을 10분간 발표',
      r: '발표 경험을 얻음 → 자기소개서 소통 경험으로 활용',
    ),
  ),
  (
    1,
    '아침 7시 기상 2주 지키기',
    Star(
      s: '생활 리듬이 깨져서 오전 시간을 거의 못 씀',
      t: '2주 동안 아침 7시에 일어나기',
      a: '알람을 침대에서 먼 곳에 두고, 일어나면 바로 산책 15분',
      r: '14일 중 12일 성공, 오전에 공부 시간 1시간 확보',
    ),
  ),
  (
    2,
    '엑셀 가계부 프로젝트 함수 담당',
    Star(
      s: '팀 프로젝트에서 반복 계산이 많아 작업이 느렸음',
      t: '자동 계산 시트를 만들어 팀 작업 시간 줄이기',
      a: 'SUMIFS·피벗으로 카테고리별 합계 시트 제작, 팀원에게 사용법 공유',
      r: '정리 시간이 주 2시간 → 20분으로 줄어듦',
    ),
  ),
  (
    2,
    '공모전 팀 자료 조사 맡기',
    Star(
      s: '아이디어는 있었지만 근거 자료가 부족했음',
      t: '공공데이터로 아이디어 근거 만들기',
      a: '공공데이터포털에서 청년 통계 3종을 찾아 그래프로 정리',
      r: '기획서 근거 페이지 완성, 팀원 피드백으로 발표에 그대로 사용',
    ),
  ),
  (
    3,
    '데이터 분석 부트캠프 1주차',
    Star(
      s: '데이터 분석을 처음 배우는 상황',
      t: '1주차 과제(데이터 정제) 기한 내 제출',
      a: '강의 복습 후 결측치 처리 코드를 직접 작성, 질문 게시판 활용',
      r: '과제 통과, 강사 피드백으로 코드 개선',
    ),
  ),
];

List<DoneMission> mockDoneMissionsOf(TeamMember m) {
  final base = DateTime(2026, 10, 18);
  return [
    for (var i = 0; i < m.missionsDone; i++)
      if (_missionPool[i % _missionPool.length] case (final step, final title, final category, final minutes))
        DoneMission(
          step: step > m.step ? m.step : step, // 아직 안 간 STEP 의 미션은 현재 STEP 으로
          title: title,
          category: category,
          minutes: minutes,
          doneAt: base.subtract(Duration(days: i * 2)),
        ),
  ];
}

List<ActivityRecord> mockRecordsOf(TeamMember m) {
  final base = DateTime(2026, 10, 17);
  String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return [
    for (var i = 0; i < m.records; i++)
      if (_recordPool[i % _recordPool.length] case (final step, final title, final star))
        ActivityRecord(
          id: '${m.id}-r$i',
          step: step > m.step ? m.step : step,
          title: title,
          date: fmt(base.subtract(Duration(days: i * 3))),
          raw: '',
          star: star,
        ),
  ];
}
