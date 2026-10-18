// 취업 지원현황 — STEP 4 오른쪽 위 '지원현황' 버튼에서 진입
// 스크랩 탭에서 '지원했어요'를 누른 공고가 카드로 모여요.
// 카드마다 진행 단계(지원 완료 → 서류 심사 → 면접 → 결과)와 메모를 관리합니다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum _Filter { all, progress, passed, failed }

/// 카드 위 진행 표시에 쓰는 단계 (불합격은 '결과' 칸에 표시)
const _track = [ApplyStage.applied, ApplyStage.document, ApplyStage.interview, ApplyStage.passed];

class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  _Filter _filter = _Filter.all;

  void _goScrapTab() {
    Navigator.popUntil(context, (r) => r.isFirst);
    context.read<MainTabs>().go(MainTab.scrap);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // TODO(API): 지원 내역 조회
    final items = [
      for (final s in state.appliedScraps)
        if (findOpportunity(s.opportunityId) case final o?) (s, o),
    ];
    int count(bool Function(ApplyStage s) f) => items.where((x) => f(x.$1.stage ?? ApplyStage.applied)).length;
    final shown = items.where((x) {
      final st = x.$1.stage ?? ApplyStage.applied;
      return switch (_filter) {
        _Filter.all => true,
        _Filter.progress => st.inProgress,
        _Filter.passed => st == ApplyStage.passed,
        _Filter.failed => st == ApplyStage.failed,
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('취업 지원현황')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 요약
          AppCard(
            child: StatRow(center: true, items: [
              (items.length, '지원'),
              (count((s) => s.inProgress), '진행 중'),
              (count((s) => s == ApplyStage.interview), '면접'),
              (count((s) => s == ApplyStage.passed), '합격'),
            ]),
          ),
          const SizedBox(height: 4),
          ChipWrap(children: [
            for (final (f, label) in [
              (_Filter.all, '전체'),
              (_Filter.progress, '진행 중'),
              (_Filter.passed, '합격'),
              (_Filter.failed, '불합격'),
            ])
              SelectChip(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f)),
          ]),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Column(children: [
              const EmptyState(
                icon: Icons.assignment_outlined,
                title: '아직 지원한 공고가 없어요',
                desc: "스크랩 탭에서 '지원했어요'를 누르면\n여기에서 진행 상황을 관리할 수 있어요.",
              ),
              AppButton(label: '스크랩한 활동 보러 가기', variant: ButtonVariant.outline, onPressed: _goScrapTab),
            ])
          else if (shown.isEmpty)
            const EmptyState(icon: Icons.filter_alt_off_outlined, title: '해당하는 지원 내역이 없어요'),
          for (final (s, o) in shown) _ApplyCard(scrap: s, o: o),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("스크랩 탭에서 '지원했어요'를 누른 공고가 여기에 모여요.", style: AppText.caption, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _ApplyCard extends StatelessWidget {
  const _ApplyCard({required this.scrap, required this.o});
  final Scrap scrap;
  final Opportunity o;

  (BadgeTone, String) get _badge {
    final st = scrap.stage ?? ApplyStage.applied;
    return switch (st) {
      ApplyStage.applied => (BadgeTone.gray, st.label),
      ApplyStage.document => (BadgeTone.green, '${st.label} 중'),
      ApplyStage.interview => (BadgeTone.amber, '${st.label} 예정'),
      ApplyStage.passed => (BadgeTone.dark, st.label),
      ApplyStage.failed => (BadgeTone.red, st.label),
    };
  }

  @override
  Widget build(BuildContext context) {
    final st = scrap.stage ?? ApplyStage.applied;
    final (tone, label) = _badge;
    final applied = scrap.appliedAt;
    return AppCard(
      onTap: () => _showEditSheet(context, scrap, o),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              o.step == 4 ? '${o.field}${o.employment != null ? ' · ${o.employment}' : ''}' : kindLabel[o.kind]!,
              style: AppText.caption.copyWith(fontSize: 11),
            ),
          ),
          TagBadge(label, tone: tone),
        ]),
        const SizedBox(height: 4),
        Text(o.title, style: AppText.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(
          [o.org, o.region, if (applied != null) '${applied.month}/${applied.day} 지원'].join(' · '),
          style: AppText.caption.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 14),
        _StageTrack(stage: st),
        if (scrap.memo.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.event_note_outlined, size: 15, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(scrap.memo, style: AppText.small.copyWith(fontSize: 12))),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: '상태 변경',
            icon: Icons.edit_outlined,
            small: true,
            expand: false,
            variant: ButtonVariant.outline,
            onPressed: () => _showEditSheet(context, scrap, o),
          ),
        ),
      ]),
    );
  }
}

/// 지원 완료 → 서류 심사 → 면접 → 결과 진행 표시
class _StageTrack extends StatelessWidget {
  const _StageTrack({required this.stage});
  final ApplyStage stage;

  @override
  Widget build(BuildContext context) {
    final failed = stage == ApplyStage.failed;
    // 불합격이면 '결과' 칸까지 칠하고 빨간색으로
    final reached = failed ? _track.length - 1 : _track.indexOf(stage);
    final on = failed ? AppColors.red : AppColors.green;
    final labels = ['지원', '서류', '면접', failed ? '불합격' : '합격'];

    return Row(children: [
      for (var i = 0; i < _track.length; i++) ...[
        Column(children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= reached ? on : AppColors.paper,
              border: Border.all(color: i <= reached ? on : AppColors.dim, width: 1.5),
            ),
            child: i <= reached
                ? Icon(failed && i == reached ? Icons.close : Icons.check, size: 12, color: AppColors.paper)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            labels[i],
            style: TextStyle(
              fontSize: 11,
              fontWeight: i == reached ? FontWeight.w700 : FontWeight.w400,
              color: i <= reached ? AppColors.ink : AppColors.subtle,
            ),
          ),
        ]),
        if (i < _track.length - 1)
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18, left: 2, right: 2),
              color: i < reached ? on : AppColors.line,
            ),
          ),
      ],
    ]);
  }
}

/// 단계 변경 + 메모 + 지원 취소 바텀시트
Future<void> _showEditSheet(BuildContext context, Scrap scrap, Opportunity o) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.paper,
    builder: (_) => _EditSheet(scrap: scrap, o: o, messenger: ScaffoldMessenger.of(context)),
  );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.scrap, required this.o, required this.messenger});
  final Scrap scrap;
  final Opportunity o;

  /// 시트를 닫은 뒤 토스트를 띄울 곳 (카드가 사라져도 안전하도록 미리 받아 둠)
  final ScaffoldMessengerState messenger;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _memo = TextEditingController(text: widget.scrap.memo);
  late ApplyStage _stage = widget.scrap.stage ?? ApplyStage.applied;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  void _close(String message) {
    Navigator.pop(context);
    widget.messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final o = widget.o;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(o.title, style: AppText.h2.copyWith(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
        Text('${o.org} · ${o.region}', style: AppText.caption),
        const SectionTitle('진행 단계'),
        ChipWrap(children: [
          for (final s in ApplyStage.values)
            SelectChip(label: s.label, selected: _stage == s, onTap: () => setState(() => _stage = s)),
        ]),
        const SectionTitle('메모'),
        LabeledField(controller: _memo, hint: '예) 10/22(수) 오후 2시 대면 면접, 포트폴리오 지참', maxLines: 3, maxLength: 200),
        const SizedBox(height: 16),
        AppButton(
          label: '저장',
          onPressed: () {
            state.setApplyStage(o.id, _stage);
            state.setApplyMemo(o.id, _memo.text.trim());
            _close('지원 상태를 바꿨어요');
          },
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () {
              state.setApplied(o.id, false);
              _close('지원현황에서 뺐어요. 스크랩은 남아 있어요');
            },
            child: const Text('지원 취소 (지원현황에서 빼기)', style: TextStyle(fontSize: 12.5, color: AppColors.subtle)),
          ),
        ),
      ]),
    );
  }
}
