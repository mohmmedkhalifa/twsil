import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';

class CaptainsPage extends StatefulWidget {
  const CaptainsPage({super.key});
  @override
  State<CaptainsPage> createState() => _CaptainsPageState();
}

class _CaptainsPageState extends State<CaptainsPage> with PollingMixin {
  List<Map<String, dynamic>> _captains = [];
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
      final c = await AApi.instance.get('/admin/captains') as List;
      if (!mounted) return;
      setState(() {
        _captains = c.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _reviewVerification(Map<String, dynamic> captain, String action) async {
    final userId = captain['userId']?.toString() ??
        (captain['user'] as Map?)?['id']?.toString() ??
        captain['id']?.toString();

    if (userId == null || userId.isEmpty || userId == 'null') {
      snack(context, 'تعذر تحديد معرّف الكابتن', error: true);
      return;
    }

    final noteCtrl = TextEditingController();
    showDialog(
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
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(c);
              try {
                await AApi.instance.post('/admin/captains/$userId/verification', body: {
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
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> captain) async {
    final userId = captain['userId']?.toString() ??
        (captain['user'] as Map?)?['id']?.toString() ??
        captain['id']?.toString();

    if (userId == null || userId.isEmpty || userId == 'null') {
      snack(context, 'تعذر تحديد معرّف الكابتن', error: true);
      return;
    }

    final isActive = captain['isActive'] == true;
    try {
      await AApi.instance.post('/admin/captains/$userId/toggle-active');
      if (mounted) {
        snack(context, isActive ? 'تم إيقاف حساب الكابتن' : 'تم تنشيط حساب الكابتن بنجاح');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, ae(e), error: true);
    }
  }

  void _showDocumentsDialog(Map<String, dynamic> captain) {
    final user = (captain['user'] ?? {}) as Map<String, dynamic>;
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final idCardUrl = captain['nationalIdCardImageUrl']?.toString() ??
        captain['idCardUrl']?.toString() ??
        captain['idCardImageUrl']?.toString() ?? '';
    final licenseUrl = captain['licenseImageUrl']?.toString() ??
        captain['licenseUrl']?.toString() ?? '';
    final receiptUrl = captain['receiptImageUrl']?.toString() ??
        captain['receiptUrl']?.toString() ?? '';
    final note = captain['verificationNote']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: ATheme.primary.withValues(alpha: .1),
                      child: const Icon(Icons.directions_car, color: ATheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? 'كابتن' : name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('هاتف: ${user['phone'] ?? '-'} | مدينة: ${captain['city'] ?? '-'}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
                  ],
                ),
                const Divider(height: 28),
                const Text('📄 وثائق وتفاصيل الكابتن:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoItem('نوع المركبة', captain['transportType'] ?? 'سيارة'),
                      _infoItem('رقم اللوحة', captain['plateNumber'] ?? '-'),
                      _infoItem('رقم الهوية', captain['nationalId'] ?? '-'),
                    ],
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('ملاحظة التوثيق: $note', style: const TextStyle(color: Colors.brown, fontSize: 13)),
                ],

                const SizedBox(height: 20),
                const Text('🪪 صورة بطاقة الهوية (identity/):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _documentPreview(idCardUrl, 'بطاقة الهوية'),

                const SizedBox(height: 16),
                const Text('🚗 صورة رخصة القيادة (licenses/):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _documentPreview(licenseUrl, 'رخصة القيادة'),

                const SizedBox(height: 16),
                const Text('🧾 صورة إشعار الاشتراك/التحويل (payment-receipts/):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _documentPreview(receiptUrl, 'إشعار التحويل'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _documentPreview(String url, String title) {
    if (url.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text('لم يتم إرفاق $title', style: const TextStyle(color: Colors.grey)),
      );
    }
    final fullUrl = AApi.instance.imageUrl(url);
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (c) => Dialog(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(
                fullUrl,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('تعذر تحميل $title من الخادم'),
                ),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Image.network(
              fullUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: Text('تعذر تحميل $title', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('تكبير', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredCaptains {
    if (_searchQuery.trim().isEmpty) return _captains;
    final q = _searchQuery.trim().toLowerCase();
    return _captains.where((c) {
      final user = (c['user'] ?? {}) as Map<String, dynamic>;
      final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.toLowerCase();
      final phone = (user['phone'] ?? '').toString();
      final city = (c['city'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || city.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredCaptains;

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة السائقين والتوثيق (${_captains.length})'),
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
                hintText: 'بحث باسم الكابتن، رقم الجوال، أو المدينة...',
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
                        ? const Center(child: Text('لا يوجد سائقون مطابقون للبحث'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('الكابتن')),
                                  DataColumn(label: Text('الهاتف')),
                                  DataColumn(label: Text('نوع المركبة')),
                                  DataColumn(label: Text('الوثائق والصور')),
                                  DataColumn(label: Text('حالة التوثيق')),
                                  DataColumn(label: Text('تفعيل الحساب')),
                                  DataColumn(label: Text('إجراءات الإدارة')),
                                ],
                                rows: list.map((c) {
                                  final user = (c['user'] ?? {}) as Map<String, dynamic>;
                                  final vStatus = c['verificationStatus']?.toString() ?? '';
                                  final isActive = c['isActive'] == true;
                                  final phone = (user['phone']?.toString().isNotEmpty == true) ? user['phone'].toString() : '-';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: ATheme.primary.withValues(alpha: .1),
                                              child: const Icon(Icons.directions_car, size: 18, color: ATheme.primary),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim().isEmpty
                                                  ? 'كابتن بدون اسم'
                                                  : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(phone, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                                      DataCell(Text(c['transportType'] ?? 'سيارة', style: const TextStyle(fontSize: 13))),
                                      DataCell(
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            foregroundColor: const Color(0xFF2563EB),
                                          ),
                                          icon: const Icon(Icons.badge_outlined, size: 16),
                                          label: const Text('معاينة الوثائق والإيصال'),
                                          onPressed: () => _showDocumentsDialog(c),
                                        ),
                                      ),
                                      DataCell(
                                        Chip(
                                          label: Text(
                                            vStatus == 'verification_approved' || vStatus == 'approved'
                                                ? 'موثّق ومقبول'
                                                : vStatus == 'verification_pending' || vStatus == 'pending'
                                                    ? 'قيد المراجعة'
                                                    : 'مرفوض',
                                          ),
                                          backgroundColor: (vStatus == 'verification_approved' || vStatus == 'approved'
                                                  ? Colors.green
                                                  : vStatus == 'verification_pending' || vStatus == 'pending'
                                                      ? Colors.orange
                                                      : Colors.red)
                                              .withValues(alpha: .12),
                                          labelStyle: TextStyle(
                                            color: vStatus == 'verification_approved' || vStatus == 'approved'
                                                ? Colors.green
                                                : vStatus == 'verification_pending' || vStatus == 'pending'
                                                    ? Colors.orange
                                                    : Colors.red,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      DataCell(
                                        Switch(
                                          value: isActive,
                                          activeThumbColor: Colors.green,
                                          onChanged: (_) => _toggleActive(c),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            if (vStatus == 'verification_pending' || vStatus == 'pending') ...[
                                              FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  backgroundColor: Colors.green,
                                                ),
                                                icon: const Icon(Icons.check_circle, size: 16),
                                                label: const Text('قبول الكابتن'),
                                                onPressed: () => _reviewVerification(c, 'approve'),
                                              ),
                                              const SizedBox(width: 6),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  foregroundColor: ATheme.danger,
                                                ),
                                                icon: const Icon(Icons.cancel, size: 16),
                                                label: const Text('رفض'),
                                                onPressed: () => _reviewVerification(c, 'reject'),
                                              ),
                                            ] else ...[
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  foregroundColor: (vStatus == 'verification_approved' || vStatus == 'approved')
                                                      ? ATheme.danger
                                                      : Colors.green,
                                                ),
                                                icon: Icon(
                                                  (vStatus == 'verification_approved' || vStatus == 'approved')
                                                      ? Icons.cancel
                                                      : Icons.check_circle,
                                                  size: 16,
                                                ),
                                                label: Text((vStatus == 'verification_approved' || vStatus == 'approved')
                                                    ? 'إلغاء التوثيق'
                                                    : 'توثيق الحساب'),
                                                onPressed: () => _reviewVerification(
                                                  c,
                                                  (vStatus == 'verification_approved' || vStatus == 'approved') ? 'reject' : 'approve',
                                                ),
                                              ),
                                            ],
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
          ),
        ],
      ),
    );
  }
}