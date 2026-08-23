import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // The users list is customers-only; find the user inside it.
      final list = await AApi.instance.get('/admin/users') as List;
      final match = list.cast<Map<String, dynamic>>().firstWhere(
            (u) => u['id']?.toString() == widget.userId,
            orElse: () => <String, dynamic>{},
          );
      if (!mounted) return;
      if (match.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'لم يتم العثور على المستخدم (قد يكون حذف سائقاً أو حساباً إدارياً)';
        });
        return;
      }
      setState(() {
        _user = match;
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

  Future<void> _delete() async {
    final user = _user!;
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final phone = user['phone']?.toString() ?? '';
    final label = name.isNotEmpty ? '$name ($phone)' : phone;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف المستخدم نهائياً؟'),
        content: Text(
          'سيتم حذف حساب «$label» مع كل بياناته المرتبطة:\n'
          'الطلبات، العروض، المحادثات والرسائل، التقييمات، الإشعارات والشكاوى.\n\n'
          'هذا الإجراء لا يمكن التراجع عنه.',
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
      await AApi.instance.delete('/admin/users/${widget.userId}');
      if (!mounted) return;
      snack(context, 'تم حذف المستخدم $label');
      context.go('/admin/users');
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 44, color: ATheme.danger),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => context.go('/admin/users'), child: const Text('رجوع للمستخدمين')),
                ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SectionCard(title: 'بيانات المستخدم', children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: ATheme.primary.withValues(alpha: .1),
                          child: const Icon(Icons.person, color: ATheme.primary, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_user!['firstName'] ?? ''} ${_user!['lastName'] ?? ''}'.trim(),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                              StatusBadge(
                                label: _user!['isBanned'] == true ? 'محظور' : 'نشط',
                                danger: _user!['isBanned'] == true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 26),
                    InfoRow(label: 'رقم الهاتف', value: _user!['phone']?.toString() ?? '-'),
                    InfoRow(label: 'البريد الإلكتروني', value: _user!['email']?.toString() ?? '-'),
                    InfoRow(label: 'تاريخ التسجيل', value: _formatDate(_user!['createdAt'])),
                    InfoRow(label: 'آخر تحديث', value: _formatDate(_user!['updatedAt'])),
                    InfoRow(label: 'اللغة', value: _user!['locale']?.toString() ?? 'ar'),
                  ]),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await AApi.instance.post('/admin/users/${widget.userId}/toggle-ban');
                            if (mounted) {
                              snack(context, _user?['isBanned'] == true ? 'تم إلغاء الحظر' : 'تم الحظر');
                              _load();
                            }
                          } catch (e) {
                            if (mounted) snack(context, ae(e), error: true);
                          }
                        },
                        icon: Icon(_user?['isBanned'] == true ? Icons.lock_open : Icons.block, size: 17),
                        label: Text(_user?['isBanned'] == true ? 'إلغاء الحظر' : 'حظر الحساب'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: ATheme.danger),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('حذف المستخدم نهائياً'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(dynamic v) {
    if (v == null) return '-';
    return v.toString().split('T').first;
  }
}
