// 화면에서 쓰는 데이터 모델.
// 백엔드 API 응답 모양이 정해지면 여기에 fromJson 을 추가하고, mock_data.dart 는 개발용으로만 남깁니다.

enum UserRole { youth, institution } // 청년 / 활동기관

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

  Mission copyWith({MissionStatus? status, DateTime? due, bool clearDue = false}) {
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

// ── 활동 기록 (STAR)
class Star {
  final String s; // 상황
  final String t; // 목표
  final String a; // 행동
  final String r; // 결과
  const Star({required this.s, required this.t, required this.a, required this.r});

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
  const Attachment({required this.id, required this.type, required this.name, required this.uri, this.size});
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
  final String desc;
  final int current;
  final int max;
  final int weeks;
  final int perWeek;
  final String mode; // 온라인 / 오프라인
  final String leaderId;
  final String postedAgo;

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
  });
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

  const TeamApplication({
    required this.postId,
    required this.role,
    required this.availableTime,
    required this.message,
    this.sharedRecordIds = const [],
    this.status = ApplicationStatus.pending,
  });
}

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

/// 공고 스크랩 + 지원 여부 (취업 지원 현황)
class Scrap {
  final String opportunityId;
  final bool applied;
  final DateTime scrappedAt;
  const Scrap({required this.opportunityId, this.applied = false, required this.scrappedAt});

  Scrap copyWith({bool? applied}) =>
      Scrap(opportunityId: opportunityId, applied: applied ?? this.applied, scrappedAt: scrappedAt);
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
class Notice {
  final String id;
  final String group; // 'deadline' | 'new'
  final String category; // 정책, 적금, 캠프
  final String title;
  final String meta;
  final int? dday;
  final bool read;

  const Notice({
    required this.id,
    required this.group,
    required this.category,
    required this.title,
    required this.meta,
    this.dday,
    this.read = false,
  });

  Notice markRead() => Notice(id: id, group: group, category: category, title: title, meta: meta, dday: dday, read: true);
}
