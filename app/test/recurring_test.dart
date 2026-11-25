import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lht_money/core/format.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/data/logic.dart';
import 'package:lht_money/data/models.dart';

void main() {
  group('Recurrence.nextOccurrence', () {
    test('DAILY với interval = 2', () {
      final from = DateTime(2026, 11, 25, 9, 30);
      final next = Recurrence.nextOccurrence('FREQ=DAILY;INTERVAL=2', from);
      expect(next, DateTime(2026, 11, 27, 9, 30));
    });

    test('WEEKLY chọn nhiều thứ (T2, T5)', () {
      // 2026-11-25 là Thứ 4 (weekday = 3)
      final from = DateTime(2026, 11, 25, 8, 0);
      final next1 = Recurrence.nextOccurrence('FREQ=WEEKLY;BYDAY=MO,TH', from);
      expect(next1, DateTime(2026, 11, 26, 8, 0)); // Thứ 5
      final next2 = Recurrence.nextOccurrence('FREQ=WEEKLY;BYDAY=MO,TH', next1);
      expect(next2, DateTime(2026, 11, 30, 8, 0)); // Thứ 2 tuần sau
    });

    test('MONTHLY kẹp ngày cuối tháng (31/01 -> 28/02)', () {
      final from = DateTime(2026, 1, 31, 10, 0);
      final next = Recurrence.nextOccurrence('FREQ=MONTHLY', from);
      expect(next, DateTime(2026, 2, 28, 10, 0));
    });

    test('YEARLY kẹp 29/02 -> 28/02 năm thường', () {
      final from = DateTime(2024, 2, 29, 7, 0);
      final next = Recurrence.nextOccurrence('FREQ=YEARLY', from);
      expect(next, DateTime(2025, 2, 28, 7, 0));
    });
  });

  group('runDueRecurringRules', () {
    test('tự sinh các kỳ đến hạn và chống trùng tuyệt đối khi chạy lại', () async {
      final tempDir = await Directory.systemTemp.createTemp('lht_test_rec_');
      Hive.init(tempDir.path);
      final store = LocalStore();
      await store.initForTest(filesDir: '${tempDir.path}/files');

      final acc = store.put(E.accounts, {'name': 'Ví chính', 'type': 1, 'currencyCode': 'VND'});
      final cat = store.put(E.categories, {'name': 'Tiền nhà', 'type': 1});

      final rule = store.put(E.recurringRules, {
        'name': 'Tiền nhà',
        'templateJson': jsonEncode({
          'type': TxType.expense,
          'amount': 3500000,
          'currencyCode': 'VND',
          'accountId': acc['id'],
          'categoryId': cat['id'],
        }),
        'rRule': 'FREQ=DAILY',
        'nextRunAt': toIso8601WithOffset(DateTime(2026, 11, 23, 8, 0)),
        'isActive': true,
      });

      final now = DateTime(2026, 11, 25, 10, 0);
      final created1 = runDueRecurringRules(store, now: now);
      expect(created1, 3); // 23, 24, 25
      expect(store.all(E.transactions).length, 3);

      final updatedRule = RecurringRule(store.get(E.recurringRules, rule['id'])!);
      expect(updatedRule.nextRunAt.toLocal().day, 26);

      // Chạy lại cùng thời điểm hoặc đặt lùi nextRunAt về 23 -> vẫn không sinh trùng
      final created2 = runDueRecurringRules(store, now: now);
      expect(created2, 0);
      expect(store.all(E.transactions).length, 3);
    });
  });
}
