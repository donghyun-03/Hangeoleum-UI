// 메인(홈) — 하단 탭
// - 이름 영역 → 활동 기록 / 기록하기 → 기록 작성 / 종 아이콘 → 알림
// - [추가 기능 2] '미션 수정' 버튼 → 진행 중 미션 마감 시 변경
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final unread = state.unreadCount;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.directions_walk, size: 15, color: AppColors.paper),
          ),
          const SizedBox(width: 6),
          const Text('한걸음'),
        ]),
        actions: [
          IconButton(
            tooltip: '알림 $unread건',
            onPressed: () => Navigator.pushNamed(context, Routes.notifications),
            icon: Badge(isLabelVisible: unread > 0, smallSize: 7, backgroundColor: AppColors.red, child: const Icon(Icons.notifications_none)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            InkWell(
              onTap: () => Navigator.pushNamed(context, state.isInstitution ? Routes.profile : Routes.recordList),
              child: Row(children: [
                Avatar(name: user.name, size: 34, color: AppColors.dim),
                const SizedBox(width: 8),
                Text(state.isInstitution ? user.name : '${user.name.substring(1)}님', style: AppText.h2.copyWith(fontSize: 16)),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.subtle),
              ]),
            ),
            const Spacer(),
            if (!state.isInstitution)
              AppButton(
                label: '기록하기',
                small: true,
                expand: false,
                variant: ButtonVariant.outline,
                onPressed: () => AppNav.toRecordWrite(context),
              ),
          ]),
          const SizedBox(height: 16),
          if (state.isInstitution) const _InstitutionHome() else const _YouthHome(),
        ],
      ),
    );
  }
}

class _YouthHome extends StatelessWidget {
  const _YouthHome();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final step = state.user.currentStep;
    final active = state.missions.where((m) => m.status != MissionStatus.todo).toList();
    final done = active.where((m) => m.status == MissionStatus.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.soft,
          onTap: () => context.read<MainTabs>().go(MainTab.step, step: step),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('지금 내 위치 단계', style: AppText.caption),
            Text('STEP $step · ${stepInfo[step]!.title}', style: AppText.h2.copyWith(fontSize: 17)),
            Text('생활 리듬 되찾기', style: AppText.small.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            TagBadge('미션 $done/${active.length} 완료', tone: BadgeTone.dark),
            const SizedBox(height: 10),
            ProgressLine(value: done, total: active.length),
          ]),
        ),
        const SectionTitle('진행 중인 미션'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < active.length; i++) ...[
              if (i > 0) const Divider(),
              _MissionRow(m: active[i]),
            ],
          ]),
        ),
        // [추가 기능 2] 미션 수정
        AppButton(
          label: '미션 수정',
          icon: Icons.edit_outlined,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.pushNamed(context, Routes.missionEdit),
        ),
      ],
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.m});
  final Mission m;

  @override
  Widget build(BuildContext context) {
    final done = m.status == MissionStatus.done;
    final due = m.due == null ? '' : ' · ~${m.due!.month}/${m.due!.day}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(done ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 20, color: done ? AppColors.dim : AppColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title, style: AppText.body.copyWith(fontSize: 13.5, color: done ? AppColors.subtle : AppColors.ink)),
            Text('${m.minutes}분 · ${m.category}$due', style: AppText.caption),
          ]),
        ),
        TagBadge(done ? '완료' : '진행 중', tone: done ? BadgeTone.gray : BadgeTone.green),
      ]),
    );
  }
}

class _InstitutionHome extends StatelessWidget {
  const _InstitutionHome();

  @override
  Widget build(BuildContext context) {
    final programs = context.watch<AppState>().programs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('활동기관', style: AppText.caption),
            const SizedBox(height: 4),
            Text('등록한 프로그램 ${programs.length}개', style: AppText.h2.copyWith(fontSize: 17)),
            const SizedBox(height: 10),
            AppButton(
              label: '프로그램 등록',
              icon: Icons.add,
              small: true,
              expand: false,
              onPressed: () => Navigator.pushNamed(context, Routes.programRegister),
            ),
          ]),
        ),
        for (final p in programs)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TagBadge('STEP ${p.step} · ${kindLabel[p.kind]}', tone: BadgeTone.gray),
              const SizedBox(height: 6),
              Text(p.title, style: AppText.bodyBold),
              Text([if (p.region.isNotEmpty) p.region, '마감 ${p.deadline}'].join(' · '), style: AppText.caption),
            ]),
          ),
        const TodoBox('기관 홈: 신청자 수, 검수 상태 등 정해지면 추가'),
      ],
    );
  }
}
