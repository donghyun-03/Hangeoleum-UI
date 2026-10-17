// 알림 — 마감 임박 / 내게 맞는 새 소식
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
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

class _Group extends StatelessWidget {
  const _Group({required this.items});
  final List<Notice> items;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          // TODO: 알림 눌렀을 때 해당 공고/정책 상세로 이동
          InkWell(
            onTap: () => state.markRead(items[i].id),
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
