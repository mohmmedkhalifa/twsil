import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});
  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> with PollingMixin {
  List<Map<String, dynamic>> _complaints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    startPolling();
  }

  @override
  void onPoll() => _load();

  Future<void> _load() async {
    // Silent refresh: keep current rows visible while polling.
    if (_complaints.isEmpty) setState(() => _loading = true);
    try {
      final c = await AApi.instance.get('/complaints/admin/list') as List;
      if (!mounted) return;
      setState(() {
        _complaints = c.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _resolve(String id, String action, String note) async {
    try {
      await AApi.instance.patch('/complaints/admin/$id', body: {
        'action': action,
        'adminNote': note,
      });
      if (mounted) {
        snack(context, 'تم تحديث الشكوى');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشكاوى'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _complaints.isEmpty
                  ? ListView(children: [
                      SizedBox(height: 200),
                      Center(child: Text('لا توجد شكاوى')),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _complaints.length,
                      itemBuilder: (c, i) {
                        final comp = _complaints[i];
                        final user = (comp['user'] ?? {}) as Map<String, dynamic>;
                        final order = (comp['order'] ?? {}) as Map<String, dynamic>;
                        final status = comp['status']?.toString() ?? '';
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              status == 'resolved' ? Icons.verified : Icons.report_problem,
                              color: status == 'resolved' ? Colors.green : const Color(0xFFF59E0B),
                            ),
                            title: Text(
                              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''} - ${statusLabel(status)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(comp['message'] ?? '', style: const TextStyle(fontSize: 12.5)),
                                if (order['orderNumber'] != null)
                                  Text('طلب #${order['orderNumber']}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                if (comp['adminNote'] != null)
                                  Text('رد الإدارة: ${comp['adminNote']}',
                                      style: const TextStyle(fontSize: 12, color: Colors.green)),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: status == 'resolved'
                                ? null
                                : TextButton(
                                    onPressed: () => _askResolve(c, comp),
                                    child: const Text('حل الشكوى'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  void _askResolve(BuildContext context, Map<String, dynamic> comp) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حل الشكوى'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'ملاحظة الإدارة (اختياري)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              _resolve(comp['id'] as String, 'resolve', noteCtrl.text);
            },
            child: const Text('تأكيد الحل'),
          ),
        ],
      ),
    );
  }
}