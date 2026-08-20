import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with PollingMixin {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    startPolling();
  }

  @override
  void onPoll() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final u = await AApi.instance.get('/admin/users', query: {'role': 'customer'}) as List;
      if (!mounted) return;
      setState(() {
        _users = u
            .cast<Map<String, dynamic>>()
            .where((usr) => usr['role'] == 'customer' || usr['role'] == null || usr['role'] == '')
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _users;
    final q = _searchQuery.trim().toLowerCase();
    return _users.where((u) {
      final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.toLowerCase();
      final phone = (u['phone'] ?? '').toString();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredUsers;

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة المستخدمين العاديين (${_users.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، رقم الهاتف، أو البريد الإلكتروني...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: list.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'لا يوجد مستخدمون عاديون مضافون حالياً',
                                  style: TextStyle(color: Colors.grey, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('المستخدم')),
                                  DataColumn(label: Text('رقم الهاتف')),
                                  DataColumn(label: Text('البريد الإلكتروني')),
                                  DataColumn(label: Text('تاريخ الانضمام')),
                                  DataColumn(label: Text('الحالة')),
                                  DataColumn(label: Text('الإجراءات')),
                                ],
                                rows: list.map((u) {
                                  final banned = u['isBanned'] == true;
                                  final phone = (u['phone']?.toString().isNotEmpty == true) ? u['phone'].toString() : '-';
                                  final email = (u['email']?.toString().isNotEmpty == true) ? u['email'].toString() : '-';
                                  final createdAt = u['createdAt'] != null
                                      ? u['createdAt'].toString().split('T').first
                                      : '-';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: ATheme.primary.withValues(alpha: .1),
                                              child: const Icon(
                                                Icons.person,
                                                size: 18,
                                                color: ATheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().isEmpty
                                                  ? 'مستخدم بدون اسم'
                                                  : '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}',
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
                                      DataCell(
                                        Text(email, style: const TextStyle(color: Colors.black87)),
                                      ),
                                      DataCell(
                                        Text(createdAt, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ),
                                      DataCell(
                                        Chip(
                                          label: Text(banned ? 'محظور' : 'نشط'),
                                          backgroundColor: (banned ? Colors.red : Colors.green).withValues(alpha: .12),
                                          labelStyle: TextStyle(
                                            color: banned ? Colors.red : Colors.green,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      DataCell(
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            foregroundColor: banned ? ATheme.primary : ATheme.danger,
                                          ),
                                          icon: Icon(banned ? Icons.lock_open : Icons.block, size: 16),
                                          label: Text(banned ? 'إلغاء الحظر' : 'حظر الحساب'),
                                          onPressed: () => _toggleBan(u),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}