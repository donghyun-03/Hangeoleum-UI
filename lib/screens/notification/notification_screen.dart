// 알림 — 마감 임박 / 내게 맞는 새 소식
// 누르면: 마감 임박 → 홈 / STEP 1 알림 → STEP 1 화면 / 나머지 → 프로그램 상세
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deadline = state.notices.where((n) => n.group == 'deadline').toList();
    final fresh = state.notices.where((n) => n.group == 'new').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () => state.markRead(),
            child: const Text(
              '모두 읽음',
              style: TextStyle(fontSize: 12.5, color: AppColors.green),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SectionTitle('마감 임박', aside: '${deadline.length}건'),
                _Group(items: deadline),
              ],
            ),
          ),
          Container(height: 16, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SectionTitle('내게 맞는 새 소식', aside: '${fresh.length}건'),
                _Group(items: fresh),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림을 읽음 처리하고 해당 화면으로 이동
void _open(BuildContext context, Notice n) {
  context.read<AppState>().markRead(n.id);

  void goTab(MainTab tab, {int? step}) {
    context.read<MainTabs>().go(tab, step: step);
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  if (n.group == 'deadline') {
    goTab(MainTab.home);
  } else if (n.step == 1) {
    goTab(MainTab.step, step: 1);
  } else if (n.programId case final id?) {
    AppNav.toProgramDetail(context, id);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.items});
  final List<Notice> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          InkWell(
            onTap: () => _open(context, items[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            items[i].category,
                            style: AppText.caption.copyWith(
                              fontSize: 11,
                              fontWeight: items[i].read
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                              color: items[i].read
                                  ? AppColors.muted
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          items[i].title,
                          style: AppText.body.copyWith(
                            fontSize: 14.5,
                            fontWeight: items[i].read
                                ? FontWeight.w400
                                : FontWeight.w700,
                            color: items[i].read
                                ? AppColors.muted
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(items[i].meta, style: AppText.caption),
                      ],
                    ),
                  ),
                  if (items[i].dday != null)
                    TagBadge('D-${items[i].dday}')
                  else if (!items[i].read)
                    const TagBadge('NEW', tone: BadgeTone.red),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
