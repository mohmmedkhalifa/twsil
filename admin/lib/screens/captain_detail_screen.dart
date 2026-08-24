import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class CaptainDetailScreen extends StatefulWidget {
  final String captainUserId;
  const CaptainDetailScreen({super.key, required this.captainUserId});

  @override
  State<CaptainDetailScreen> createState() => _CaptainDetailScreenState();
}

class _CaptainDetailScreenState extends State<CaptainDetailScreen> {
  Map<String, dynamic>? _captain;
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
      final list = await AApi.instance.get('/admin/captains') as List;
      final match = list.cast<Map<String, dynamic>>().firstWhere(
            (c) => c['userId']?.toString() == widget.captainUserId,
            orElse: () => <String, dynamic>{},
          );
      if (!mounted) return;
      if (match.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'لم يتم العثور على الكابتن';
        });
        return;
      }
      setState(() {
        _captain = match;
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

  (String, bool, bool) _verificationBadge(String vs) {
    if (vs == 'verification_approved' || vs == 'approved') {
      return ('موثّق ومقبول', false, false);
    }
    if (vs == 'verification_pending' || vs == 'pending') {
      return ('قيد المراجعة', false, true);
    }
    return ('مرفوض', true, false);
  }

  Future<void> _reviewVerification(String action) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(action == 'approve' ? 'اعتماد توثيق الكابتن' : 'رفض توثيق الكابتن'),
        content: action == 'approve'
            ? const Text('سيتم توثيق حساب الكابتن وتفعيل قدرته على استقبال الطلبات.')
            : TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'سبب الرفض (اختياري)'),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AApi.instance.post('/admin/captains/${widget.captainUserId}/verification', body: {
        'action': action,
        if (noteCtrl.text.isNotEmpty) 'note': noteCtrl.text,
      });
      if (mounted) {
        snack(context, action == 'approve' ? 'تم توثيق الكابتن بنجاح' : 'تم رفض طلب التوثيق');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  Future<void> _toggleActive() async {
    try {
      await AApi.instance.post('/admin/captains/${widget.captainUserId}/toggle-active');
      if (mounted) {
        snack(context, 'تم تحديث حالة الحساب');
        _load();
      }
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
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 44, color: ATheme.danger),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => context.go('/admin/captains'), child: const Text('رجوع للسائقين')),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SectionCard(title: 'بيانات السائق', children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: ATheme.primary.withValues(alpha: .1),
                              child: const Icon(Icons.two_wheeler, color: ATheme.primary, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_captain!['user']['firstName'] ?? ''} ${_captain!['user']['lastName'] ?? ''}'.trim(),
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      StatusBadge(label: _verificationBadge(_captain!['verificationStatus']?.toString() ?? '').$1,
                                        danger: _verificationBadge(_captain!['verificationStatus']?.toString() ?? '').$2,
                                        warning: _verificationBadge(_captain!['verificationStatus']?.toString() ?? '').$3),
                                      StatusBadge(
                                        label: _captain!['isActive'] == true ? 'الحساب مفعّل' : 'الحساب موقوف',
                                        danger: _captain!['isActive'] != true,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 26),
                        InfoRow(label: 'رقم الهاتف', value: _captain!['user']['phone']?.toString() ?? '-'),
                        InfoRow(label: 'البريد الإلكتروني', value: _captain!['user']['email']?.toString() ?? '-'),
                        InfoRow(label: 'نوع المركبة', value: transportTypeLabel(_captain!['transportType']?.toString() ?? '')),
                        InfoRow(label: 'رقم اللوحة', value: _captain!['plateNumber']?.toString() ?? '-'),
                        InfoRow(label: 'رقم الهوية', value: _captain!['nationalId']?.toString() ?? '-'),
                        InfoRow(label: 'المدينة', value: _captain!['city']?.toString() ?? '-'),
                        InfoRow(label: 'تاريخ التسجيل', value: (_captain!['createdAt']?.toString() ?? '-').split('T').first),
                        if ((_captain!['verificationNote']?.toString() ?? '').isNotEmpty)
                          InfoRow(label: 'ملاحظة التوثيق', value: _captain!['verificationNote'].toString()),
                      ]),
                      SectionCard(title: 'الوثائق المرفوعة', children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DocumentThumb(
                                url: _captain!['idCardUrl']?.toString() ?? '',
                                title: 'بطاقة الهوية',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DocumentThumb(
                                url: _captain!['licenseUrl']?.toString() ?? '',
                                title: 'رخصة القيادة',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DocumentThumb(
                                url: _captain!['receiptImageUrl']?.toString() ?? '',
                                title: 'إشعار الاشتراك',
                              ),
                            ),
                          ],
                        ),
                      ]),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _reviewVerification('approve'),
                            icon: const Icon(Icons.check_circle, size: 17),
                            label: const Text('اعتماد التوثيق'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: ATheme.danger),
                            onPressed: () => _reviewVerification('reject'),
                            icon: const Icon(Icons.cancel, size: 17),
                            label: const Text('رفض التوثيق'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _toggleActive,
                            icon: Icon(_captain!['isActive'] == true ? Icons.pause_circle : Icons.play_circle, size: 17),
                            label: Text(_captain!['isActive'] == true ? 'إيقاف الحساب' : 'تفعيل الحساب'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
