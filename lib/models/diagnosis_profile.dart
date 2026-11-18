import '../data/diagnosis_data.dart';

/// 진단 정보가 쓰이는 곳. 용도마다 필요한 항목이 다릅니다.
enum DiagnosisUse {
  /// AI가 사용자에게 맞는 STEP(1~4) 판단
  stepJudgement,

  /// STEP 1~3 미션·활동·프로그램 추천
  activityRecommendation,

  /// 희망 직무 추천·정리
  jobRecommendation,

  /// 기업·채용 공고 추천 (STEP 4)
  companyRecommendation,
}

class DiagnosisProfile {
  const DiagnosisProfile(this.answers, {this.completedAt});

  /// slotKey → 선택한 값
  final Map<String, String> answers;
  final DateTime? completedAt;

  static const empty = DiagnosisProfile({});

  /// 진단을 안 하고 들어왔을 때 쓰는 기본값.
  /// 교육·공모전 탐색 단계, 하루 30분, 기업은 고민 중으로 두고 관심 분야는 회원 정보에서 가져옵니다.
  factory DiagnosisProfile.fallback({List<String> interests = const []}) {
    const fields = {'IT·데이터', '디자인·영상', '사무·행정'};
    final field = interests.where(fields.contains).firstOrNull;
    return DiagnosisProfile({
      'current_status': '잘 모르겠어요.',
      'primary_goal': '경험 쌓기',
      'time_commitment': '30분 정도',
      'interest': field ?? '아직 잘 모르겠어요',
      'company_preference': '아직 고민 중이에요',
    });
  }

  bool get isEmpty => answers.isEmpty;

  /// 한 항목의 답을 바꾼 새 진단을 돌려줍니다. (내 기준 바꾸기 화면에서 사용)
  /// 바뀐 답 때문에 더 이상 묻지 않는 질문(예: 6번 분기)의 답은 지웁니다.
  DiagnosisProfile withAnswer(String slotKey, String value) {
    final next = Map<String, String>.from(answers)..[slotKey] = value;

    // 6번 분기가 바뀌어도 이미 적어 둔 기업·직무 이름은 살립니다.
    final company = slotKey == 'target_company_name' ? null : targetCompanyName;
    final job = slotKey == 'target_job_name' ? null : targetJobName;
    final branchKeys = {'target_clarity', 'target_company_only', 'desired_job_only'};
    if (!branchKeys.contains(slotKey)) {
      final visible = visibleQuestions(next).map((q) => q.slotKey).toSet();
      if (visible.contains('target_clarity') && !next.containsKey('target_clarity') && (company != null || job != null)) {
        next['target_clarity'] = company != null && job != null
            ? '목표 기업과 직무 모두 있어요'
            : (company != null ? '목표 기업만 정해뒀어요' : '직무만 정해뒀어요');
      }
      if (visible.contains('desired_job_only') && !next.containsKey('desired_job_only') && job != null) {
        next['desired_job_only'] = '있어요';
      }
      if (visible.contains('target_company_only') && !next.containsKey('target_company_only') && company != null) {
        next['target_company_only'] = '있어요';
      }
    }

    // 더 이상 묻지 않는 질문의 답을 지웁니다. (지우면 또 안 보이게 되는 질문이 있어 바뀌지 않을 때까지 반복)
    while (true) {
      final visibleKeys = visibleQuestions(next).map((q) => q.slotKey).toSet();
      final before = next.length;
      next.removeWhere((key, _) => !visibleKeys.contains(key));
      if (next.length == before) break;
    }
    return DiagnosisProfile(next, completedAt: completedAt);
  }

  // ───────────── 항목별 getter

  String? get currentStatus => answers['current_status'];
  String? get primaryGoal => answers['primary_goal'];
  String? get timeCommitment => answers['time_commitment'];
  String? get companyPreference => answers['company_preference'];

  /// 관심 분야 원래 답 ('아직 잘 모르겠어요' 포함)
  String? get interest => answers['interest'];

  /// 직접 입력한 목표 기업 이름 (없거나 건너뛰면 null)
  String? get targetCompanyName => _text('target_company_name');

  /// 직접 입력한 희망 직무 이름 (없거나 건너뛰면 null)
  String? get targetJobName => _text('target_job_name');

  String? _text(String key) {
    final v = answers[key]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 기존 코드 호환용: 사기업 / 공기업 / null
  String? get companyType {
    switch (companyPreference) {
      case '공기업·공공기관':
        return '공기업';
      case '스타트업':
      case '중소기업':
      case '중견기업':
      case '대기업':
        return '사기업';
      default:
        return null;
    }
  }

  /// 기존 코드 호환용: 스타트업 / 중소기업 / 중견기업 / 대기업 / null
  String? get companySize {
    const privateSizes = {'스타트업', '중소기업', '중견기업', '대기업'};
    final v = companyPreference;
    return privateSizes.contains(v) ? v : null;
  }

  /// 특정 희망 기업이 있는지
  /// null: 질문하지 않았거나 판단할 수 없는 상태
  bool? get hasTargetCompany {
    final clarity = answers['target_clarity'];

    if (clarity != null) {
      switch (clarity) {
        case '목표 기업과 직무 모두 있어요':
        case '목표 기업만 정해뒀어요':
          return true;
        case '직무만 정해뒀어요':
        case '아직 찾아가는 중이에요':
          return false;
        default:
          return null;
      }
    }

    final companyOnly = answers['target_company_only'];

    if (companyOnly != null) {
      switch (companyOnly) {
        case '있어요':
          return true;
        case '아직 없어요':
          return false;
        default:
          return null;
      }
    }

    // desired_job_only 분기에서는 특정 기업 보유 여부를 질문하지 않음
    return null;
  }

  /// 희망 직무가 있는지
  bool? get hasDesiredJob {
    final clarity = answers['target_clarity'];

    if (clarity != null) {
      switch (clarity) {
        case '목표 기업과 직무 모두 있어요':
        case '직무만 정해뒀어요':
          return true;
        case '목표 기업만 정해뒀어요':
        case '아직 찾아가는 중이에요':
          return false;
        default:
          return null;
      }
    }

    final jobOnly = answers['desired_job_only'];

    if (jobOnly != null) {
      switch (jobOnly) {
        case '있어요':
          return true;
        case '아직 없어요':
          return false;
        default:
          return null;
      }
    }

    // 관심 분야가 없으면 희망 직무도 미정으로 판단
    if (answers['interest'] == '아직 잘 모르겠어요') {
      return false;
    }

    return null;
  }

  /// 포트폴리오(공모전·프로젝트 등 활동 기록)를 갖고 있는지
  bool? get hasPortfolio {
    switch (answers['readiness_assets']) {
      case '포트폴리오와 어학 성적 모두 있어요':
      case '포트폴리오만 있어요':
        return true;
      case '어학 성적만 있어요':
      case '아직 둘 다 없어요':
        return false;
      default:
        return null;
    }
  }

  /// 어학 성적을 갖고 있는지
  bool? get hasLanguageScore {
    switch (answers['readiness_assets']) {
      case '포트폴리오와 어학 성적 모두 있어요':
      case '어학 성적만 있어요':
        return true;
      case '포트폴리오만 있어요':
      case '아직 둘 다 없어요':
        return false;
      default:
        return null;
    }
  }

  /// 관심 분야 ('아직 잘 모르겠어요'는 제외)
  List<String> get interests {
    final v = answers['interest'];
    return (v == null || v == '아직 잘 모르겠어요')
        ? const []
        : [v];
  }

  /// 기업 추천이 명확하게 필요한 경우
  bool get needsCompanyRecommendation => hasTargetCompany == false;

  /// 직무 추천이 명확하게 필요한 경우
  bool get needsJobRecommendation => hasDesiredJob == false;

  // ───────────── AI 프롬프트용

  static const _labels = {
    'current_status': '현재 상태',
    'primary_goal': '가장 먼저 도전하고 싶은 것',
    'time_commitment': '하루 투자 가능 시간',
    'interest': '관심 분야',
    'company_preference': '희망 기업 유형 및 규모',
    'target_clarity': '목표 기업 및 희망 직무 보유 여부',
    'target_company_only': '특정 희망 기업 보유 여부',
    'desired_job_only': '희망 직무 보유 여부',
    'target_company_name': '목표 기업',
    'target_job_name': '희망 직무',
    'readiness_assets': '포트폴리오(활동 경험) 및 어학 성적 보유 여부',
  };

  /// 용도별로 필요한 항목
  static const _slotsByUse = {
    DiagnosisUse.stepJudgement: [
      'current_status',
      'primary_goal',
      'time_commitment',
      'interest',
      'readiness_assets',
    ],
    DiagnosisUse.activityRecommendation: [
      'current_status',
      'primary_goal',
      'time_commitment',
      'interest',
      'readiness_assets',
    ],
    DiagnosisUse.jobRecommendation: [
      'interest',
      'company_preference',
      'target_clarity',
      'target_company_only',
      'desired_job_only',
      'target_job_name',
      'readiness_assets',
    ],
    DiagnosisUse.companyRecommendation: [
      'company_preference',
      'target_clarity',
      'target_company_only',
      'desired_job_only',
      'target_company_name',
      'target_job_name',
      'interest',
      'readiness_assets',
    ],
  };

  /// 용도에 필요한 항목만 골라 AI 프롬프트에 붙여 넣을 문장으로 만듭니다.
  /// use를 생략하면 모든 항목을 포함합니다.
  String toPromptContext({DiagnosisUse? use}) {
    final keys = use == null ? null : _slotsByUse[use]!.toSet();
    final lines = <String>[];

    for (final q in kDiagnosisQuestions) {
      if (keys != null && !keys.contains(q.slotKey)) continue;

      final v = answers[q.slotKey];
      if (v == null || v.trim().isEmpty) continue;

      lines.add('- ${_labels[q.slotKey] ?? q.slotKey}: $v');
    }

    if (lines.isEmpty) return '[진단 정보 없음]';

    return '''[사용자 진단 정보]
${lines.join('\n')}

※ 위 정보는 사용자가 실제로 선택한 답변입니다.
기재되지 않은 항목은 미응답이거나 분기상 질문하지 않은 항목이므로 임의로 추측하지 마세요.''';
  }

  // ───────────── 저장 (Firebase 연결 시 사용)

  Map<String, dynamic> toJson() => {
        'answers': Map<String, String>.from(answers),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory DiagnosisProfile.fromJson(Map<String, dynamic> json) =>
      DiagnosisProfile(
        Map<String, String>.from(
          json['answers'] as Map? ?? const {},
        ),
        completedAt: DateTime.tryParse(
          json['completedAt'] as String? ?? '',
        ),
      );
}
