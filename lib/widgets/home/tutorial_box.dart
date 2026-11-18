// 홈 튜토리얼 박스: 좌우로 넘기며 학점·어학·첫 기록·진단을 채우게 도와줍니다.
// 이미 채운 단계는 저절로 사라지고, 단계마다 "건너뛰기", 박스 전체는 X 로 닫을 수 있어요. (사람마다 저장)
// 성적·어학·자격증은 아래에 창을 띄우지 않고 내 정보로 가서, 각 칸의 추가 버튼을 누른 것처럼 바로 입력 창을 열어요.
// 고교 재학·고졸이면 학점 대신 내신 등급을 넣어요.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../router/routes.dart';
import '../../screens/profile/profile_screen.dart';
import '../../services/readiness_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../common.dart';

class _Step {
  const _Step(this.id, this.title, this.body, this.action, this.onAction);
  final String id;
  final String title;
  final String body;
  final String action;
  final void Function(BuildContext) onAction;
}

List<_Step> _stepsFor(AppState state) {
  final u = state.user;
  final d = state.effectiveDiagnosis;
  return [
    if (!state.hasDiagnosis)
      _Step('diagnosis', '내 기준 정하기', '질문 몇 개에 답하면 관심 분야·희망 기업에 맞춰 준비도를 계산해요. 지금은 기본값으로 보여 주고 있어요.',
          '질문 답하기', (c) => Navigator.pushNamed(c, Routes.diagnosis)),
    // 진단에서 포트폴리오가 "있다"고 했으면 (기존 기록이 있어도) 맨 앞에서 넣어 달라고 안내합니다.
    // "포트폴리오 넣기"를 누르거나 건너뛰면 이 카드는 사라져요.
    if (d.hasPortfolio == true)
      _Step('portfolio', '포트폴리오를 넣어 주세요!', '진단에서 포트폴리오가 있다고 했어요. 해 본 공모전·프로젝트를 기록하고 파일이나 링크를 붙이면 준비도에 바로 반영돼요.',
          '포트폴리오 넣기', (c) {
        c.read<AppState>().skipTutorialStep('portfolio');
        AppNav.toRecordWrite(c);
      }),
    if (ReadinessService.isUniversity(u.education) && u.gpa == null)
      _Step('gpa', '학점 넣기', '대학을 다녔다면 학점이 "성적" 항목에 들어가요. 전체 평균 학점 하나면 돼요.', '학점 입력',
          (c) => AppNav.toProfile(c, focus: ProfileFocus.grades)),
    // 고교 재학·고졸이면 학점 대신 내신 등급 (건너뛰기는 학점과 같이 'gpa' 로 저장)
    if (ReadinessService.isHighSchool(u.education) && u.schoolGrade == null)
      _Step('gpa', '내신 등급 넣기', '고등학교 내신 평균 등급(1~9등급)을 넣어 주세요. 고졸 채용에서 성적으로 봐요.', '내신 입력',
          (c) => AppNav.toProfile(c, focus: ProfileFocus.grades)),
    // 분야·기업·직무를 모른다고 했으면: 끌리는 것 아무거나 몇 개 → AI 가 방향 추천
    if (state.needsDirection && state.likes.isEmpty)
      _Step('likes', '끌리는 것 적기', '좋아하는 거, 요즘 조금이라도 재밌던 거 아무거나 몇 개만 알려 주세요. AI가 나에게 맞는 분야·직무를 찾아 줄게요.',
          '적어 보기', _askLikes),
    // 진단에서 어학 성적이 "있다"고 한 사람에게만
    if (u.languages.isEmpty && d.hasLanguageScore == true)
      _Step('language', '어학 성적 넣기', '진단에서 어학 성적이 있다고 했어요. 가장 최근 점수 하나만 넣어 주세요.', '어학 입력',
          (c) => AppNav.toProfile(c, focus: ProfileFocus.language)),
    // 목표 회사·직무가 자격증을 보는 곳(자격증 비중 10% 넘음)이고 아직 하나도 안 넣었으면
    if (u.certificates.isEmpty && state.readiness.area(ReadinessArea.certificate).weight > 0.1)
      _Step('certificate', '자격증 넣기', '${state.readiness.target.label} 기준에서는 자격증도 봐요. 이미 딴 자격증이 있으면 넣어 주세요. 없으면 건너뛰어도 돼요.',
          '자격증 입력', (c) => AppNav.toProfile(c, focus: ProfileFocus.certificate)),
    if (state.records.isEmpty && d.hasPortfolio != true)
      _Step('record', '첫 활동 기록 남기기', '해 본 일을 편하게 적으면 AI가 정리해 줘요. 기록이 쌓일수록 준비도가 정확해져요.', '기록 쓰기',
          (c) => AppNav.toRecordWrite(c)),
    _Step('howto', '준비도 보는 법', '"나의 역량"을 누르면 5개 항목과 지금 채우면 좋은 것이 펼쳐져요. 자세히 보기에서 항목별로 뭐가 부족한지 볼 수 있어요.',
        '알겠어요', (c) => c.read<AppState>().skipTutorialStep('howto')),
  ].where((s) => !state.isTutorialSkipped(s.id)).toList();
}

class TutorialBox extends StatefulWidget {
  const TutorialBox({super.key});

  @override
  State<TutorialBox> createState() => _TutorialBoxState();
}

class _TutorialBoxState extends State<TutorialBox> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.isInstitution || state.tutorialClosed) return const SizedBox.shrink();
    final steps = _stepsFor(state);
    if (steps.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, steps.length - 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('시작 가이드', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('${index + 1} / ${steps.length}', style: AppText.caption),
                const Spacer(),
                IconButton(
                  tooltip: '가이드 닫기',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18, color: AppColors.subtle),
                  onPressed: state.closeTutorial,
                ),
              ],
            ),
            SizedBox(
              height: 128,
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: [for (final s in steps) _StepPage(step: s)],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Container(
                    width: i == index ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.green : AppColors.dim,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title, style: AppText.bodyBold.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(step.body, style: AppText.small.copyWith(fontSize: 12.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          Row(
            children: [
              if (step.id != 'howto') ...[
                Expanded(
                  child: AppButton(
                    label: '건너뛰기',
                    small: true,
                    variant: ButtonVariant.outline,
                    onPressed: () => context.read<AppState>().skipTutorialStep(step.id),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: AppButton(label: step.action, small: true, onPressed: () => step.onAction(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



const _likeExamples = ['게임', '요리', '사진', '영상 보기', '글쓰기', '그림', '운동', '음악', '정리하기', '사람 돕기', '숫자·계산', '만들기', '여행', '동물', '패션', 'SNS'];

Future<void> _askLikes(BuildContext context) async {
  final state = context.read<AppState>();
  final picked = <String>{...state.likes};
  final ctrl = TextEditingController();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setLocal) {
        void addTyped() {
          final t = ctrl.text.trim();
          if (t.isEmpty) return;
          setLocal(() => picked.add(t));
          ctrl.clear();
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('끌리는 것 아무거나', style: AppText.bodyBold),
              const SizedBox(height: 4),
              Text('직업이 아니어도 괜찮아요. 몇 개만 골라도 돼요.', style: AppText.small),
              const SizedBox(height: 12),
              ChipWrap(
                children: [
                  for (final e in {..._likeExamples, ...picked})
                    SelectChip(
                      label: e,
                      selected: picked.contains(e),
                      onTap: () => setLocal(() => picked.contains(e) ? picked.remove(e) : picked.add(e)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onSubmitted: (_) => addTyped(),
                      decoration: const InputDecoration(hintText: '직접 적기 (예: 캠핑, 웹툰)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(label: '추가', small: true, expand: false, variant: ButtonVariant.outline, onPressed: addTyped),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(
                label: '저장',
                onPressed: () {
                  if (picked.isEmpty) return;
                  Navigator.pop(sheet, true);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
  ctrl.dispose();
  if (saved == true && picked.isNotEmpty) state.setLikes(picked.toList());
}
