// 앱 전역 상태 (provider 의 ChangeNotifier). 지금은 메모리에만 저장되어 앱을 끄면 초기화됩니다.
// 기능별로 섹션을 나눠 두었습니다. 자기 기능 섹션만 수정하면 병합 충돌이 줄어듭니다.
//
// 화면에서 쓰는 법
//   읽기(값이 바뀌면 다시 그림):  final state = context.watch<AppState>();
//   액션 호출(버튼 onPressed 등): context.read<AppState>().toggleScrap(id);
//
// API 연결 시: 각 액션 안에서 서버를 호출하고 결과로 값을 바꾼 뒤 notifyListeners() 하면 됩니다.
import 'package:flutter/foundation.dart';

import '../data/diagnosis_data.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../models/diagnosis_profile.dart';
import '../data/user_profile_store.dart';
import '../services/llm_client.dart';
import '../services/readiness_ai.dart';
import '../services/readiness_service.dart';
import '../services/recommend_ai.dart';
import '../data/home_recommendation_data.dart';

class AppState extends ChangeNotifier {
  // ───────────────────────── 사용자 / 인증
  AppUser _user = mockUser;
  AppUser get user => _user;
  bool get isInstitution => _user.role == UserRole.institution;

  void updateUser(AppUser Function(AppUser u) change) {
    _user = change(_user);
    notifyListeners();
  }

  /// 홈에서 최소 활동 수를 완료한 뒤 다음 STEP으로 이동합니다.
  ///
  /// 완료 수는 홈에서 각 STEP 활동의 done 상태로 집계합니다.
  /// 연속 클릭으로 여러 단계를 건너뛰지 않도록 현재 STEP을 확인합니다.
  bool advanceHomeStep({
    required int expectedStep,
    required int completedCount,
  }) {
    final currentStep = _user.currentStep;

    if (currentStep != expectedStep) return false;
    if (currentStep < 1 || currentStep >= 4) return false;

    final requiredCount = currentStep == 1 ? 3 : 1;

    if (completedCount < requiredCount) return false;

    _user = _user.copyWith(
      currentStep: currentStep + 1,
    );

    notifyListeners();
    return true;
  }



  /// TODO(인증): 로그인 API 연결 후 응답의 role / diagnosed 로 교체
  void loginAs(UserRole role, {bool diagnosed = true}) {
    _user = _user.copyWith(
      role: role,
      diagnosed: diagnosed,
      name: role == UserRole.institution ? '서울청년센터' : mockUser.name,
    );
    _loadProfile();
    // 시연용: 진단을 마친 계정인데 저장된 진단이 없으면 샘플 진단 답을 넣어 둡니다.
    if (diagnosed && _diagnosis.isEmpty && role == UserRole.youth) {
      _diagnosis = mockDiagnosis;
      _saveProfile();
    }
    notifyListeners();
  }

  void logout() {
    _saveProfile();
    _user = mockUser;
    _diagnosis = DiagnosisProfile.empty;
    _aiReadiness = null;
    _aiSignature = null;
    _tutorialClosed = false;
    _tutorialSkipped.clear();
    _likes.clear();
    _aiRecs = null;
    _aiRecsSignature = null;
    notifyListeners();
  }
  // ───────────────────────── 미션 (STEP 1, 미션 수정)
  final List<Mission> _missions = [...mockMissions];
  List<Mission> get missions => List.unmodifiable(_missions);

  void updateMission(String id, Mission Function(Mission m) change) {
    final i = _missions.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final before = _missions[i];
    _missions[i] = change(before);
    // 리듬 회복 판단용: 미션을 완료한 시각을 남깁니다.
    if (before.status != MissionStatus.done && _missions[i].status == MissionStatus.done) {
      _missionDoneLog.add((id: id, at: DateTime.now()));
    } else if (before.status == MissionStatus.done && _missions[i].status != MissionStatus.done) {
      final j = _missionDoneLog.lastIndexWhere((e) => e.id == id);
      if (j >= 0) _missionDoneLog.removeAt(j);
    }
    notifyListeners();
  }
  

  void startMission(String id) =>
      updateMission(id, (m) => m.status == MissionStatus.todo ? m.copyWith(status: MissionStatus.doing) : m);

  /// 진행 중 미션 [fromId] 를 그만두고 [toId] 미션을 같은 마감일로 시작
  void swapMission(String fromId, String toId) {
    final from = _missions.firstWhere((m) => m.id == fromId);
    updateMission(fromId, (m) => m.copyWith(status: MissionStatus.todo, clearDue: true));
    updateMission(toId, (m) => m.copyWith(status: MissionStatus.doing, due: from.due));
  }

  // ───────────────────────── 활동 그만두기

  // STEP 2~4에서 사용자가 그만둔 활동을 기록합니다.
  // STEP 1은 기존 MissionStatus.todo로 복귀시킵니다.
  final Map<int, Set<String>> _stoppedActivityIds = {
    2: <String>{},
    3: <String>{},
    4: <String>{},
  };

  bool isActivityStopped({
    required int step,
    required String activityId,
  }) {
    return _stoppedActivityIds[step]?.contains(activityId) ?? false;
  }

    void stopActivity({
    required int step,
    required String activityId,
  }) {
    if (activityId.isEmpty) return;

    if (step == 1) {
      updateMission(
        activityId,
        (mission) {
          // 완료한 미션은 그만두기 처리하지 않습니다.
          if (mission.status == MissionStatus.done) {
            return mission;
          }

          return mission.copyWith(
            status: MissionStatus.todo,
            clearDue: true,
          );
        },
      );
      return;
    }

    final stoppedIds = _stoppedActivityIds[step];

    if (stoppedIds == null) return;

    // STEP 2~4도 완료한 활동은 그만두기 처리하지 않습니다.
    if (isHomeActivityDone(
      step: step,
      activityId: activityId,
    )) {
      return;
    }

    if (stoppedIds.add(activityId)) {
      notifyListeners();
    }
  }


  /// 향후 프로젝트 재참여 또는 STEP 3·4의 + 버튼에서 사용합니다.
  /// 이 메서드는 중단 상태만 해제합니다.
  /// 신청 승인이나 홈 활동 추가 처리는 해당 기능에서 별도로 수행합니다.
  void clearActivityStopped({
    required int step,
    required String activityId,
  }) {
    final changed =
        _stoppedActivityIds[step]?.remove(activityId) ?? false;

    if (changed) {
      notifyListeners();
    }
  }

  // ───────────────────────── 활동 기록
  final List<ActivityRecord> _records = [...mockRecords];
  List<ActivityRecord> get records => List.unmodifiable(_records);

  void saveRecord(ActivityRecord r) {
    _records.removeWhere((x) => x.id == r.id);
    _records.insert(0, r);
    notifyListeners();
  }

  void removeRecord(String id) {
    _records.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  // ───────────────────────── 스크랩 · 지원 현황
  // 스크랩과 지원 내역을 한 목록(_scraps)으로 관리합니다.
  // 지원한 공고는 스크랩을 지워도 지원현황에 남아야 해서, 목록에서 빼지 않고 bookmarked 만 false 로 바꿉니다.
  final List<Scrap> _scraps = [...mockScraps];

  /// 스크랩 탭에 보이는 항목 (북마크한 것만)
  List<Scrap> get scraps => List.unmodifiable(_scraps.where((s) => s.bookmarked));

  /// 지원한 공고만 (취업 지원현황 화면). 최근 지원 순
  List<Scrap> get appliedScraps {
    final v = _scraps.where((s) => s.applied).toList();
    v.sort((a, b) => (b.appliedAt ?? b.scrappedAt).compareTo(a.appliedAt ?? a.scrappedAt));
    return v;
  }

  bool isScrapped(String opportunityId) => _scraps.any((s) => s.opportunityId == opportunityId && s.bookmarked);

  /// 지원한 공고인지 (스크랩을 지웠어도 지원현황에 있으면 true)
  bool isApplied(String opportunityId) => _scraps.any((s) => s.opportunityId == opportunityId && s.applied);

  /// 북마크 켜기/끄기. 지원한 공고는 스크랩만 지우고 지원현황에는 남깁니다.
  void toggleScrap(String opportunityId) {
    final i = _scraps.indexWhere((s) => s.opportunityId == opportunityId);
    if (i < 0) {
      _scraps.insert(0, Scrap(opportunityId: opportunityId, scrappedAt: DateTime.now()));
    } else if (!_scraps[i].bookmarked) {
      _scraps[i] = _scraps[i].copyWith(bookmarked: true);
    } else if (_scraps[i].applied) {
      _scraps[i] = _scraps[i].copyWith(bookmarked: false);
    } else {
      _scraps.removeAt(i);
    }
    notifyListeners();
  }

  /// 지원 여부 변경. 지원하면 '지원 완료' 단계부터 시작
  void setApplied(String opportunityId, bool applied) {
    final i = _scraps.indexWhere((s) => s.opportunityId == opportunityId);
    if (i < 0) return;
    final s = _scraps[i];
    if (!applied && !s.bookmarked) {
      // 스크랩을 지운 뒤 지원까지 취소하면 남길 이유가 없음
      _scraps.removeAt(i);
    } else {
      _scraps[i] = applied
          ? s.copyWith(applied: true, appliedAt: s.appliedAt ?? DateTime.now(), stage: s.stage ?? ApplyStage.applied)
          : s.copyWith(applied: false, clearApply: true);
    }
    notifyListeners();
  }

  /// 지원현황: 진행 단계 변경 (서류 심사 → 면접 → 합격/불합격)
  void setApplyStage(String opportunityId, ApplyStage stage) {
    final i = _scraps.indexWhere((s) => s.opportunityId == opportunityId);
    if (i < 0) return;
    _scraps[i] = _scraps[i].copyWith(applied: true, appliedAt: _scraps[i].appliedAt ?? DateTime.now(), stage: stage);
    notifyListeners();
  }

  void setApplyMemo(String opportunityId, String memo) {
    final i = _scraps.indexWhere((s) => s.opportunityId == opportunityId);
    if (i < 0) return;
    _scraps[i] = _scraps[i].copyWith(memo: memo);
    notifyListeners();
  }

  // ───────────────────────── 팀 모집 글 · 팀 신청 (STEP 2)
  final List<TeamPost> _teamPosts = [...mockTeamPosts];
  List<TeamPost> get teamPosts => List.unmodifiable(_teamPosts);

  TeamPost? teamPostById(String id) {
    for (final p in _teamPosts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 팀원 정보. 내 id 면 현재 사용자 정보로 만들어서 돌려줌
  TeamMember? memberById(String id) {
    if (id == _user.id) {
      return TeamMember(
        id: _user.id,
        name: _user.name,
        intro: '',
        interests: _user.interests,
        step: _user.currentStep,
        missionsDone: _missions.where((m) => m.status == MissionStatus.done).length,
        records: _records.length,
      );
    }
    return findMember(id);
  }

  /// 팀원의 완료한 미션 (내 id 면 내 데이터)
  List<DoneMission> doneMissionsOf(String memberId) {
    if (memberId == _user.id) {
      return [
        for (final m in _missions.where((m) => m.status == MissionStatus.done))
          DoneMission(step: 1, title: m.title, category: m.category, minutes: m.minutes, doneAt: m.due ?? DateTime.now()),
      ];
    }
    final m = findMember(memberId);
    return m == null ? const [] : mockDoneMissionsOf(m);
  }

  /// 팀원의 활동 기록 (내 id 면 내 기록)
  List<ActivityRecord> recordsOf(String memberId) {
    if (memberId == _user.id) return records;
    final m = findMember(memberId);
    return m == null ? const [] : mockRecordsOf(m);
  }

  /// 내가 쓴 모집 글인지
  bool isMyPost(TeamPost p) => p.leaderId == _user.id;

  /// TODO(API): 모집 글 등록
  void addTeamPost(TeamPost p) {
    _teamPosts.insert(0, p);
    notifyListeners();
  }

  final List<TeamApplication> _applications = [];
  List<TeamApplication> get applications => List.unmodifiable(_applications);

  TeamApplication? applicationFor(String postId) {
    for (final a in _applications) {
      if (a.postId == postId) return a;
    }
    return null;
  }

  /// TODO(API): 팀 신청 전송
  void applyTeam(TeamApplication a) {
    _applications.removeWhere((x) => x.postId == a.postId);
    _applications.add(a);
    notifyListeners();
  }

  void cancelTeamApplication(String postId) {
    _applications.removeWhere((x) => x.postId == postId);
    notifyListeners();
  }

  // ───────────────────────── 기관 프로그램 등록
  final List<Program> _programs = [];
  List<Program> get programs => List.unmodifiable(_programs);

  void addProgram(Program p) {
    _programs.insert(0, p);
    notifyListeners();
  }

  // ───────────────────────── 알림
  final List<Notice> _notices = [...mockNotices];
  List<Notice> get notices => List.unmodifiable(_notices);
  int get unreadCount => _notices.where((n) => !n.read).length;

  /// [id] 가 없으면 모두 읽음
  void markRead([String? id]) {
    for (var i = 0; i < _notices.length; i++) {
      if (id == null || _notices[i].id == id) _notices[i] = _notices[i].markRead();
    }
    notifyListeners();
  }

  // ───────────────────────── 홈 활동 완료 상태 (STEP 2~4)

  // STEP별로 완료한 활동 ID를 저장합니다.
  // 목록에 ID가 있으면 완료, 없으면 미완료입니다.
  final Map<int, Set<String>> _completedHomeActivityIds = {
    2: <String>{},
    3: <String>{},
    4: <String>{},
  };

  bool isHomeActivityDone({
    required int step,
    required String activityId,
  }) {
    return _completedHomeActivityIds[step]?.contains(activityId) ?? false;
  }

    void toggleHomeActivityDone({
    required int step,
    required String activityId,
  }) {
    final completedIds = _completedHomeActivityIds[step];

    if (completedIds == null || activityId.isEmpty) return;

    // 그만둔 활동은 완료 처리할 수 없습니다.
    if (isActivityStopped(
      step: step,
      activityId: activityId,
    )) {
      return;
    }

    if (completedIds.contains(activityId)) {
      completedIds.remove(activityId);
    } else {
      completedIds.add(activityId);
    }

    notifyListeners();
  }

  // ───────────────────────── 홈에 추가한 공고 (STEP 3·4)

  // 홈의 AI 추천에서 "활동에 추가"한 공고 ID입니다.
  // 지원한 공고(appliedScraps)와 별개로 홈 활동에 표시됩니다.
  final Set<String> _homeAddedOpportunityIds = <String>{};

  bool isHomeOpportunityAdded(String opportunityId) =>
      _homeAddedOpportunityIds.contains(opportunityId);

  /// 공고를 홈 활동에 추가합니다. 그만둔 공고였다면 그만둠 상태도 해제합니다.
  void addHomeOpportunity({required String id, required int step}) {
    final added = _homeAddedOpportunityIds.add(id);
    final cleared = _stoppedActivityIds[step]?.remove(id) ?? false;

    if (added || cleared) {
      notifyListeners();
    }
  }

  /// 추가를 취소합니다. (추천 카드의 "실행 취소"용)
  void removeHomeOpportunity({required String id, required int step}) {
    if (_homeAddedOpportunityIds.remove(id)) {
      notifyListeners();
    }
  }

  // ───────────────────────── 니즈 진단 결과
  DiagnosisProfile _diagnosis = DiagnosisProfile.empty;
  DiagnosisProfile get diagnosis => _diagnosis;

  void saveDiagnosis(DiagnosisProfile p) {
    _diagnosis = p;
    _saveProfile();
    notifyListeners();
  }

  /// 진단을 안 했으면 기본값([DiagnosisProfile.fallback])을 씁니다. 준비도·추천은 이 값을 봅니다.
  DiagnosisProfile get effectiveDiagnosis =>
      _diagnosis.isEmpty ? DiagnosisProfile.fallback(interests: _user.interests) : _diagnosis;

  bool get hasDiagnosis => !_diagnosis.isEmpty;

  // ───────────────────────── 준비도 · 단계 (홈 3안)

  /// 미션 완료 기록 (최근 리듬 판단용)
  final List<({String id, DateTime at})> _missionDoneLog = [];

  /// "다음 단계로 바꿀까요?"를 '아직이요'로 미룬 날짜
  DateTime? _stageAskSnoozedAt;

  /// 참여가 확정된 팀 프로젝트 (그만둔 것 제외)
  List<TeamPost> get acceptedTeams => [
        for (final p in _teamPosts)
          if (applicationFor(p.id)?.status == ApplicationStatus.accepted &&
              !isActivityStopped(step: 2, activityId: p.id))
            p,
      ];

  Set<String> get doneTeamIds => {..._completedHomeActivityIds[2] ?? const <String>{}};

  ReadinessInput get _readinessInput => ReadinessInput(
        user: _user,
        diagnosis: effectiveDiagnosis,
        records: _records,
        acceptedTeams: acceptedTeams,
        doneTeamIds: doneTeamIds,
        likes: _likes,
        needsDirection: needsDirection,
      );

  /// AI 판단기. 키 없이 실행하면 null → 규칙 계산만 씁니다. (테스트에서 가짜로 바꿔 끼울 수 있어요)
  ReadinessJudge? readinessJudge = hasLlmKey ? BazeReadinessJudge() : null;

  ReadinessResult? _aiReadiness;
  String? _aiSignature;
  bool _readinessLoading = false;
  String? _readinessError;

  bool get readinessLoading => _readinessLoading;
  String? get readinessError => _readinessError;

  /// 준비도: 재료가 그대로면 마지막 AI 판단, 아니면(또는 AI 없음) 규칙 계산
  ReadinessResult get readiness {
    final input = _readinessInput;
    final ai = _aiReadiness;
    if (ai != null && _aiSignature == input.signature) return ai;
    return input.ruleResult();
  }

  /// 재료가 바뀌었으면 AI 에게 다시 판단을 맡깁니다. 홈이 보일 때 부릅니다.
  Future<void> refreshReadiness({bool force = false}) async {
    final judge = readinessJudge;
    if (judge == null || _readinessLoading || isInstitution) return;
    final input = _readinessInput;
    final sig = input.signature;
    if (!force && _aiSignature == sig && _aiReadiness != null) return;
    if (!force && _readinessError != null && _failedSignature == sig) return; // 같은 재료로 실패했으면 반복 호출하지 않음

    _readinessLoading = true;
    _readinessError = null;
    notifyListeners();
    try {
      _aiReadiness = await judge.judge(input);
      _aiSignature = sig;
      _saveProfile();
    } catch (e) {
      _readinessError = '$e';
      _failedSignature = sig;
    } finally {
      _readinessLoading = false;
      notifyListeners();
    }
  }

  String? _failedSignature;

  // ───────────────────────── 끌리는 것 (관심 찾기 카드)
  final List<String> _likes = [];
  List<String> get likes => List.unmodifiable(_likes);

  /// 분야·기업·직무를 아직 모르는 사람인지 (관심 찾기 카드·AI 방향 추천 대상)
  /// 진단에서 "모르겠어요 / 고민 중 / 아직 없어요 / 찾아가는 중"이라고 답한 것이 있을 때만 true.
  /// 직무·기업을 정했다고 답했으면 이름 칸을 비워 뒀어도 false 입니다.
  bool get needsDirection {
    final d = effectiveDiagnosis;
    return d.interests.isEmpty || d.companyPreference == '아직 고민 중이에요' || d.hasDesiredJob == false;
  }

  void setLikes(List<String> likes) {
    _likes
      ..clear()
      ..addAll(likes.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet());
    _saveProfile();
    notifyListeners();
  }

  // ───────────────────────── AI 추천 활동
  /// AI 추천기. 키 없이 실행하면 null → 규칙 추천만 씁니다.
  RecommendJudge? recommendJudge = hasLlmKey ? BazeRecommendJudge() : null;

  List<HomeRecommendation>? _aiRecs;
  String? _aiRecsSignature;
  String? _failedRecsSignature;
  bool _recsLoading = false;
  bool get recommendationsLoading => _recsLoading;

  RecommendInput get _recommendInput => RecommendInput(
        readiness: readiness,
        diagnosis: effectiveDiagnosis,
        candidates: allHomeCandidates(this),
        likes: _likes,
      );

  /// 홈 추천 활동: 재료가 그대로면 AI 가 고른 것, 아니면(또는 AI 없음) 규칙 추천
  List<HomeRecommendation> get homeRecommendations {
    final ai = _aiRecs;
    if (ai != null && _aiRecsSignature == _recommendInput.signature) return ai;
    return buildHomeRecommendations(this);
  }

  bool get recommendationsFromAi => _aiRecs != null && _aiRecsSignature == _recommendInput.signature;

  Future<void> refreshRecommendations() async {
    final judge = recommendJudge;
    if (judge == null || _recsLoading || isInstitution || _readinessLoading) return;
    final input = _recommendInput;
    if (input.candidates.isEmpty) return;
    final sig = input.signature;
    if (_aiRecsSignature == sig || _failedRecsSignature == sig) return;
    _recsLoading = true;
    notifyListeners();
    try {
      _aiRecs = await judge.pick(input);
      _aiRecsSignature = sig;
    } catch (_) {
      _failedRecsSignature = sig;
    } finally {
      _recsLoading = false;
      notifyListeners();
    }
  }

  UserStage get stage => stageOf(effectiveDiagnosis);

  /// 지금 단계에서 다음 단계로 넘어가도 될 것 같으면 다음 단계를, 아니면 null.
  /// - 리듬 → 교류: 최근 7일 동안 미션을 3번 이상 완료
  /// - 교류 → 탐색: 팀 프로젝트 참여 확정, 또는 '모임' 미션 2개 완료
  /// - 탐색 → 취업 준비: 준비도 60점 이상
  /// 사용자에게 물어보고 '네'를 눌러야 바뀝니다. '아직이요'를 누르면 그날은 다시 묻지 않습니다.
  UserStage? get suggestedNextStage {
    if (_diagnosis.isEmpty) return null;
    final snoozed = _stageAskSnoozedAt;
    final now = DateTime.now();
    if (snoozed != null && now.difference(snoozed).inHours < 24) return null;

    switch (stage) {
      case UserStage.rhythm:
        final week = now.subtract(const Duration(days: 7));
        final recent = _missionDoneLog.where((e) => e.at.isAfter(week)).length;
        return recent >= 3 ? UserStage.social : null;
      case UserStage.social:
        final meetups = _missions.where((m) => m.category == '모임' && m.status == MissionStatus.done).length;
        return (acceptedTeams.isNotEmpty || meetups >= 2) ? UserStage.explore : null;
      case UserStage.explore:
        return readiness.score >= 60 ? UserStage.ready : null;
      case UserStage.ready:
        return null;
    }
  }

  /// 단계 올리기: 진단 1번 답을 다음 단계 답으로 바꿉니다.
  void moveToStage(UserStage next) {
    _diagnosis = effectiveDiagnosis.withAnswer('current_status', stageAnswers[next]!);
    _saveProfile();
    notifyListeners();
  }

  void snoozeStageAsk() {
    _stageAskSnoozedAt = DateTime.now();
    notifyListeners();
  }

  /// 진단 답 하나 바꾸기 (내 기준 바꾸기). 관심 분야는 사용자 정보에도 반영합니다.
  void updateDiagnosisAnswer(String slotKey, String value) {
    _diagnosis = effectiveDiagnosis.withAnswer(slotKey, value);
    if (slotKey == 'interest') {
      _user = _user.copyWith(interests: _diagnosis.interests);
    }
    _saveProfile();
    notifyListeners();
  }

  /// 희망 직무 정하기 (고민 중 카드에서 직무를 고를 때).
  /// 6번 분기 답을 "직무 있음"으로 맞춘 뒤 직무 이름을 저장합니다.
  /// [field] 를 주면 관심 분야가 비어 있을 때 먼저 채웁니다. (직무는 관심 분야가 있어야 저장할 수 있어요)
  void setTargetJob(String job, {String? field}) {
    var d = effectiveDiagnosis;
    if (d.interests.isEmpty) {
      d = d.withAnswer('interest', field ?? fieldFromMajor(_user.major) ?? 'IT·데이터');
      _user = _user.copyWith(interests: d.interests);
    }
    final visible = visibleQuestions(d.answers).map((q) => q.slotKey).toSet();
    if (visible.contains('target_clarity')) {
      d = d.withAnswer('target_clarity', d.targetCompanyName != null ? '목표 기업과 직무 모두 있어요' : '직무만 정해뒀어요');
    } else if (visible.contains('desired_job_only')) {
      d = d.withAnswer('desired_job_only', '있어요');
    }
    _diagnosis = d.withAnswer('target_job_name', job);
    _saveProfile();
    notifyListeners();
  }

  // ───────────────────────── 홈 튜토리얼 박스
  bool _tutorialClosed = false;
  final Set<String> _tutorialSkipped = {};

  bool get tutorialClosed => _tutorialClosed;
  bool isTutorialSkipped(String step) => _tutorialSkipped.contains(step);

  void skipTutorialStep(String step) {
    if (_tutorialSkipped.add(step)) {
      _saveProfile();
      notifyListeners();
    }
  }

  void closeTutorial() {
    _tutorialClosed = true;
    _saveProfile();
    notifyListeners();
  }

  // ───────────────────────── 사람마다 저장 (진단 답 · 준비도 · 튜토리얼)
  /// 저장소. 지금은 메모리, 서버를 붙이면 이 값만 바꿉니다. (data/user_profile_store.dart)
  UserProfileStore profileStore = MemoryUserProfileStore();

  void _saveProfile() {
    if (isInstitution) return;
    profileStore.save(
      _user.id,
      StoredProfile(
        diagnosis: _diagnosis,
        readinessJson: _aiReadiness?.toJson(),
        readinessSignature: _aiSignature,
        tutorialClosed: _tutorialClosed,
        tutorialSkipped: {..._tutorialSkipped},
        likes: [..._likes],
      ),
    );
  }

  void _loadProfile() {
    final p = profileStore.load(_user.id);
    if (p == null || isInstitution) return;
    _diagnosis = p.diagnosis;
    _tutorialClosed = p.tutorialClosed;
    _tutorialSkipped
      ..clear()
      ..addAll(p.tutorialSkipped);
    _likes
      ..clear()
      ..addAll(p.likes);
    final j = p.readinessJson;
    if (j != null) {
      final rule = _readinessInput.ruleResult();
      _aiReadiness = ReadinessResult.fromJson(j, target: rule.target, stage: rule.stage);
      _aiSignature = p.readinessSignature;
    }
  }
}
