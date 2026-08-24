import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
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
      final list = await AApi.instance.get('/orders/admin/list') as List;
      final match = list.cast<Map<String, dynamic>>().firstWhere(
            (o) => o['id']?.toString() == widget.orderId,
            orElse: () => <String, dynamic>{},
          );
      if (!mounted) return;
      if (match.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'لم يتم العثور على الطلب';
        });
        return;
      }
      setState(() {
        _order = match;
        _loading = false;
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
      backgroundColor: Colors.grey.shade50,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 44, color: ATheme.danger),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => context.go('/admin/orders'), child: const Text('رجوع للطلبات')),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SectionCard(title: 'الطلب #${_order!['orderNumber'] ?? ''}', children: [
                        Wrap(spacing: 6, children: [
                          StatusBadge(
                            label: statusLabel(_order!['status']?.toString() ?? ''),
                            color: statusColor(_order!['status']?.toString() ?? ''),
                            danger: _order!['status'] == 'cancelled',
                          ),
                        ]),
                        const Divider(height: 24),
                        InfoRow(label: 'الوصف', value: _order!['packageDescription']?.toString() ?? '-'),
                        InfoRow(label: 'من', value: _order!['pickupAddress']?.toString() ?? '-'),
                        InfoRow(label: 'إلى', value: _order!['dropoffAddress']?.toString() ?? '-'),
                        InfoRow(label: 'المسافة', value: '${_order!['distanceKm'] ?? '-'} كم'),
                        InfoRow(label: 'أجرة التوصيل', value: '${_order!['deliveryFee'] ?? '-'} ₪'),
                        InfoRow(label: 'رسوم الخدمة', value: '${_order!['serviceFee'] ?? '-'} ₪'),
                        InfoRow(label: 'التاريخ', value: (_order!['createdAt']?.toString() ?? '-').split('T').first),
                      ]),
                      SectionCard(title: 'الأطراف', children: [
                        InfoRow(
                          label: 'العميل',
                          value:
                              '${_order!['customer']?['firstName'] ?? ''} ${_order!['customer']?['lastName'] ?? ''} (${_order!['customer']?['phone'] ?? '-'})',
                        ),
                        InfoRow(
                          label: 'السائق',
                          value: _order!['captain']?['firstName'] == null
                              ? 'لم يُعيّن بعد'
                              : '${_order!['captain']?['firstName']} ${_order!['captain']?['lastName']} (${_order!['captain']?['phone']})',
                        ),
                      ]),
                      _paymentsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _paymentsSection() {
    final payments = (_order!['payments'] as List?) ?? [];
    if (payments.isEmpty) {
      return SectionCard(title: 'الدفعات', children: [const Text('لا توجد دفعات مسجلة', style: TextStyle(color: Colors.grey))]);
    }
    return SectionCard(
      title: 'الدفعات (${payments.length})',
      children: [
        for (final p in payments)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('طريقة الدفع: ${paymentMethodLabel(p['paymentMethod']?.toString() ?? '')}',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      Text('المبلغ: ${p['amount'] ?? '-'} ₪ • الحالة: ${statusLabel(p['status']?.toString() ?? '')}',
                          style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                    ],
                  ),
                ),
                if ((p['receiptImageUrl']?.toString() ?? '').isNotEmpty)
                  SizedBox(
                    width: 150,
                    child: DocumentThumb(url: p['receiptImageUrl'].toString(), title: 'الإيصال'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
