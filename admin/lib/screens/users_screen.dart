import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';
import '../core/widgets.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with PollingMixin {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all | active | banned
  int _page = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load();
    startPolling();
  }

  @override
  void onPoll() => _load();

  Future<void> _load() async {
    if (_users.isEmpty) setState(() => _loading = true);
    try {
      // The API enforces regular customers only — captains/admins can never appear.
      final u = await AApi.instance.get('/admin/users') as List;
      if (!mounted) return;
      setState(() {
        _users = u.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ae(e);
      });
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    try {
      final banned = user['isBanned'] == true;
      await AApi.instance.post('/admin/users/${user['id']}/toggle-ban');
      if (mounted) {
        snack(context, banned ? 'تم إلغاء حظر المستخدم' : 'تم حظر المستخدم');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final name =
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final phone = user['phone']?.toString() ?? '';
    final label = name.isNotEmpty ? '$name (${phone})' : phone;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف المستخدم نهائياً؟'),
        content: Text(
          'سيتم حذف حساب «$label» مع كل بياناته المرتبطة:\n'
          'الطلبات، العروض، المحادثات والرسائل، التقييمات، '
          'الإشعارات والشكاوى.\n\nهذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ATheme.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AApi.instance.delete('/admin/users/${user['id']}');
      if (mounted) {
        snack(context, 'تم حذف المستخدم $label');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    Iterable<Map<String, dynamic>> list = _users;
    if (_statusFilter == 'active') list = list.where((u) => u['isBanned'] != true);
    if (_statusFilter == 'banned') list = list.where((u) => u['isBanned'] == true);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((u) {
        final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.toLowerCase();
        final phone = (u['phone'] ?? '').toString();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || email.contains(q);
      });
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredUsers;
    final pageCount = (list.length / _pageSize).ceil().clamp(1, 9999);
    if (_page > pageCount) _page = pageCount;
    final pageItems = list
        .skip((_page - 1) * _pageSize)
        .take(_pageSize)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('المستخدمون (${list.length})'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _page = 1;
                    }),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم، رقم الهاتف أو البريد...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('الكل')),
                    ButtonSegment(value: 'active', label: Text('نشط')),
                    ButtonSegment(value: 'banned', label: Text('محظور')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (s) => setState(() {
                    _statusFilter = s.first;
                    _page = 1;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off, size: 44, color: ATheme.danger),
                            const SizedBox(height: 8),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : pageItems.isEmpty
                        ? const EmptyState(
                            icon: Icons.person_off_outlined,
                            message: 'لا يوجد مستخدمون مطابقون',
                          )
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                horizontalMargin: 20,
                                columns: const [
                                  DataColumn(label: Text('المستخدم')),
                                  DataColumn(label: Text('رقم الهاتف')),
                                  DataColumn(label: Text('البريد الإلكتروني')),
                                  DataColumn(label: Text('تاريخ التسجيل')),
                                  DataColumn(label: Text('الحالة')),
                                  DataColumn(label: Text('الإجراءات')),
                                ],
                                rows: pageItems.map((u) {
                                  final banned = u['isBanned'] == true;
                                  final phone =
                                      (u['phone']?.toString().isNotEmpty == true) ? u['phone'].toString() : '-';
                                  final email =
                                      (u['email']?.toString().isNotEmpty == true) ? u['email'].toString() : '-';
                                  final createdAt = u['createdAt'] != null
                                      ? u['createdAt'].toString().split('T').first
                                      : '-';
                                  final name =
                                      '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();

                                  return DataRow(
                                    onSelectChanged: (_) => context.go('/admin/users/${u['id']}'),
                                    cells: [
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: ATheme.primary.withValues(alpha: .1),
                                              child: const Icon(Icons.person, size: 18, color: ATheme.primary),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              name.isEmpty ? 'مستخدم بدون اسم' : name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        SelectableText(
                                          phone,
                                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataCell(Text(email, style: const TextStyle(color: Colors.black87))),
                                      DataCell(Text(createdAt, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                      DataCell(StatusBadge(label: banned ? 'محظور' : 'نشط', danger: banned)),
                                      DataCell(
                                        Row(
                                          children: [
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                foregroundColor: banned ? ATheme.primary : ATheme.danger,
                                              ),
                                              icon: Icon(banned ? Icons.lock_open : Icons.block, size: 16),
                                              label: Text(banned ? 'إلغاء الحظر' : 'حظر'),
                                              onPressed: () => _toggleBan(u),
                                            ),
                                            IconButton(
                                              tooltip: 'حذف المستخدم',
                                              icon: const Icon(Icons.delete_outline, size: 19, color: ATheme.danger),
                                              onPressed: () => _deleteUser(u),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
          ),
          if (!_loading && pageCount > 1)
            PaginationBar(
              page: _page,
              pageCount: pageCount,
              onChanged: (p) => setState(() => _page = p),
            ),
        ],
      ),
    );
  }
}
