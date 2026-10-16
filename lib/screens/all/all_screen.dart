// 검색(전체) 탭 — 모든 기능을 찾아 해당 화면으로 이동
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AllScreen extends StatefulWidget {
  const AllScreen({super.key});

  @override
  State<AllScreen> createState() => _AllScreenState();
}

class _AllScreenState extends State<AllScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 탭 밖(다른 화면 위)에서 열렸으면 탭 이동 전에 메인으로 되돌아감
  void _goTab(MainTab tab, {int? step}) {
    Navigator.popUntil(context, (r) => r.isFirst);
    context.read<MainTabs>().go(tab, step: step);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _search.text.trim();

    final services = <(IconData, String, String, VoidCallback)>[
      (Icons.edit_note, '활동 기록', '오늘 한 일을 STAR로 정리', () => Navigator.pushNamed(context, Routes.recordList)),
      (Icons.folder_outlined, '내 경험 정리', '경험 리포트 · 포트폴리오 · 자기소개서', () => AppNav.toComingSoon(context, '내 경험 정리')),
      (Icons.work_outline, '채용 · 공모전', '나에게 맞는 공고 찾아보기', () => _goTab(MainTab.step, step: 4)),
      (Icons.bookmark_border, '공고 스크랩', '스크랩한 공고 · 지원 현황', () => _goTab(MainTab.scrap)),
      (Icons.groups_outlined, '미니 프로젝트', '모여서 2-3명이 4주 도전', () => _goTab(MainTab.step, step: 2)),
      (Icons.notifications_none, '알림', '맞춤 알림 · 마감 임박 소식', () => Navigator.pushNamed(context, Routes.notifications)),
      (Icons.person_outline, '내 정보', '프로필 · 관심 분야 · 알림 설정', () => Navigator.pushNamed(context, Routes.profile)),
      if (state.isInstitution)
        (Icons.add_box_outlined, '프로그램 등록', '기관 프로그램 · 채용 공고 올리기', () => Navigator.pushNamed(context, Routes.programRegister)),
    ];
    final shownServices = services.where((s) => q.isEmpty || '${s.$2} ${s.$3}'.contains(q)).toList();
    final results = q.isEmpty ? <Opportunity>[] : mockOpportunities.where((o) => '${o.title} ${o.org} ${o.field}'.contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체'),
        centerTitle: false,
        titleSpacing: 20,
        actions: [
          IconButton(
            tooltip: '알림 ${state.unreadCount}건',
            onPressed: () => Navigator.pushNamed(context, Routes.notifications),
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SearchField(controller: _search, hint: '서비스, 채용, 공모전 검색', onChanged: (_) => setState(() {})),
          if (q.isEmpty) ...[
            SectionTitle('나에게 맞는 추천', aside: '더보기', onAside: () => _goTab(MainTab.step, step: 3)),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final o = mockOpportunities[i];
                  return SizedBox(
                    width: 150,
                    child: AppCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(12),
                      onTap: () => _goTab(MainTab.step, step: o.step),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(kindLabel[o.kind]!, style: AppText.caption.copyWith(fontSize: 10.5)),
                        Text(o.title, style: AppText.bodyBold.copyWith(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Text('D-${o.dday} · ${o.region}', style: AppText.caption.copyWith(fontSize: 11)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
          if (results.isNotEmpty) ...[
            SectionTitle('공고', aside: '${results.length}건'),
            for (final o in results)
              AppCard(
                onTap: () => _goTab(MainTab.step, step: o.step),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${kindLabel[o.kind]} · D-${o.dday}', style: AppText.caption.copyWith(fontSize: 11)),
                  Text(o.title, style: AppText.bodyBold),
                ]),
              ),
          ],
          const SectionTitle('전체 서비스'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < shownServices.length; i++) ...[
                if (i > 0) const Divider(),
                ListTile(
                  leading: Icon(shownServices[i].$1, color: AppColors.muted),
                  title: Text(shownServices[i].$2, style: AppText.bodyBold.copyWith(fontSize: 13.5)),
                  subtitle: Text(shownServices[i].$3, style: AppText.caption),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.dim),
                  onTap: shownServices[i].$4,
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
