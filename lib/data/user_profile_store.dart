// 사람마다 저장하는 "내 기준" 정보: 진단 답, 마지막 준비도 판단(AI), 튜토리얼 상태
//
// 지금은 앱 메모리에 사용자 id 별로 저장합니다. (다른 데이터처럼 앱을 끄면 사라짐)
// 서버를 붙일 때는 [UserProfileStore] 를 구현한 클래스 하나만 만들어 AppState.profileStore 에 넣으면 됩니다.
//   Supabase 예: user_readiness 테이블 한 줄 = 사용자 한 명
//     create table user_readiness (
//       user_id uuid primary key references users(id) on delete cascade,
//       diagnosis jsonb not null default '{}',   -- 진단 답 (DiagnosisProfile.toJson)
//       readiness jsonb,                          -- 마지막 준비도 판단 (ReadinessResult.toJson)
//       readiness_signature text,                 -- 판단할 때 쓴 재료 (바뀌면 AI 다시 호출)
//       tutorial jsonb not null default '{}',     -- {"closed":false,"skipped":["gpa"]}
//       likes text[] not null default '{}',       -- 관심 찾기에서 적은 끌리는 것
//       updated_at timestamptz not null default now()
//     );

import '../models/diagnosis_profile.dart';

class StoredProfile {
  const StoredProfile({
    this.diagnosis = DiagnosisProfile.empty,
    this.readinessJson,
    this.readinessSignature,
    this.tutorialClosed = false,
    this.tutorialSkipped = const {},
    this.likes = const [],
  });

  final DiagnosisProfile diagnosis;

  /// 마지막 AI 준비도 판단 (ReadinessResult.toJson). 없으면 null
  final Map<String, dynamic>? readinessJson;
  final String? readinessSignature;

  /// 홈 튜토리얼 박스를 닫았는지, 건너뛴 단계
  final bool tutorialClosed;
  final Set<String> tutorialSkipped;

  /// 관심 찾기 카드에서 적은 끌리는 것
  final List<String> likes;

  StoredProfile copyWith({
    DiagnosisProfile? diagnosis,
    Map<String, dynamic>? readinessJson,
    String? readinessSignature,
    bool? tutorialClosed,
    Set<String>? tutorialSkipped,
    List<String>? likes,
  }) =>
      StoredProfile(
        diagnosis: diagnosis ?? this.diagnosis,
        readinessJson: readinessJson ?? this.readinessJson,
        readinessSignature: readinessSignature ?? this.readinessSignature,
        tutorialClosed: tutorialClosed ?? this.tutorialClosed,
        tutorialSkipped: tutorialSkipped ?? this.tutorialSkipped,
        likes: likes ?? this.likes,
      );

  Map<String, dynamic> toJson() => {
        'diagnosis': diagnosis.toJson(),
        'readiness': readinessJson,
        'readiness_signature': readinessSignature,
        'tutorial': {'closed': tutorialClosed, 'skipped': tutorialSkipped.toList()},
        'likes': likes,
      };

  factory StoredProfile.fromJson(Map<String, dynamic> j) {
    final tutorial = Map<String, dynamic>.from(j['tutorial'] as Map? ?? const {});
    return StoredProfile(
      diagnosis: DiagnosisProfile.fromJson(Map<String, dynamic>.from(j['diagnosis'] as Map? ?? const {})),
      readinessJson: j['readiness'] == null ? null : Map<String, dynamic>.from(j['readiness'] as Map),
      readinessSignature: j['readiness_signature'] as String?,
      tutorialClosed: tutorial['closed'] as bool? ?? false,
      tutorialSkipped: {for (final s in (tutorial['skipped'] as List? ?? const [])) '$s'},
      likes: [for (final l in (j['likes'] as List? ?? const [])) '$l'],
    );
  }
}

abstract class UserProfileStore {
  StoredProfile? load(String userId);
  void save(String userId, StoredProfile profile);
}

/// 앱 메모리 저장소 (사용자 id 별). 서버 연결 전 기본값.
class MemoryUserProfileStore implements UserProfileStore {
  final Map<String, Map<String, dynamic>> _rows = {};

  @override
  StoredProfile? load(String userId) {
    final row = _rows[userId];
    return row == null ? null : StoredProfile.fromJson(row);
  }

  @override
  void save(String userId, StoredProfile profile) => _rows[userId] = profile.toJson();
}
