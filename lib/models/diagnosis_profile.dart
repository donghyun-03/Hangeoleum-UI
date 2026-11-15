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

  bool get isEmpty => answers.isEmpty;

  // ───────────── 항목별 getter

  String? get currentStatus => answers['current_status'];
  String? get primaryGoal => answers['primary_goal'];
  String? get timeCommitment => answers['time_commitment'];
  String? get companyPreference => answers['company_preference'];

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
      'readiness_assets',
    ],
    DiagnosisUse.companyRecommendation: [
      'company_preference',
      'target_clarity',
      'target_company_only',
      'desired_job_only',
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
      if (v == null) continue;

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
