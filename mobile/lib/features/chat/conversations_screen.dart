import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../orders/chat_screen.dart';

/// Conversations list for the logged-in user (customer or captain).
/// Shows the counterpart name, the order number and the last message.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_conversations.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final json = await ApiClient.instance.get('/chats/conversations') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _conversations = json.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(e);
      });
    }
  }

  void _open(Map<String, dynamic> c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        orderId: c['orderId']?.toString() ?? '',
        conversationId: c['id']?.toString(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرسائل')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const LoadingWidget()
            : _error != null && _conversations.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      ErrorStateWidget(message: _error!),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ),
                    ],
                  )
                : _conversations.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          EmptyStateWidget(
                            icon: Icons.chat_bubble_outline,
                            title: 'لا توجد محادثات بعد',
                            subtitle:
                                'تفتح المحادثة تلقائياً بين العميل والكابتن عند قبول الطلب أو العرض.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _conversations.length,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        itemBuilder: (context, i) {
                          final c = _conversations[i];
                          final other = (c['otherUser'] ?? {}) as Map<String, dynamic>;
                          final name =
                              '${other['firstName'] ?? ''} ${other['lastName'] ?? ''}'.trim();
                          final last = (c['lastMessage'] ?? {}) as Map<String, dynamic>;
                          final preview = last.isNotEmpty
                              ? (last['type'] == 'image'
                                  ? '📷 صورة'
                                  : last['body']?.toString() ?? '')
                              : 'ابدأ المحادثة الآن';
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  name.isNotEmpty ? name.characters.first : '؟',
                                  style: const TextStyle(
                                      color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(
                                name.isEmpty ? 'مستخدم' : name,
                                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  if ((c['orderNumber'] ?? '').toString().isNotEmpty) ...[
                                    Text(
                                      '#${c['orderNumber']}',
                                      style: AppTypography.caption.copyWith(color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      preview,
                                      style: AppTypography.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                              onTap: () => _open(c),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
