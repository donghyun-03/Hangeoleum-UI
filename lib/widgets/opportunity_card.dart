// STEP 3·4 공고 카드. 오른쪽 북마크로 스크랩 → 스크랩 탭에서 지원 여부 관리
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.o, this.onTap});
  final Opportunity o;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final on = state.isScrapped(o.id);
    final head = o.step == 4 ? '${o.field}${o.career != null ? ' · ${o.career}' : ''}' : kindLabel[o.kind]!;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(head, style: AppText.caption.copyWith(fontSize: 11)),
                const SizedBox(width: 6),
                TagBadge('D-${o.dday}', tone: o.dday <= 7 ? BadgeTone.green : BadgeTone.gray),
              ]),
              const SizedBox(height: 4),
              Text(o.title, style: AppText.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('${o.org} · ${o.region}${o.employment != null ? ' · ${o.employment}' : ''}', style: AppText.caption.copyWith(fontSize: 12)),
              if (o.period != null) Text('진행 ${o.period}', style: AppText.caption),
            ]),
          ),
          IconButton(
            tooltip: on ? '스크랩 취소' : '스크랩',
            onPressed: () {
              state.toggleScrap(o.id);
              showToast(context, on ? '스크랩을 취소했어요' : '스크랩했어요. 스크랩 탭에서 모아 볼 수 있어요');
            },
            icon: Icon(on ? Icons.bookmark : Icons.bookmark_border, color: on ? AppColors.green : AppColors.dim),
          ),
        ],
      ),
    );
  }
}
