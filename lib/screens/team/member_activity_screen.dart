// 팀원 활동 자세히 보기 — 팀원 프로필의 '완료한 미션' / '활동 기록'에서 진입
// 탭 1: 완료한 미션 (STEP 별로 묶어서)  탭 2: 활동 기록 (STAR, 누르면 펼침)
// TODO(API): 공개 범위(사용자가 공개한 기록만 보여주기) 정해지면 반영
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MemberActivityScreen extends StatelessWidget {
  const MemberActivityScreen({super.key, required this.memberId, this.initialTab = 0});
  final String memberId;

  /// 0 = 완료한 미션, 1 = 활동 기록
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.memberById(memberId);
    if (m == null) {
      return Scaffold(appBar: AppBar(title: const Text('활동')), body: const EmptyState(title: '프로필을 찾을 수 없어요'));
    }
    final missions = state.doneMissionsOf(memberId);
    final records = state.recordsOf(memberId);
    final isMe = memberId == state.user.id;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isMe ? '내 활동' : '${m.name}님의 활동'),
          bottom: TabBar(
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.subtle,
            indicatorColor: AppColors.ink,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 13.5),
            tabs: [
              Tab(text: '완료한 미션 ${missions.length}'),
              Tab(text: '활동 기록 ${records.length}'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _MissionsTab(missions: missions),
          _RecordsTab(records: records),
        ]),
      ),
    );
  }
}

// ───────────────────────── 완료한 미션
class _MissionsTab extends StatelessWidget {
  const _MissionsTab({required this.missions});
  final List<DoneMission> missions;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) {
      return const EmptyState(icon: Icons.flag_outlined, title: '아직 완료한 미션이 없어요');
    }
    final steps = [for (var s = 4; s >= 1; s--) if (missions.any((x) => x.step == s)) s];
    final totalMinutes = missions.fold<int>(0, (n, x) => n + x.minutes);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: StatRow(center: true, items: [
            for (var s = 1; s <= 4; s++) (missions.where((x) => x.step == s).length, 'STEP $s'),
          ]),
        ),
        Text('총 ${missions.length}개 · 약 ${(totalMinutes / 60).toStringAsFixed(1)}시간', style: AppText.caption, textAlign: TextAlign.right),
        for (final s in steps) ...[
          SectionTitle('STEP $s · ${stepInfo[s]!.title}', aside: '${missions.where((x) => x.step == s).length}개'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (final x in missions.where((x) => x.step == s)) ...[
                if (x != missions.firstWhere((y) => y.step == s)) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    const Icon(Icons.check_circle, size: 20, color: AppColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x.title, style: AppText.body.copyWith(fontSize: 13.5)),
                        Text('${x.category} · ${x.minutes}분', style: AppText.caption),
                      ]),
                    ),
                    Text('${x.doneAt.month}/${x.doneAt.day} 완료', style: AppText.caption.copyWith(fontSize: 11)),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── 활동 기록
class _RecordsTab extends StatelessWidget {
  const _RecordsTab({required this.records});
  final List<ActivityRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyState(icon: Icons.edit_note, title: '아직 활동 기록이 없어요');
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('카드를 누르면 자세한 내용을 볼 수 있어요.', style: AppText.caption),
        const SizedBox(height: 10),
        for (final r in records) _RecordTile(record: r),
      ],
    );
  }
}

class _RecordTile extends StatefulWidget {
  const _RecordTile({required this.record});
  final ActivityRecord record;

  @override
  State<_RecordTile> createState() => _RecordTileState();
}

class _RecordTileState extends State<_RecordTile> {
  bool _open = false;

  static const _labels = {'S': '상황', 'T': '목표', 'A': '행동', 'R': '결과'};

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final star = {'S': r.star.s, 'T': r.star.t, 'A': r.star.a, 'R': r.star.r};
    return AppCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TagBadge('STEP ${r.step}', tone: BadgeTone.gray),
          const SizedBox(width: 6),
          Expanded(child: Text(r.date, style: AppText.caption.copyWith(fontSize: 11))),
          Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.subtle),
        ]),
        const SizedBox(height: 6),
        Text(r.title, style: AppText.bodyBold),
        const SizedBox(height: 4),
        if (!_open)
          // 접힌 상태: 결과 한 줄만
          Text(r.star.r, style: AppText.small.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)
        else ...[
          for (final e in star.entries)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 44,
                  child: Text('${e.key} ${_labels[e.key]}', style: AppText.bodyBold.copyWith(fontSize: 12, color: AppColors.green)),
                ),
                Expanded(child: Text(e.value, style: AppText.small.copyWith(fontSize: 13))),
              ]),
            ),
          if (r.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in r.attachments)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(a.type == AttachmentType.github ? Icons.code : Icons.attach_file, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(a.name, style: AppText.caption.copyWith(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
            ]),
          ],
        ],
      ]),
    );
  }
}
