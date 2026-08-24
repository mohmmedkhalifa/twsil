import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';

class PaymentCenter extends StatefulWidget {
  const PaymentCenter({super.key});
  @override
  State<PaymentCenter> createState() => _PaymentCenterState();
}

class _PaymentCenterState extends State<PaymentCenter> with PollingMixin {
  int _tab = 0;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _subscriptions = [];
  bool _loading = true;
  String _filter = 'all';

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
      final p = await AApi.instance.get('/orders/admin/payments', query: {
        if (_filter != 'all') 'status': _filter,
      }) as List;
      final s = await AApi.instance.get('/admin/subscriptions', query: {
        if (_filter != 'all') 'status': _filter,
      }) as List;
      if (!mounted) return;
      setState(() {
        _payments = p.cast<Map<String, dynamic>>();
        _subscriptions = s.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// A receipt is actionable while it waits for a decision. The backend
  /// writes 'under_review' for new submissions; older rows may still use
  /// the legacy 'payment_submitted' value.
  static bool _isPendingReceipt(String? status) =>
      status == 'under_review' || status == 'payment_submitted';

  Future<void> _reviewPayment(String id, String action, String note) async {
    try {
      await AApi.instance.post('/orders/admin/payments/$id/review', body: {
        'action': action,
        if (note.isNotEmpty) 'note': note,
      });
      if (mounted) {
        snack(
          context,
          action == 'approve'
              ? 'تم اعتماد الإيصال بنجاح'
              : action == 'reject'
                  ? 'تم رفض الإيصال'
                  : 'تم إرسال طلب إيصال جديد للعميل',
        );
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  Future<void> _reviewSubscription(String id, String action, String? note) async {
    try {
      await AApi.instance.post('/admin/subscriptions/$id/review', body: {
        'action': action,
        if (note != null) 'note': note,
      });
      if (mounted) {
        snack(context, action == 'approve' ? 'تم تفعيل الاشتراك بنجاح' : 'تم رفض الاشتراك');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز الدفع'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'إيصالات الطلبات'),
              Tab(text: 'اشتراكات السائقين'),
            ],
            onTap: (i) => setState(() => _tab = i),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: DropdownButton<String>(
                value: _filter,
                onChanged: (v) {
                  setState(() => _filter = v!);
                  _load();
                },
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'under_review', child: Text('بانتظار المراجعة')),
                  DropdownMenuItem(value: 'approved', child: Text('مقبول')),
                  DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                  DropdownMenuItem(value: 'awaiting_payment', child: Text('بانتظار إيصال جديد')),
                ],
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _tab == 0
                    ? _paymentsList(context)
                    : _subscriptionsList(context),
              ),
      ),
    );
  }

  Widget _paymentsList(BuildContext context) {
    if (_payments.isEmpty) return const Center(child: Text('لا توجد إيصالات'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (c, i) {
        final p = _payments[i];
        final order = (p['order'] ?? {}) as Map<String, dynamic>;
        final customer = (order['customer'] ?? {}) as Map<String, dynamic>;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(statusLabel(p['status']?.toString() ?? '')),
                      backgroundColor: statusColor(p['status']?.toString() ?? '').withValues(alpha: .14),
                      labelStyle: TextStyle(color: statusColor(p['status']?.toString() ?? '')),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    Text(
                      '${p['amount'] ?? 0} ₪',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('طلب #${order['orderNumber'] ?? p['orderId']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('العميل: ${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''} (${customer['phone'] ?? ''})',
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                Text('${paymentMethodLabel(p['method']?.toString() ?? '')} | مرسل: ${p['submittedAt'] ?? ''}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                if (p['note'] != null && p['note'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('ملاحظة: ${p['note']}',
                        style: const TextStyle(fontSize: 12.5, color: Colors.brown)),
                  ),
                if (p['receiptImageUrl'] != null && p['receiptImageUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showReceipt(p['receiptImageUrl'] as String),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        AApi.instance.imageUrl(p['receiptImageUrl'] as String),
                        height: 160,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Text('تعذر عرض الإيصال'),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_isPendingReceipt(p['status']?.toString())) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('اعتماد الإيصال'),
                          onPressed: () => _paymentAction(context, p, 'approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: ATheme.danger),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('رفض'),
                          onPressed: () => _paymentAction(context, p, 'reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('إيصال غير واضح'),
                          onPressed: () => _paymentAction(context, p, 'request_receipt'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _paymentAction(BuildContext context, Map<String, dynamic> p, String action) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(action == 'approve' ? 'اعتماد الإيصال' : action == 'reject' ? 'رفض الإيصال' : 'طلب إيصال أوضح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action == 'reject' || action == 'request_receipt')
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظة للعميل'),
              ),
            if (action == 'approve')
              const Text('سيتم تحويل الطلب إلى قيد المعالجة وتعديل رصيد العميل.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              _reviewPayment(p['id'] as String, action, noteCtrl.text);
            },
            child: Text(action == 'approve' ? 'اعتماد' : 'إرسال'),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionsList(BuildContext context) {
    if (_subscriptions.isEmpty) return const Center(child: Text('لا توجد اشتراكات'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subscriptions.length,
      itemBuilder: (c, i) {
        final s = _subscriptions[i];
        final user = (s['captain'] ?? {}) as Map<String, dynamic>;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(statusLabel(s['status']?.toString() ?? '')),
                      backgroundColor: statusColor(s['status']?.toString() ?? '').withValues(alpha: .14),
                      labelStyle: TextStyle(color: statusColor(s['status']?.toString() ?? '')),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    Text(
                      '${s['amount'] ?? 0} ₪',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${user['firstName'] ?? ''} ${user['lastName'] ?? ''} (${user['phone'] ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('اشتراك شهري | بداية: ${s['startDate'] ?? ''}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                if (s['note'] != null && s['note'].toString().isNotEmpty)
                  Text('ملاحظة: ${s['note']}', style: const TextStyle(fontSize: 12.5, color: Colors.brown)),
                if (s['receiptImageUrl'] != null && s['receiptImageUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showReceipt(s['receiptImageUrl'] as String),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        AApi.instance.imageUrl(s['receiptImageUrl'] as String),
                        height: 160,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Text('تعذر عرض الإيصال'),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_isPendingReceipt(s['status']?.toString())) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('تفعيل الاشتراك'),
                          onPressed: () => _subscriptionAction(context, s, 'approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: ATheme.danger),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('رفض'),
                          onPressed: () => _subscriptionAction(context, s, 'reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _subscriptionAction(BuildContext context, Map<String, dynamic> s, String action) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(action == 'approve' ? 'تفعيل الاشتراك' : 'رفض الاشتراك'),
        content: action == 'approve'
            ? const Text('سيتم تفعيل اشتراك السائق.')
            : TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'سبب الرفض'),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              _reviewSubscription(s['id'] as String, action, noteCtrl.text);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showReceipt(String url) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            AApi.instance.imageUrl(url),
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(40),
              child: Text('تعذر عرض الإيصال'),
            ),
          ),
        ),
      ),
    );
  }
}

