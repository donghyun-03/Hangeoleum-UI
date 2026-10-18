// 화면(라우트) 목록과 이동 함수.
// 새 화면을 추가할 때: 1) Routes 에 이름 추가 → 2) onGenerateRoute 에 case 추가 → 3) 필요하면 AppNav 에 이동 함수 추가
//
// 화면에서 쓰는 법
//   AppNav.toTeamApply(context, 'p1');   // 파라미터 있는 화면
//   Navigator.pushNamed(context, Routes.notifications);   // 파라미터 없는 화면
//   Navigator.pop(context);   // 뒤로
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/all/all_screen.dart';
import '../screens/application/application_status_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/common/coming_soon_screen.dart';
import '../screens/institution/program_register_screen.dart';
import '../screens/mission/mission_edit_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/onboarding/diagnosis_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/record/record_list_screen.dart';
import '../screens/record/record_result_screen.dart';
import '../screens/record/record_write_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/team/member_activity_screen.dart';
import '../screens/team/member_profile_screen.dart';
import '../screens/team/team_apply_screen.dart';
import '../screens/team/team_post_write_screen.dart';

class Routes {
  Routes._();

  // 인증·온보딩
  static const login = '/login';
  static const signup = '/signup';
  static const diagnosis = '/diagnosis'; // AI 대화 Q1~Q4

  /// 하단 탭(홈 · STEP · 스크랩 · 전체)이 있는 메인 화면
  static const main = '/main';

  // 활동 기록
  static const recordList = '/record';
  static const recordWrite = '/record/write'; // 인자: String? missionId
  static const recordResult = '/record/result'; // 인자: ActivityRecord (AI 정리 초안)

  // 미션
  static const missionEdit = '/mission/edit';

  // 팀 (STEP 2)
  static const memberProfile = '/team/member'; // 인자: String memberId
  static const memberActivity = '/team/member/activity'; // 인자: ({String memberId, int tab}) — 완료한 미션·활동 기록
  static const teamApply = '/team/apply'; // 인자: String postId. 신청하면 true 를 돌려줌
  static const teamPostWrite = '/team/write'; // 팀 모집 글쓰기. 올리면 true 를 돌려줌

  // 취업 (STEP 4)
  static const applicationStatus = '/applications'; // 취업 지원현황

  // 기관
  static const programRegister = '/program/register';

  // 기타
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const allServices = '/all'; // 탭 밖에서 전체 화면을 열 때
  static const comingSoon = '/coming-soon'; // 인자: String title
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final args = settings.arguments;
  final Widget page = switch (settings.name) {
    Routes.login => const LoginScreen(),
    Routes.signup => const SignupScreen(),
    Routes.diagnosis => const DiagnosisScreen(),
    Routes.main => const MainShell(),
    Routes.recordList => const RecordListScreen(),
    Routes.recordWrite => RecordWriteScreen(missionId: args as String?),
    Routes.recordResult => RecordResultScreen(draft: args as ActivityRecord),
    Routes.missionEdit => const MissionEditScreen(),
    Routes.memberProfile => MemberProfileScreen(memberId: args as String),
    Routes.memberActivity => switch (args) {
        (memberId: final String id, tab: final int tab) => MemberActivityScreen(memberId: id, initialTab: tab),
        _ => const ComingSoonScreen(title: '활동'),
      },
    Routes.teamApply => TeamApplyScreen(postId: args as String),
    Routes.teamPostWrite => const TeamPostWriteScreen(),
    Routes.applicationStatus => const ApplicationStatusScreen(),
    Routes.programRegister => const ProgramRegisterScreen(),
    Routes.notifications => const NotificationScreen(),
    Routes.profile => const ProfileScreen(),
    Routes.allServices => const AllScreen(),
    Routes.comingSoon => ComingSoonScreen(title: (args as String?) ?? '준비 중'),
    _ => ComingSoonScreen(title: settings.name ?? '알 수 없는 화면'),
  };
  return MaterialPageRoute(builder: (_) => page, settings: settings);
}

/// 파라미터 타입을 실수하지 않도록 만든 이동 함수 모음
class AppNav {
  AppNav._();

  static Future<void> toRecordWrite(BuildContext context, {String? missionId}) =>
      Navigator.pushNamed(context, Routes.recordWrite, arguments: missionId);

  static Future<void> toRecordResult(BuildContext context, ActivityRecord draft) =>
      Navigator.pushNamed(context, Routes.recordResult, arguments: draft);

  static Future<void> toMemberProfile(BuildContext context, String memberId) =>
      Navigator.pushNamed(context, Routes.memberProfile, arguments: memberId);

  /// 팀원 활동 자세히 보기. tab 0 = 완료한 미션, 1 = 활동 기록
  static Future<void> toMemberActivity(BuildContext context, String memberId, {int tab = 0}) =>
      Navigator.pushNamed(context, Routes.memberActivity, arguments: (memberId: memberId, tab: tab));

  /// 신청을 완료하면 true
  static Future<bool> toTeamApply(BuildContext context, String postId) async =>
      await Navigator.pushNamed(context, Routes.teamApply, arguments: postId) == true;

  /// 글을 올리면 true
  static Future<bool> toTeamPostWrite(BuildContext context) async =>
      await Navigator.pushNamed(context, Routes.teamPostWrite) == true;

  static Future<void> toComingSoon(BuildContext context, String title) =>
      Navigator.pushNamed(context, Routes.comingSoon, arguments: title);

  /// 이전 화면을 모두 지우고 이동 (로그인 → 메인 등)
  static void resetTo(BuildContext context, String route) =>
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
}
