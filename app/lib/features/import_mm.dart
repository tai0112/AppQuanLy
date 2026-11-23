import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/mm_import.dart';
import '../providers.dart';

enum _Step { idle, reading, preview, saving, done, error }

/// Nhập dữ liệu từ file sao lưu Money Manager (.mmbackup).
/// File được đọc NGAY TRÊN MÁY. Người dùng chọn: chỉ lưu trên máy, hoặc lưu và đồng bộ lên máy chủ.
/// Dữ liệu "chỉ lưu trên máy" có thể đồng bộ lên sau bằng nút ở cuối trang.
class MoneyManagerImportPage extends ConsumerStatefulWidget {
  const MoneyManagerImportPage({super.key});

  @override
  ConsumerState<MoneyManagerImportPage> createState() => _MoneyManagerImportPageState();
}

class _MoneyManagerImportPageState extends ConsumerState<MoneyManagerImportPage> {
  _Step step = _Step.idle;
  String? fileName;
  String? error;
  MmBackup? backup;
  MmImportResult? result;
  bool savedLocalOnly = false;
  (int, int)? photoProgress;

  bool get _busy => step == _Step.reading || step == _Step.saving;

  Future<void> _pick() async {
    final f = (await FilePicker.pickFiles(type: FileType.any)).firstOrNull;
    if (f == null) return;
    if (!f.name.toLowerCase().endsWith('.mmbackup')) {
      if (mounted) showToast(context, 'Hãy chọn file có đuôi .mmbackup', error: true);
      return;
    }
    setState(() {
      fileName = f.name;
      step = _Step.reading;
      error = null;
      backup = null;
      result = null;
    });
    try {
      final bytes = await f.readAsBytes();
      await Future<void>.delayed(const Duration(milliseconds: 16)); // để vòng quay kịp hiện trước khi đọc
      final b = MmBackup.parse(bytes);
      if (!mounted) return;
      setState(() {
        backup = b;
        step = _Step.preview;
      });
    } on FormatException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Không đọc được file: $e');
    }
  }

  Future<void> _save({required bool localOnly}) async {
    final b = backup;
    if (b == null) return;
    setState(() {
      step = _Step.saving;
      photoProgress = null;
    });
    try {
      final store = ref.read(storeProvider);
      final r = await importMoneyManager(
        store,
        b,
        localOnly: localOnly,
        onPhoto: (d, t) {
          if (mounted) setState(() => photoProgress = (d, t));
        },
      );
      if (!localOnly) ref.read(syncProvider).sync();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        result = r;
        savedLocalOnly = localOnly;
        backup = null; // giải phóng bộ nhớ của file đã đọc
        step = _Step.done;
      });
    } catch (e) {
      _fail('Lưu dữ liệu lỗi: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      step = _Step.error;
      error = message;
      backup = null;
    });
  }

  Future<void> _promote(int count) async {
    final loggedIn = ref.read(sessionProvider).isLoggedIn;
    if (!loggedIn) {
      showToast(context, 'Cần đăng nhập để đồng bộ lên máy chủ', error: true);
      return;
    }
    if (!await confirm(
      context,
      'Đồng bộ lên máy chủ?',
      message: '$count bản ghi đang chỉ lưu trên máy (kèm ảnh) sẽ được đẩy lên máy chủ và có trên mọi thiết bị đăng nhập tài khoản này.',
      ok: 'Đồng bộ',
    )) {
      return;
    }
    ref.read(storeProvider).promoteLocalOnly();
    ref.read(syncProvider).sync();
    if (mounted) showToast(context, 'Đang đồng bộ lên máy chủ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nhập từ Money Manager')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: const Color(0xFFF76B15).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.move_to_inbox_rounded, color: Color(0xFFF76B15)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Chuyển dữ liệu sang LHT Money', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _Bullet('Trong Money Manager: Cài đặt → Sao lưu → tạo bản sao lưu, rồi chép file .mmbackup sang máy này.'),
                  const _Bullet('File được đọc ngay trên máy. Bạn xem trước rồi chọn chỉ lưu trên máy hay đồng bộ lên máy chủ.'),
                  const _Bullet('Nhập tài khoản (giữ đúng số dư), danh mục, giao dịch, chuyển khoản và ảnh đính kèm.'),
                  const _Bullet('Nhập lại cùng file không tạo bản trùng. Tài khoản / danh mục trùng tên được dùng chung.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: c),
              ),
              child: switch (step) {
                _Step.reading => _busyCard('Đang đọc file…', null),
                _Step.saving => _busyCard(
                  photoProgress == null ? 'Đang lưu dữ liệu…' : 'Đang lưu ảnh ${photoProgress!.$1}/${photoProgress!.$2}…',
                  photoProgress == null || photoProgress!.$2 == 0 ? null : photoProgress!.$1 / photoProgress!.$2,
                ),
                _Step.preview => _previewCard(scheme),
                _Step.done => _resultCard(scheme),
                _Step.error => _errorCard(scheme),
                _Step.idle => const SizedBox.shrink(key: ValueKey('idle')),
              },
            ),
            if (step != _Step.preview) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.file_open_rounded),
                label: Text(step == _Step.done ? 'Nhập file khác' : 'Chọn file .mmbackup'),
              ),
            ],
            _localOnlyCard(scheme),
          ],
        ),
      ),
    );
  }

  Widget _busyCard(String text, double? value) => AppCard(
    key: const ValueKey('busy'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fileName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: value == null
              ? const LinearProgressIndicator(minHeight: 6)
              : TweenAnimationBuilder<double>(
                  tween: Tween(end: value),
                  duration: const Duration(milliseconds: 200),
                  builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6),
                ),
        ),
      ],
    ),
  );

  Widget _previewCard(ColorScheme scheme) {
    final b = backup!;
    final range = b.dateRange;
    final loggedIn = ref.watch(sessionProvider).isLoggedIn;
    final missing = b.photoLinks - b.photosAvailable;
    return AppCard(
      key: const ValueKey('preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fileName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (range != null) Text('${Fmt.dateShort(range.$1)} – ${Fmt.dateShort(range.$2)}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          _Line(Icons.receipt_long_rounded, 'Giao dịch', '${b.transactions.length}'),
          if (b.transfers.isNotEmpty) _Line(Icons.swap_horiz_rounded, 'Chuyển khoản', '${b.transfers.length}'),
          _Line(Icons.account_balance_wallet_rounded, 'Tài khoản', b.accounts.map((a) => a.title).where((t) => t.isNotEmpty).join(', ')),
          _Line(Icons.category_rounded, 'Danh mục', '${b.categories.length}'),
          _Line(Icons.photo_library_rounded, 'Ảnh có trong file', '${b.photosAvailable}'),
          if (missing > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$missing ảnh không nằm trong file sao lưu (Money Manager chỉ giữ chúng trên đám mây của họ) nên sẽ không nhập được.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 14),
          const Text('Lưu dữ liệu này ở đâu?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: Icons.phone_iphone_rounded,
            title: 'Chỉ lưu trên máy này',
            subtitle: 'Không gửi lên máy chủ. Có thể đồng bộ lên sau.',
            onTap: () => _save(localOnly: true),
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Lưu & đồng bộ lên máy chủ',
            subtitle: loggedIn ? 'Có trên mọi thiết bị đăng nhập tài khoản này, kể cả ảnh.' : 'Cần đăng nhập để dùng lựa chọn này.',
            primary: true,
            onTap: loggedIn ? () => _save(localOnly: false) : null,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {
              step = _Step.idle;
              backup = null;
            }),
            child: const Text('Huỷ'),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(ColorScheme scheme) => AppCard(
    key: const ValueKey('error'),
    color: scheme.errorContainer,
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
        const SizedBox(width: 12),
        Expanded(
          child: Text(error ?? 'Có lỗi xảy ra', style: TextStyle(color: scheme.onErrorContainer)),
        ),
      ],
    ),
  );

  Widget _resultCard(ColorScheme scheme) {
    final r = result!;
    final nothingNew = r.transactions + r.transfers == 0 && r.skipped > 0;
    final sync = ref.watch(syncProvider);
    final fp = sync.fileProgress;
    return AppCard(
      key: const ValueKey('done'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF30A46C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nothingNew ? 'Không có gì mới — file này đã được nhập trước đó' : (savedLocalOnly ? 'Đã lưu trên máy' : 'Đã lưu & đang đồng bộ'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Line(Icons.receipt_long_rounded, 'Giao dịch', '${r.transactions}'),
          if (r.transfers > 0) _Line(Icons.swap_horiz_rounded, 'Chuyển khoản', '${r.transfers}'),
          _Line(Icons.account_balance_wallet_rounded, 'Tài khoản', '${r.accountsCreated} mới · ${r.accountsMatched} dùng lại'),
          _Line(Icons.category_rounded, 'Danh mục', '${r.categoriesCreated} mới · ${r.categoriesMatched} dùng lại'),
          _Line(Icons.photo_library_rounded, 'Ảnh', '${r.photos}'),
          if (r.skipped > 0) _Line(Icons.content_copy_rounded, 'Bỏ qua (đã có)', '${r.skipped}'),
          if (!savedLocalOnly) ...[
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                fp != null
                    ? 'Đang đồng bộ ảnh ${fp.$1}/${fp.$2}…'
                    : sync.pending > 0
                    ? 'Còn ${sync.pending} mục chờ đồng bộ lên máy chủ…'
                    : sync.lastError == null
                    ? 'Đã đồng bộ lên máy chủ.'
                    : 'Đồng bộ chưa xong (${sync.lastError}). Sẽ tự thử lại.',
                key: ValueKey('${fp != null}-${sync.pending > 0}-${sync.lastError}'),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Dữ liệu đang chỉ lưu trên máy (từ các lần nhập trước) → cho phép đồng bộ lên.
  Widget _localOnlyCard(ColorScheme scheme) {
    final store = ref.watch(storeProvider);
    final counts = store.localOnlyCounts();
    final total = counts.values.fold(0, (a, b) => a + b);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: total == 0 || _busy
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_iphone_rounded, color: scheme.primary),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Đang chỉ lưu trên máy này', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (counts[E.transactions] case final n?) '$n giao dịch',
                        if (counts[E.accounts] case final n?) '$n tài khoản',
                        if (counts[E.categories] case final n?) '$n danh mục',
                        if (counts[E.attachments] case final n?) '$n ảnh',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text('Dữ liệu này sẽ mất nếu đăng xuất hoặc xoá app trước khi đồng bộ.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _promote(total),
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: const Text('Đồng bộ lên máy chủ'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.primary = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = primary && enabled ? scheme.onPrimary : scheme.onSurface;
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: primary && enabled ? scheme.primary : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w700, color: fg),
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
          ),
        ),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
