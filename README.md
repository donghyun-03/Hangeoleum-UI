# Hangeoleum-UI

한걸음 frontend — 쉬었음 청년에게 STEP 1~4 활동을 추천하는 앱의 화면 골조입니다.

- **Flutter** + provider (전역 상태) + file_picker (기록 첨부)
- 백엔드 연결 없음. 모든 데이터는 `lib/data/mock_data.dart` 샘플이고, 앱 메모리에만 저장됩니다(앱을 끄면 초기화).
- 각자 맡은 화면 파일만 고치면 되도록 **화면 1개 = 파일 1개**로 나눠 두었습니다.
- 한글 폰트는 Pretendard (SIL OFL 1.1)를 `assets/fonts` 에 넣어 두었습니다.

## 실행

```powershell
flutter pub get
flutter run              # 연결된 기기/에뮬레이터 선택
flutter run -d chrome    # 브라우저로 빠르게 확인
flutter analyze          # 코드 검사
flutter test             # 테스트
```

로그인 화면 아래 **개발용 미리보기 버튼**(청년·진단 전 / 청년·진단 완료 / 활동기관)으로 각 흐름에 바로 들어갈 수 있습니다.

## 폴더 구조

```
lib/
  main.dart                     앱 시작, Provider, MaterialApp (되도록 수정 X)
  theme/app_theme.dart          색(AppColors)·글자(AppText)·테마
  models/models.dart            데이터 모델
  data/mock_data.dart           샘플 데이터 (시안 내용 기준) + 조회 도우미
  state/app_state.dart          전역 상태 + 액션 (기능별 섹션)
  router/
    routes.dart                 화면 이름(Routes), onGenerateRoute, 이동 함수(AppNav)
    main_tabs.dart              하단 탭 상태 (다른 화면에서 탭 이동)
  widgets/
    common.dart                 AppCard, AppButton, TagBadge, SelectChip, SearchField, LabeledField, TodoBox …
    opportunity_card.dart       공고 카드 + 스크랩 북마크
    filter_panel.dart           검색창 옆 필터 패널 (STEP 2 · STEP 4 공통)
  screens/
    auth/                       login_screen, signup_screen
    onboarding/                 diagnosis_screen (AI 대화 Q1~Q4)
    shell/                      main_shell (하단 탭: 홈 · STEP · 스크랩 · 전체)
    home/                       home_screen
    mission/                    mission_edit_screen            ← 추가 기능 2
    record/                     record_list / record_write / record_result  ← 추가 기능 1 (첨부)
    step/                       step_screen (STEP 1~4 선택·정렬)
                                step1_missions / step2_connect / step3_challenge / step4_job
    scrap/                      scrap_screen                   ← 추가 기능 3
    team/                       member_profile_screen, team_apply_screen, team_post_write_screen
    application/                application_status_screen (취업 지원현황)
    institution/                program_register_screen        ← 추가 기능 6
    notification/               notification_screen
    profile/                    profile_screen (내 정보)
    all/                        all_screen (검색·전체 탭)
    common/                     coming_soon_screen (미정 화면 자리)
test/widget_test.dart           기본 흐름 테스트
.github/workflows/flutter_ci.yml  PR 마다 analyze + test 자동 실행
```

## 화면 흐름

하단 탭: **홈 · STEP · 스크랩 · 전체**

| 출발 | 동작 | 도착 |
| --- | --- | --- |
| 로그인 | 회원가입 | 회원가입 (청년/활동기관) |
| 로그인 | 청년 · 진단 전 | AI 대화 → 진단 완료 → 홈 |
| 로그인 | 진단한 청년 · 기관 | 홈 |
| 홈 | 이름(프로필) | 활동 기록 |
| 홈 | 기록하기 | 기록 작성 → AI 정리 결과 → 저장 → 활동 기록 |
| 홈 | 미션 수정 | 미션 수정 |
| 홈 | 종 아이콘 | 알림 |
| STEP 2 | 팀 카드 / 팀원 아바타 | 팀 신청(모집 글 상세) / 팀원 프로필 |
| STEP 2 | 글쓰기 | 팀원 모집 글쓰기 → '내가 쓴 글' 탭 |
| STEP 2 | 팀 신청 완료 | '내가 신청한 글' 탭 |
| STEP 3·4 | 북마크 | 스크랩 탭에 추가 |
| STEP 4 | 오른쪽 위 지원현황 | 취업 지원현황 (단계·메모 관리) |
| 스크랩 | 지원했어요 | 취업 지원현황에 추가 |
| STEP 3·4 (기관) | 글쓰기 | 프로그램 등록 |
| 전체 | 서비스 목록 | 각 화면 |

## 추가 기능 (디자인 시안 대비)

| # | 내용 | 위치 | 상태 |
| --- | --- | --- | --- |
| 1 | 기록 작성 시 파일·깃허브 링크 첨부 | `screens/record/record_write_screen.dart` | 골조 완료, 업로드 API 필요 |
| 2 | 진행 중 미션 마감 시 변경 (미션 수정 버튼) | `home/home_screen.dart` → `mission/mission_edit_screen.dart` | 골조 완료 |
| 3 | 활동 스크랩 + 지원했는지/안 했는지 | `widgets/opportunity_card.dart`(북마크) → `scrap/scrap_screen.dart` | 골조 완료 |
| 4 | STEP 2 검색창 | `step/step2_connect.dart` | 골조 완료 |
| 5 | STEP 4 필터 (지역·고용형태·경력·직무) | `step/step4_job.dart` | 골조 완료 |
| 6 | 팀원 프로필 · 팀 신청 · 프로그램 등록(기관) | `team/`, `institution/` | 디자인 없음 → 임시 레이아웃 |

화면 안의 노란 **TODO 박스**와 코드의 `// TODO(...)` 주석이 남은 작업입니다.

## 코드 규칙

1. 새 화면 추가: `router/routes.dart` 의 `Routes` 에 이름 추가 → `onGenerateRoute` 에 case 추가 → `screens/폴더/xxx_screen.dart` 생성
2. 화면 이동
   ```dart
   Navigator.pushNamed(context, Routes.notifications);   // 파라미터 없는 화면
   AppNav.toTeamApply(context, 'p1');                    // 파라미터 있는 화면
   context.read<MainTabs>().go(MainTab.step, step: 4);   // 하단 탭 이동
   ```
3. 전역 상태
   ```dart
   final state = context.watch<AppState>();     // build 안에서 읽기 (값 바뀌면 다시 그림)
   context.read<AppState>().toggleScrap(id);    // 버튼 등에서 액션 호출
   ```
   새 상태가 필요하면 `state/app_state.dart` 의 **자기 기능 섹션**에만 추가
4. 색은 `AppColors`, 글자는 `AppText`, 공통 모양은 `widgets/common.dart` 사용 (Color(0xFF...) 직접 쓰지 않기)
5. 공통 파일(`widgets/`, `theme/`, `state/`, `router/`, `main.dart`)을 고칠 때는 팀에 먼저 공유
6. PR 올리기 전에 `flutter analyze` 와 `flutter test` 통과 확인 (PR 에서도 자동으로 돌아요)
