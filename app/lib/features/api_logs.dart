import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/api.dart';
import '../data/session.dart';
import '../providers.dart';

class ApiLogsPage extends ConsumerStatefulWidget {
  const ApiLogsPage({super.key});

  @override
  ConsumerState<ApiLogsPage> createState() => _ApiLogsPageState();
}

class _ApiLogsPageState extends ConsumerState<ApiLogsPage> {
  bool loading = true;
  List<Map<String, dynamic>> logs = [];
  Map<String, dynamic>? stats;
  int page = 1;
  int pageSize = 25;
  int totalCount = 0;
  int totalPages = 1;

  final search = TextEditingController();
  String? methodFilter;
  int? statusFilter;
  bool onlyErrors = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final api = ref.read(apiProvider);
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
        if (methodFilter != null) 'method': methodFilter,
        if (statusFilter != null) 'statusCode': statusFilter,
        if (onlyErrors) 'onlyErrors': true,
      };

      final results = await Future.wait([
        api.get<Map<String, dynamic>>('/admin/logs', query: queryParams),
        api.get<Map<String, dynamic>>('/admin/logs/stats'),
      ]);

      final logData = results[0];
      final statsData = results[1];

      if (!mounted) return;
      setState(() {
        logs = (logData['items'] as List).cast<Map<String, dynamic>>();
        totalCount = (logData['totalCount'] as num).toInt();
        totalPages = (logData['totalPages'] as num).toInt();
        stats = statsData;
        loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showToast(context, e.message, error: true);
      }
    }
  }

  Future<void> _clearLogs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dọn dẹp nhật ký cũ'),
        content: const Text('Hành động này sẽ xoá các bản ghi nhật ký API cũ hơn 30 ngày. Tiếp tục?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final api = ref.read(apiProvider);
      final deleted = await api.delete<dynamic>('/admin/logs?keepDays=30');
      if (mounted) {
        showToast(context, 'Đã dọn dẹp $deleted bản ghi nhật ký');
        _fetch();
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Color _methodColor(String method) => switch (method.toUpperCase()) {
    'GET' => const Color(0xFF2563EB),
    'POST' => const Color(0xFF16A34A),
    'PUT' => const Color(0xFFD97706),
    'DELETE' => const Color(0xFFDC2626),
    'PATCH' => const Color(0xFF9333EA),
    _ => const Color(0xFF6B7280),
  };

  Color _statusColor(int code) {
    if (code >= 500) return const Color(0xFFDC2626);
    if (code >= 400) return const Color(0xFFF97316);
    if (code >= 300) return const Color(0xFF0891B2);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (!session.can(Perm.qtNhatKy) && !session.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nhật ký hệ thống')),
        body: const EmptyState(icon: Icons.lock_rounded, title: 'Bạn không có quyền xem nhật ký hệ thống'),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật ký hệ thống & API'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
          IconButton(
            tooltip: 'Dọn dẹp nhật ký cũ',
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Thống kê nhanh
          if (stats != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tổng gọi (hôm nay)', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text('${stats!['todayRequests']} / ${stats!['totalRequests']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lỗi hôm nay', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(
                            '${stats!['todayErrors']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: (stats!['todayErrors'] as num) > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Độ trễ trung bình', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text('${stats!['avgDurationMs']} ms', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Thanh tìm kiếm & bộ lọc
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                hintText: 'Tìm theo URL, tài khoản, IP, thông báo lỗi...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          search.clear();
                          page = 1;
                          _fetch();
                        },
                      )
                    : null,
                isDense: true,
              ),
              onSubmitted: (_) {
                page = 1;
                _fetch();
              },
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Chỉ lỗi (≥400)'),
                  selected: onlyErrors,
                  onSelected: (v) {
                    setState(() {
                      onlyErrors = v;
                      page = 1;
                    });
                    _fetch();
                  },
                ),
                const SizedBox(width: 8),
                for (final m in ['GET', 'POST', 'PUT', 'DELETE']) ...[
                  ChoiceChip(
                    label: Text(m),
                    selected: methodFilter == m,
                    onSelected: (sel) {
                      setState(() {
                        methodFilter = sel ? m : null;
                        page = 1;
                      });
                      _fetch();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Danh sách log
          Expanded(
            child: loading
                ? const SkeletonList()
                : logs.isEmpty
                ? const EmptyState(icon: Icons.history_rounded, title: 'Không tìm thấy nhật ký API nào')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = logs[i];
                      final method = item['method'] as String? ?? 'GET';
                      final path = item['path'] as String? ?? '';
                      final status = (item['statusCode'] as num?)?.toInt() ?? 200;
                      final duration = (item['durationMs'] as num?)?.toInt() ?? 0;
                      final user = item['username'] as String?;
                      final ip = item['ipAddress'] as String?;
                      final createdAt = item['createdAt'] as String?;
                      final dt = createdAt != null ? DateTime.tryParse(createdAt)?.toLocal() : null;

                      return AppCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () => _showDetail(item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _methodColor(method).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    method,
                                    style: TextStyle(
                                      color: _methodColor(method),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$status',
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '${duration}ms',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: duration > 1000
                                        ? const Color(0xFFDC2626)
                                        : duration > 400
                                        ? const Color(0xFFD97706)
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(user ?? 'Khách', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                if (ip != null) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.router_outlined, size: 14, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(ip, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                ],
                                const Spacer(),
                                if (dt != null)
                                  Text(
                                    Fmt.dateTime(dt),
                                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Thanh chuyển trang
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Text('Trang $page / $totalPages (Tổng $totalCount)', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: page > 1
                        ? () {
                            setState(() => page--);
                            _fetch();
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: page < totalPages
                        ? () {
                            setState(() => page++);
                            _fetch();
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final method = item['method'] as String? ?? 'GET';
    final path = item['path'] as String? ?? '';
    final query = item['queryString'] as String?;
    final status = (item['statusCode'] as num?)?.toInt() ?? 200;
    final duration = (item['durationMs'] as num?)?.toInt() ?? 0;
    final user = item['username'] as String?;
    final ip = item['ipAddress'] as String?;
    final userAgent = item['userAgent'] as String?;
    final reqBody = item['requestBody'] as String?;
    final resBody = item['responseBody'] as String?;
    final err = item['errorMessage'] as String?;
    final createdAt = item['createdAt'] as String?;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết yêu cầu API'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _methodColor(method).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      method,
                      style: TextStyle(color: _methodColor(method), fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'HTTP $status',
                      style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  Text('${duration}ms', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              _field('Đường dẫn', '$path${query ?? ''}', copyable: true),
              _field('Thời điểm', createdAt ?? ''),
              _field('Người dùng', user ?? 'Khách'),
              _field('Địa chỉ IP', ip ?? 'Không rõ'),
              if (userAgent != null) _field('User Agent', userAgent),
              if (reqBody != null && reqBody.isNotEmpty) ...[
                const SizedBox(height: 12),
                _jsonBlock('Dữ liệu gửi lên (Request Body)', reqBody),
              ],
              if (resBody != null && resBody.isNotEmpty) ...[
                const SizedBox(height: 12),
                _jsonBlock('Phản hồi từ máy chủ (Response Body)', resBody),
              ],
              if (err != null && err.isNotEmpty) ...[
                const SizedBox(height: 12),
                _jsonBlock('Chi tiết lỗi (Exception)', err, isError: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value, {bool copyable = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (copyable)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              showToast(context, 'Đã chép vào bộ nhớ tạm');
            },
          ),
      ],
    ),
  );

  Widget _jsonBlock(String title, String content, {bool isError = false}) {
    String pretty = content;
    try {
      final decoded = jsonDecode(content);
      pretty = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isError ? Colors.red : null)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                showToast(context, 'Đã sao chép nội dung');
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isError ? Colors.red.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isError ? Colors.red.withValues(alpha: 0.3) : Colors.black12),
          ),
          child: SelectableText(
            pretty,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: isError ? Colors.red.shade900 : null,
            ),
          ),
        ),
      ],
    );
  }
}

