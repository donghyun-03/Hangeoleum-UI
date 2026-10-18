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

  bool isScrapped(String opportunityId) => _scraps.any((s) => s.opportunityId == opportunityId);

  void toggleScrap(String opportunityId) {
    if (isScrapped(opportunityId)) {
      _scraps.removeWhere((s) => s.opportunityId == opportunityId);
    } else {
      _scraps.insert(0, Scrap(opportunityId: opportunityId, scrappedAt: DateTime.now()));
    }
    notifyListeners();
  }

  void setApplied(String opportunityId, bool applied) {
    final i = _scraps.indexWhere((s) => s.opportunityId == opportunityId);
    if (i < 0) return;
    _scraps[i] = _scraps[i].copyWith(applied: applied);
    notifyListeners();
  }

  // ───────────────────────── 팀 신청 (STEP 2)
  final List<TeamApplication> _applications = [];
  List<TeamApplication> get applications => List.unmodifiable(_applications);

  TeamApplication? applicationFor(String postId) {
    for (final a in _applications) {
      if (a.postId == postId) return a;
    }
    return null;
  }

  void applyTeam(TeamApplication a) {
    _applications.removeWhere((x) => x.postId == a.postId);
    _applications.add(a);
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
}


