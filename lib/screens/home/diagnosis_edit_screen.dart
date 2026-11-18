// 내 기준 바꾸기: 처음 진단에서 고른 답을 보고 하나씩 바꿉니다.
// 바뀐 답 때문에 더 이상 묻지 않는 질문의 답은 자동으로 지워집니다. (DiagnosisProfile.withAnswer)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/diagnosis_data.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/job_search_field.dart';

class DiagnosisEditScreen extends StatelessWidget {
  const DiagnosisEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final answers = state.effectiveDiagnosis.answers;
    final questions = visibleQuestions(answers);

    return Scaffold(
      appBar: AppBar(title: const Text('내 기준 바꾸기')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('처음에 골라 준 답이에요. 바뀐 게 있으면 눌러서 고쳐 주세요. 준비도와 추천이 바로 바뀌어요.',
              style: AppText.small),
          const SizedBox(height: 14),
          for (final q in questions)
            AppCard(
              onTap: () => _edit(context, q, answers),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.questionText, style: AppText.caption),
                        const SizedBox(height: 4),
                        Text(
                          (answers[q.slotKey]?.isNotEmpty ?? false) ? answers[q.slotKey]! : '아직 안 정했어요',
                          style: AppText.bodyBold.copyWith(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.subtle),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, SlotQuestion q, Map<String, String> answers) async {
    final state = context.read<AppState>();
    final current = answers[q.slotKey];
    final ctrl = TextEditingController(text: current ?? '');
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(q.questionText, style: AppText.bodyBold),
            const SizedBox(height: 12),
            if (q.jobSearch) ...[
              JobSearchField(
                field: answers['interest'],
                selected: current,
                maxResults: 8, // 시트가 키보드에 가려지지 않게 조금만
                onSelected: (job) => Navigator.pop(sheet, job),
              ),
              const SizedBox(height: 12),
              AppButton(label: '아직 모르겠어요', variant: ButtonVariant.outline, onPressed: () => Navigator.pop(sheet, '')),
            ] else if (q.freeText) ...[
              TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: q.hintText)),
              const SizedBox(height: 12),
              AppButton(label: '저장', onPressed: () => Navigator.pop(sheet, ctrl.text.trim())),
            ] else
              ChipWrap(
                children: [
                  for (final o in q.options)
                    SelectChip(label: o, selected: o == current, onTap: () => Navigator.pop(sheet, o)),
                ],
              ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (picked == null) return;
    state.updateDiagnosisAnswer(q.slotKey, picked);
  }
}
