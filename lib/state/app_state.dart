// 앱 전역 상태 (provider 의 ChangeNotifier). 지금은 메모리에만 저장되어 앱을 끄면 초기화됩니다.
// 기능별로 섹션을 나눠 두었습니다. 자기 기능 섹션만 수정하면 병합 충돌이 줄어듭니다.
//
// 화면에서 쓰는 법
//   읽기(값이 바뀌면 다시 그림):  final state = context.watch<AppState>();
//   액션 호출(버튼 onPressed 등): context.read<AppState>().toggleScrap(id);
//
// API 연결 시: 각 액션 안에서 서버를 호출하고 결과로 값을 바꾼 뒤 notifyListeners() 하면 됩니다.
import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';

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
    notifyListeners();
  }

  void logout() {
    _user = mockUser;
    notifyListeners();
  }

  // ───────────────────────── 미션 (STEP 1, 미션 수정)
  final List<Mission> _missions = [...mockMissions];
  List<Mission> get missions => List.unmodifiable(_missions);

  void updateMission(String id, Mission Function(Mission m) change) {
    final i = _missions.indexWhere((m) => m.id == id);
    if (i < 0) return;
    _missions[i] = change(_missions[i]);
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
  final List<Scrap> _scraps = [...mockScraps];
  List<Scrap> get scraps => List.unmodifiable(_scraps);

  /// 지원한 공고만 (취업 지원현황 화면). 최근 지원 순
  List<Scrap> get appliedScraps {
    final v = _scraps.where((s) => s.applied).toList();
    v.sort((a, b) => (b.appliedAt ?? b.scrappedAt).compareTo(a.appliedAt ?? a.scrappedAt));
    return v;
  }

  bool isScrapped(String opportunityId) => _scraps.any((s) => s.opportunityId == opportunityId);

  void toggleScrap(String opportunityId) {
    if (isScrapped(opportunityId)) {
      _scraps.removeWhere((s) => s.opportunityId == opportunityId);
    } else {
      _scraps.insert(0, Scrap(opportunityId: opportunityId, scrappedAt: DateTime.now()));
    }
    notifyListeners();
  }

  /// 지원 여부 변경. 지원하면 '지원 완료' 단계부터 시작
  void setApplied(String opportunityId, bool applied) {
    final i = _scraps.indexWhere((s) => s.opportunityId == opportunityId);
    if (i < 0) return;
    final s = _scraps[i];
    _scraps[i] = applied
        ? s.copyWith(applied: true, appliedAt: s.appliedAt ?? DateTime.now(), stage: s.stage ?? ApplyStage.applied)
        : s.copyWith(applied: false, clearApply: true);
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

}


