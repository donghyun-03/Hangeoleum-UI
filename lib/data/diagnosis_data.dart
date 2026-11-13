// 니즈 진단 질문 목록
// 질문 추가·순서 변경은 kDiagnosisQuestions만 수정하면 됩니다.
// slotKey 변경 시 diagnosis_profile.dart의 getter·라벨도 함께 수정해야 합니다.

class SlotQuestion {
  final String slotKey;
  final String questionText;
  final List<String> options;
  final String? introText;
  final Map<String, String> responseMessages;

  /// 단일 선행 조건 (기존 호환용)
  final String? dependsOnSlot;
  final List<String> dependsOnValues;

  /// 복합 선행 조건 (여러 슬롯의 조건을 AND로 모두 만족해야 노출)
  final Map<String, List<String>> conditions;

  const SlotQuestion({
    required this.slotKey,
    required this.questionText,
    required this.options,
    this.introText,
    this.responseMessages = const {},
    this.dependsOnSlot,
    this.dependsOnValues = const [],
    this.conditions = const {},
  });

  String? getResponseMessage(String answer) => responseMessages[answer];

  bool isVisible(Map<String, String> answers) {
    if (dependsOnSlot != null &&
        !dependsOnValues.contains(answers[dependsOnSlot])) {
      return false;
    }
    for (final entry in conditions.entries) {
      if (!entry.value.contains(answers[entry.key])) {
        return false;
      }
    }
    return true;
  }
}

const List<SlotQuestion> kDiagnosisQuestions = [
  // 1. 현재 상태
  SlotQuestion(
    slotKey: 'current_status',
    questionText: '요즘 하루는 어떻게 보내고 있나요? 🙂',
    options: [
      '일상 리듬이 무너져 대부분 집에서 보내고 있어요.',
      '다른 사람들과 교류할 기회가 많지 않아요.',
      '취업을 위해 교육이나 공모전을 알아보고 있어요.',
      '이력서나 포트폴리오를 준비하며 취업 준비 중이에요.',
      '잘 모르겠어요.',
    ],
    responseMessages: {
      '일상 리듬이 무너져 대부분 집에서 보내고 있어요.':
          '그렇군요 😌 생활 패턴을 다시 잡는 게 쉽지 않죠.',
      '다른 사람들과 교류할 기회가 많지 않아요.':
          '그렇군요 😌 혼자 보내는 시간이 길어지면 더 조심스러워지죠.',
      '취업을 위해 교육이나 공모전을 알아보고 있어요.':
          '이미 스스로 움직이고 계셨네요! 😮',
      '이력서나 포트폴리오를 준비하며 취업 준비 중이에요.':
          '차근차근 실전 준비 중이셨군요! 😮',
      '잘 모르겠어요.':
          '괜찮아요 😊 아직 명확하지 않을 수도 있죠.',
    },
  ),

  // 2. 가장 먼저 도전하고 싶은 것
  SlotQuestion(
    slotKey: 'primary_goal',
    questionText: '지금 가장 먼저 도전해보고 싶은 것은 무엇인가요?',
    options: ['생활 리듬 되찾기', '사람 만나기', '경험 쌓기', '바로 취업 준비'],
  ),

  // 3. 하루 투자 시간
  SlotQuestion(
    slotKey: 'time_commitment',
    questionText: '하루 중 자신을 위해 어느 정도 시간을 낼 수 있을까요?',
    options: ['10분 정도', '30분 정도', '1시간 이상'],
  ),

  // 4. 관심 분야
  SlotQuestion(
    slotKey: 'interest',
    questionText: '조금이라도 관심 가는 분야는요?',
    options: ['IT·데이터', '디자인·영상', '사무·행정', '아직 잘 모르겠어요'],
  ),

  // 5. 희망 기업 유형 및 규모 통합 (스타트업·중소·중견·대기업·공기업 모두 구분)
  SlotQuestion(
    slotKey: 'company_preference',
    questionText: '앞으로 취업을 생각한다면 어떤 기업에 관심이 있나요? 🧐',
    options: [
      '스타트업',
      '중소기업',
      '중견기업',
      '대기업',
      '공기업·공공기관',
      '아직 고민 중이에요',
    ],
  ),

  // 6-A. 목표 기업 + 직무 유무 — 관심 분야를 골랐고, 기업 유형도 정한 경우
  SlotQuestion(
    slotKey: 'target_clarity',
    questionText: '마음에 두고 있는 특정 기업이나 구체적인 직무가 있나요?',
    options: [
      '목표 기업과 직무 모두 있어요',
      '목표 기업만 정해뒀어요',
      '직무만 정해뒀어요',
      '아직 찾아가는 중이에요',
    ],
    conditions: {
      'interest': ['IT·데이터', '디자인·영상', '사무·행정'],
      'company_preference': ['스타트업', '중소기업', '중견기업', '대기업', '공기업·공공기관'],
    },
    responseMessages: {
      '목표 기업과 직무 모두 있어요': '오, 목표가 명확하시군요! 😮 방향에 맞춰 바로 실행해 보면 좋겠네요.',
      '직무만 정해뒀어요': '좋아요 😊 직무 방향이 잡혀 있으면 준비가 훨씬 수월하죠.',
      '목표 기업만 정해뒀어요': '좋아요 😊 목표 기업이 잡혀 있으면 준비가 훨씬 수월하죠.',
      '아직 찾아가는 중이에요': '괜찮아요 😊 작은 경험부터 해보면서 찾아가면 돼요.',
    },
  ),

  // 6-B. 특정 희망 기업 유무만 질문 — 관심 분야는 모르지만, 기업 유형은 고른 경우 ('아직 고민 중이에요' 제외)
  SlotQuestion(
    slotKey: 'target_company_only',
    questionText: '관심 분야는 아직 고민 중이시더라도, 혹시 마음에 두고 있는 특정 기업이 있나요?',
    options: ['있어요', '아직 없어요'],
    conditions: {
      'interest': ['아직 잘 모르겠어요'],
      'company_preference': ['스타트업', '중소기업', '중견기업', '대기업', '공기업·공공기관'],
    },
    responseMessages: {
      '있어요': '오, 가고 싶은 기업이 있으시군요! 😮 그 기업에 맞춰 직무와 준비 방향을 함께 찾아보면 좋겠네요.',
      '아직 없어요': '괜찮아요 😊 작은 경험부터 해보면서 차근차근 찾아가면 돼요.',
    },
  ),

  // 6-C. 희망 직무 유무만 질문 — 관심 분야는 골랐지만, 기업은 '아직 고민 중이에요'인 경우
  SlotQuestion(
    slotKey: 'desired_job_only',
    questionText: '기업 규모는 아직 고민 중이시군요! 그렇다면 해보고 싶은 구체적인 직무는 있나요? 😊',
    options: ['있어요', '아직 없어요'],
    conditions: {
      'interest': ['IT·데이터', '디자인·영상', '사무·행정'],
      'company_preference': ['아직 고민 중이에요'],
    },
    responseMessages: {
      '있어요': '좋아요 😊 직무 방향이 잡혀 있으면 어울리는 기업을 찾기가 훨씬 수월하죠.',
      '아직 없어요': '괜찮아요 😊 관심 분야 안에서 작은 경험부터 해보며 찾아가면 돼요.',
    },
  ),

  // 7. 포트폴리오(활동 경험) 및 어학 성적 보유 여부 통합
  SlotQuestion(
    slotKey: 'readiness_assets',
    questionText: '공모전·프로젝트 같은 포트폴리오(활동 기록)나 어학 성적이 있나요?',
    options: [
      '포트폴리오와 어학 성적 모두 있어요',
      '포트폴리오만 있어요',
      '어학 성적만 있어요',
      '아직 둘 다 없어요',
    ],
    responseMessages: {
      '포트폴리오와 어학 성적 모두 있어요': '이미 탄탄하게 준비해 두셨네요! 😮 바로 실전에 활용할 수 있겠어요.',
      '포트폴리오만 있어요': '실전 경험이 있으시군요! 😮 그 기록들을 잘 정리해 두면 큰 무기가 돼요.',
      '어학 성적만 있어요': '기본기가 준비되어 있으시네요! 😊 이제 직무 경험을 하나씩 채워보면 좋겠어요.',
      '아직 둘 다 없어요': '그렇군요 😊 지금부터 작은 경험부터 하나씩 쌓아가면 돼요.',
    },
  ),
];

List<SlotQuestion> visibleQuestions(Map<String, String> answers) =>
    kDiagnosisQuestions.where((q) => q.isVisible(answers)).toList();