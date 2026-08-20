import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> with PollingMixin {
  List<Map<String, dynamic>> _reviews = [];
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
    setState(() => _loading = true);
    try {
      final r = await AApi.instance.get('/admin/reviews') as List;
      if (!mounted) return;
      setState(() {
        _reviews = r.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleHide(Map<String, dynamic> review) async {
    try {
      await AApi.instance.post('/admin/reviews/${review['id']}/toggle-hide');
      if (mounted) {
        snack(context, review['isHidden'] == true ? 'تم إظهار التقييم' : 'تم إخفاء التقييم');
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
        title: const Text('التقييمات'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _reviews.isEmpty
                  ? ListView(children: [
                      SizedBox(height: 200),
                      Center(child: Text('لا توجد تقييمات')),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      itemBuilder: (c, i) {
                        final r = _reviews[i];
                        final author = (r['author'] ?? {}) as Map<String, dynamic>;
                        final order = (r['order'] ?? {}) as Map<String, dynamic>;
                        final hidden = r['isHidden'] == true;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFF59E0B).withValues(alpha: .14),
                              child: Text('${r['rating'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                                if (hidden)
                                  Chip(
                                    label: const Text('مخفي'),
                                    backgroundColor: Colors.grey.withValues(alpha: .14),
                                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(r['comment'] ?? '', style: const TextStyle(fontSize: 12.5)),
                                if (order['orderNumber'] != null)
                                  Text('طلب #${order['orderNumber']}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: OutlinedButton(
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _toggleHide(r),
                              child: Text(hidden ? 'إظهار' : 'إخفاء'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}