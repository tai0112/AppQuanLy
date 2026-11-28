import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../providers.dart';

/// Quản lý danh mục thu/chi 2 cấp: thêm, sửa, xoá, kéo thả sắp xếp.
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key, this.initialType = 1});
  final int initialType;

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  late int type = widget.initialType;

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(financeProvider);
    final cats = f.categories.where((c) => c.type == type).toList();
    final roots = cats.where((c) => c.parentId == null).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editCategory(context, ref, type: type),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          // Chọn loại danh mục: thanh trượt chia đều, mỗi loại một màu, kèm số danh mục chính
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: SegmentTabs<int>(
              value: type,
              values: const [1, 2, 3, 4],
              labels: const ['Khoản chi', 'Khoản thu', 'Lịch trình', 'Hoạt động'],
              icons: const [Icons.north_east_rounded, Icons.south_west_rounded, Icons.event_rounded, Icons.schedule_rounded],
              colors: _typeColors,
              counts: [
                for (final v in const [1, 2, 3, 4]) f.categories.where((c) => c.type == v && c.parentId == null).length,
              ],
              vertical: true,
              height: 64,
              onChanged: (v) => setState(() => type = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${roots.length} danh mục chính · ${cats.length - roots.length} mục con · giữ ⋮⋮ để sắp xếp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                  child: c,
                ),
              ),
              child: ReorderableListView.builder(
                key: ValueKey(type),
                buildDefaultDragHandles: false,
                proxyDecorator: liftOnDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: roots.length,
                onReorder: (oldI, newI) {
                  final list = [...roots];
                  final item = list.removeAt(oldI);
                  list.insert(newI > oldI ? newI - 1 : newI, item);
                  final store = ref.read(storeProvider);
                  for (final (i, c) in list.indexed) {
                    if (c.sortOrder != i * 100) store.put(E.categories, {...c.m, 'sortOrder': i * 100}, notify: i == list.length - 1);
                  }
                },
                itemBuilder: (c, i) {
                  final root = roots[i];
                  final children = cats.where((x) => x.parentId == root.id).toList();
                  return Padding(
                    key: ValueKey(root.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RootCard(
                      root: root,
                      children: children,
                      index: i,
                      onEdit: (c) => editCategory(context, ref, type: type, existing: c, parent: c.id == root.id ? null : root),
                      onAddChild: () => editCategory(context, ref, type: type, parent: root),
                    ),
                  ).stagger(i).withKey(ValueKey('wrap-${root.id}'));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Từ khoá tiếng Việt để tìm icon (gõ không dấu cũng được).
const _iconWords = <String, String>{
  'restaurant': 'an uong nha hang com bun pho',
  'local_cafe': 'ca phe cafe tra sang',
  'directions_car': 'xe o to taxi grab di chuyen',
  'two_wheeler': 'xe may di lai',
  'local_gas_station': 'xang dau',
  'home': 'nha cua gia dinh',
  'bolt': 'dien',
  'water_drop': 'nuoc',
  'wifi': 'internet mang wifi',
  'shopping_bag': 'mua sam shopping',
  'checkroom': 'quan ao thoi trang',
  'movie': 'phim giai tri rap',
  'sports_esports': 'game choi',
  'favorite': 'yeu hen ho tim',
  'local_hospital': 'benh vien suc khoe y te',
  'school': 'hoc tap truong',
  'card_giftcard': 'qua tang',
  'pets': 'thu cung cho meo',
  'flight': 'may bay du lich',
  'phone_iphone': 'dien thoai vi',
  'fitness_center': 'tap gym the duc the thao',
  'child_care': 'con cai tre em',
  'payments': 'tien mat luong',
  'work': 'cong viec lam',
  'trending_up': 'dau tu thu',
  'redeem': 'thuong',
  'sell': 'ban',
  'savings': 'tiet kiem heo',
  'account_balance': 'ngan hang',
  'credit_card': 'the tin dung',
  'beach_access': 'bien di choi',
  'celebration': 'tiec le',
  'spa': 'thu gian spa nghi',
  'local_grocery_store': 'cho sieu thi di cho',
  'medication': 'thuoc',
  'build': 'sua chua do gia dung',
  'book': 'sach doc',
  'music_note': 'nhac',
  'camera': 'chup anh tham quan',
  'diamond': 'trang suc',
  'house': 'nha thue tro',
  'directions_bus': 'xe buyt',
  'hotel': 'khach san check in',
  'park': 'cong vien',
  'nightlife': 'bar dem',
  'restaurant_menu': 'an',
  'sports_soccer': 'bong da',
  'church': 'nha tho chua',
  'event': 'su kien lich',
};

const _typeNames = {1: 'Khoản chi', 2: 'Khoản thu', 3: 'Lịch trình', 4: 'Mẫu hoạt động'};
const _typeColors = [AppColors.expense, AppColors.income, AppColors.transfer, Color(0xFF8E4EC6)];

/// Thẻ danh mục chính: bấm để mở / thu gọn; mục con hiện dạng thẻ nhỏ (bấm để sửa), cuối cùng là ô "Thêm mục con".
class _RootCard extends StatefulWidget {
  const _RootCard({required this.root, required this.children, required this.index, required this.onEdit, required this.onAddChild});
  final Category root;
  final List<Category> children;
  final int index;
  final ValueChanged<Category> onEdit;
  final VoidCallback onAddChild;

  @override
  State<_RootCard> createState() => _RootCardState();
}

class _RootCardState extends State<_RootCard> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final root = widget.root;
    final color = hexColor(root.color);
    final kids = widget.children;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => setState(() => open = !open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                children: [
                  CircleIcon(icon: root.icon, color: color, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          root.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(kids.isEmpty ? 'Chưa có mục con' : '${kids.length} mục con', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1), foregroundColor: color),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => widget.onEdit(root),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
                  ),
                  DragHandle(index: widget.index),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ch in kids) _ChildChip(cat: ch, onTap: () => widget.onEdit(ch)),
                        _AddChildChip(color: color, onTap: widget.onAddChild),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({required this.cat, required this.onTap});
  final Category cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = hexColor(cat.color);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleIcon(icon: cat.icon, color: color, size: 26),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChildChip extends StatelessWidget {
  const _AddChildChip({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            'Thêm mục con',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    ),
  );
}

/// Thêm / sửa danh mục: xem trước trực tiếp, chọn nhóm cha, màu, icon (tìm bằng tiếng Việt), nút lưu cố định ở đáy.
Future<void> editCategory(BuildContext context, WidgetRef ref, {required int type, Category? existing, Category? parent}) async {
  final name = TextEditingController(text: existing?.name);
  final search = TextEditingController();
  var icon = existing?.icon ?? parent?.icon ?? 'more_horiz';
  var color = hexColor(existing?.color ?? parent?.color, AppColors.palette[5]);
  var parentId = existing?.parentId ?? parent?.id;
  final f = ref.read(financeProvider);
  final roots = f.categories.where((c) => c.type == type && c.parentId == null && c.id != existing?.id).toList();
  final hasChildren = existing != null && f.categories.any((c) => c.parentId == existing.id);

  await showModalBottomSheet(
    sheetAnimationStyle: kSheetAnim,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          final parentName = roots.where((r) => r.id == parentId).firstOrNull?.name;
          final q = Fmt.fold(search.text.trim());
          final icons = appIcons.entries.where((e) => q.isEmpty || e.key.contains(q) || (_iconWords[e.key] ?? '').contains(q)).toList();

          void save() {
            if (name.text.trim().isEmpty) return showToast(ctx, 'Nhập tên danh mục', error: true);
            final store = ref.read(storeProvider);
            store.put(E.categories, {
              if (existing != null) ...existing.m,
              'name': name.text.trim(),
              'type': type,
              'icon': icon,
              'color': colorHex(color),
              'parentId': hasChildren ? null : parentId,
              'sortOrder': existing?.sortOrder ?? store.all(E.categories).length * 100,
            });
            HapticFeedback.lightImpact();
            Navigator.pop(ctx);
          }

          return Column(
            children: [
              // Tiêu đề
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(existing == null ? 'Thêm danh mục' : 'Sửa danh mục', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    // Xem trước trực tiếp
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.06)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                              child: Icon(iconOf(icon), key: ValueKey(icon), color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ValueListenableBuilder(
                                  valueListenable: name,
                                  builder: (_, v, __) => Text(
                                    v.text.trim().isEmpty ? 'Tên danh mục' : v.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: v.text.trim().isEmpty ? scheme.onSurfaceVariant : null),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_typeNames[type]}${parentName != null && !hasChildren ? ' · trong "$parentName"' : ' · danh mục chính'}',
                                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: name,
                      autofocus: existing == null,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(labelText: 'Tên danh mục', prefixIcon: Icon(Icons.edit_rounded)),
                    ),

                    // Nhóm cha
                    if (!hasChildren && roots.isNotEmpty) ...[
                      const _Label('Thuộc nhóm'),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _Choice(
                              label: 'Danh mục chính',
                              icon: Icons.layers_rounded,
                              selected: parentId == null,
                              color: color,
                              onTap: () => set(() => parentId = null),
                            ),
                            for (final r in roots)
                              _Choice(
                                label: r.name,
                                icon: iconOf(r.icon),
                                selected: parentId == r.id,
                                color: hexColor(r.color),
                                onTap: () => set(() => parentId = r.id),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (hasChildren)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('Danh mục này đang có mục con nên luôn là danh mục chính.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ),

                    const _Label('Màu'),
                    ColorPickerRow(value: color, size: 32, onChanged: (c) => set(() => color = c)),

                    const _Label('Biểu tượng'),
                    TextField(
                      controller: search,
                      onChanged: (_) => set(() {}),
                      decoration: const InputDecoration(hintText: 'Tìm icon: ăn, xe, nhà, học...', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                    ),
                    const SizedBox(height: 10),
                    if (icons.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text('Không tìm thấy icon', style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: icons.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8),
                        itemBuilder: (c, i) {
                          final e = icons[i];
                          final sel = e.key == icon;
                          return Pressable(
                            onTap: () => set(() => icon = e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: sel ? color : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : null,
                              ),
                              child: Icon(e.value, color: sel ? Colors.white : scheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // Nút cố định ở đáy: ẩn khi bàn phím mở, hiện lại khi đóng; phần đệm đáy đẩy danh sách lên trên bàn phím
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
                child: KeyboardHideable(
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        if (existing != null) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.expense,
                              minimumSize: const Size(64, 50),
                              side: const BorderSide(color: AppColors.expense),
                            ),
                            onPressed: () async {
                              if (await confirm(
                                ctx,
                                'Xoá "${existing.name}"?',
                                message: 'Các mục con cũng bị xoá. Giao dịch cũ vẫn giữ nguyên.',
                                danger: true,
                                ok: 'Xoá',
                              )) {
                                final store = ref.read(storeProvider);
                                store.remove(E.categories, existing.id);
                                for (final ch in store.all(E.categories).where((c) => c['parentId'] == existing.id)) {
                                  store.remove(E.categories, ch['id'] as String);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Xoá'),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.check_rounded), label: const Text('Lưu')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.icon, required this.selected, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: selected ? color : scheme.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
