import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with PollingMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _filter = '';

  static const _statuses = [
    '',
    'payment_pending',
    'awaiting_captain',
    'captain_assigned',
    'en_route_pickup',
    'arrived_pickup',
    'picked_up',
    'en_route_delivery',
    'arrived_dropoff',
    'delivered',
    'completed',
    'cancelled',
  ];

  String _formatDistance(dynamic dist) {
    final km = (dist as num?)?.toDouble() ?? 0.0;
    if (km <= 0) return '0 متر';
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters متر';
    }
    return '${km.toStringAsFixed(1)} كم';
  }

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
      final o = await AApi.instance.get('/orders/admin/list', query: {
        if (_filter.isNotEmpty) 'status': _filter,
      }) as List;
      if (!mounted) return;
      setState(() {
        _orders = o.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: DropdownButton<String>(
              value: _filter,
              onChanged: (v) {
                setState(() => _filter = v!);
                _load();
              },
              items: _statuses
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.isEmpty ? 'كل الحالات' : statusLabel(s)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _orders.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 200),
                      Center(child: Text('لا توجد طلبات')),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (c, i) {
                        final o = _orders[i];
                        final customer = (o['customer'] ?? {}) as Map<String, dynamic>;
                        final captain = (o['captain'] ?? {}) as Map<String, dynamic>;
                        final cu = (captain['user'] ?? {}) as Map<String, dynamic>;
                        final status = o['status']?.toString() ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            leading: Chip(
                              label: Text(statusLabel(status)),
                              backgroundColor: statusColor(status).withValues(alpha: .14),
                              labelStyle: TextStyle(color: statusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                              visualDensity: VisualDensity.compact,
                            ),
                            title: Text(
                              'طلب #${o['orderNumber'] ?? o['id']}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''} → ${o['dropoffAddress'] ?? ''}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: TextButton.icon(
                                        onPressed: () => context.go('/admin/orders/${o['id']}'),
                                        icon: const Icon(Icons.open_in_new, size: 15),
                                        label: const Text('فتح صفحة الطلب'),
                                      ),
                                    ),
                                    const Divider(),
                                    _kv('العميل', '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''} (${customer['phone'] ?? ''})'),
                                    _kv('العنوان من', o['pickupAddress'] ?? ''),
                                    _kv('العنوان إلى', o['dropoffAddress'] ?? ''),
                                    _kv('المسافة المقدرة', _formatDistance(o['distanceKm'])),
                                    _kv('الوصف', o['description'] ?? o['packageDescription'] ?? ''),
                                    _kv('السائق', cu['firstName'] != null ? '${cu['firstName']} ${cu['lastName']} (${cu['phone']})' : 'لم يُعيّن بعد'),
                                    _kv('التكلفة', o['deliveryFee'] != null && (o['deliveryFee'] as num) > 0 ? '${o['deliveryFee']} ₪ (رسوم خدمة ${o['serviceFee'] ?? 0} ₪)' : 'أجرة الكابتن: يحددها السائق (رسوم خدمة ${o['serviceFee'] ?? 0} ₪)'),
                                    _kv('حجم الطرد', o['packageType'] ?? o['packageSize'] ?? ''),
                                    _kv('وقت الإنشاء', o['createdAt']?.toString() ?? ''),
                                    if (o['pickupCode'] != null)
                                      _kv('رمز الاستلام', o['pickupCode'].toString()),
                                    
                                    // Payment Notice Section
                                    _buildPaymentNotice(o),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildPaymentNotice(Map<String, dynamic> o) {
    final payments = (o['payments'] as List? ?? []);
    final Map<String, dynamic> payment = payments.isNotEmpty
        ? Map<String, dynamic>.from(payments.last as Map)
        : {};

    final receiptUrl = payment['receiptImageUrl'] ??
        payment['receipt_image_url'] ??
        payment['receiptUrl'] ??
        o['receiptImageUrl'] ??
        '';

    final txnNum = payment['transactionNumber'] ?? payment['transaction_number'] ?? '';
    final method = payment['paymentMethod'] ?? payment['payment_method'] ?? o['paymentMethod'] ?? '';
    final payStatus = payment['status']?.toString() ?? o['paymentStatus']?.toString() ?? 'payment_pending';
    final payId = payment['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 18, color: Colors.blue),
              const SizedBox(width: 6),
              const Text(
                'إشعار وتأكيد الدفع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
              ),
              const Spacer(),
              _buildPaymentStatusChip(payStatus),
            ],
          ),
          const SizedBox(height: 8),
          if (method.toString().isNotEmpty)
            _kv('طريقة الدفع', _methodLabel(method.toString())),
          if (txnNum.toString().isNotEmpty)
            _kv('رقم العمليّة/الحوالة', txnNum.toString()),
          if (payment['amount'] != null)
            _kv('المبلغ المحول', '${payment['amount']} ₪'),
          
          if (receiptUrl.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'صورة إشعار الدفع:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showFullImage(AApi.instance.imageUrl(receiptUrl.toString())),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Image.network(
                    AApi.instance.imageUrl(receiptUrl.toString()),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('تعذر تحميل صورة الإشعار', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'لم يتم إرفاق صورة إشعار دفع بعد',
                style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ),

          if (payId.isNotEmpty && (payStatus == 'payment_submitted' || payStatus == 'under_review' || payStatus == 'payment_pending')) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reviewPay(payId, 'approve'),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('موافقة على الدفع', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reviewPay(payId, 'reject'),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('رفض الدفع', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'jawwal_pay':
        return 'جوال باي (Jawwal Pay)';
      case 'bop_palestine':
        return 'بنك فلسطين (BOP)';
      case 'palpay':
        return 'بال باي (PalPay)';
      default:
        return m;
    }
  }

  Widget _buildPaymentStatusChip(String st) {
    Color col;
    String txt;
    switch (st) {
      case 'approved':
        col = Colors.green;
        txt = 'مقبول ومؤكد';
        break;
      case 'rejected':
        col = Colors.red;
        txt = 'مرفوض';
        break;
      case 'payment_submitted':
      case 'under_review':
        col = Colors.orange;
        txt = 'قيد المراجعة';
        break;
      default:
        col = Colors.grey;
        txt = 'في انتظار الدفع';
    }
    return Chip(
      label: Text(txt, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: col.withValues(alpha: .12),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('إشعار الدفع'),
              leading: const CloseButton(),
            ),
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewPay(String payId, String action) async {
    try {
      await AApi.instance.post('/orders/admin/payments/$payId/review', body: {'action': action});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'approve' ? 'تمت الموافقة على إشعار الدفع' : 'تم رفض إشعار الدفع')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            TextSpan(text: v, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }
}