import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';
import '../core/widgets.dart';

/// Administrative accounts only — regular users and captains never appear here.
class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});
  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> with PollingMixin {
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    startPolling();
  }

  @override
  void onPoll() => _load();

  Future<void> _load() async {
    if (_admins.isEmpty) setState(() => _loading = true);
    try {
      final list = await AApi.instance.get('/admin/admins') as List;
      if (!mounted) return;
      setState(() {
        _admins = list.cast<Map<String, dynamic>>();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المدراء (${_admins.length})'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, size: 44, color: ATheme.danger),
                  const SizedBox(height: 8),
                  Text(_error!),
                ]))
              : _admins.isEmpty
                  ? const EmptyState(icon: Icons.admin_panel_settings_outlined, message: 'لا توجد حسابات إدارية')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _admins.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final a = _admins[i];
                        final name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ATheme.primary.withValues(alpha: .1),
                              child: const Icon(Icons.admin_panel_settings, color: ATheme.primary),
                            ),
                            title: Text(name.isEmpty ? 'مدير' : name,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${a['phone'] ?? '-'}  •  ${a['email'] ?? 'بدون بريد'}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                            ),
                            trailing: StatusBadge(
                              label: a['isBanned'] == true ? 'محظور' : 'مفعّل',
                              danger: a['isBanned'] == true,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
