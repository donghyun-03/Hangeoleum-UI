// 자격증 추가 창 (내 정보 · 홈 시작 가이드에서 같이 씁니다)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../common.dart';

/// 자주 따는 자격증 (눌러서 바로 넣기)
const commonCertificates = [
  '컴퓨터활용능력 1급',
  '컴퓨터활용능력 2급',
  '한국사능력검정 1급',
  '한국사능력검정 2급',
  '전산회계 1급',
  'SQLD',
  'ADsP',
  '정보처리기사',
  'GTQ 1급',
  'MOS',
];

/// 자격증 하나를 입력받습니다. 취소하면 null.
Future<Certificate?> showCertificateDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final yearCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        backgroundColor: AppColors.paper,
        surfaceTintColor: AppColors.paper,
        title: Text('자격증 추가', style: AppText.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('자주 따는 자격증', style: AppText.small.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              ChipWrap(
                children: [
                  for (final c in commonCertificates)
                    SelectChip(
                      label: c,
                      selected: nameCtrl.text == c,
                      onTap: () => setLocal(() => nameCtrl.text = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('자격증 이름', style: AppText.small.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(hintText: '예: 컴퓨터활용능력 2급'),
              ),
              const SizedBox(height: 12),
              Text('취득 연도 (선택)', style: AppText.small.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(hintText: '예: 2025'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소', style: TextStyle(color: AppColors.subtle)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('추가', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    ),
  );
  final name = nameCtrl.text.trim();
  final year = int.tryParse(yearCtrl.text);
  nameCtrl.dispose();
  yearCtrl.dispose();
  if (saved != true || name.isEmpty) return null;
  return Certificate(name: name, year: year);
}
