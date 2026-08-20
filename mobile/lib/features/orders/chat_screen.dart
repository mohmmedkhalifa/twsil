import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/socket_service.dart';
import '../../core/network/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../auth/auth_cubit.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String? conversationId;
  const ChatScreen({super.key, required this.orderId, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = context.read<AuthCubit>().state.user?.id;
    SocketService.instance.on('chat:message', (data) {
      final map = data as Map<String, dynamic>;
      if (map['conversationId'] == _conversationId && mounted) {
        setState(() {
          _messages.add(Message.fromJson(Map<String, dynamic>.from(map)));
        });
        _scrollToBottom();
      }
    });
    _load();
  }

  Future<void> _load() async {
    _conversationId = widget.conversationId;
    if (_conversationId == null) {
      try {
        final json = await ApiClient.instance.get('/chats/order/${widget.orderId}');
        if (!mounted) return;
        final conv = Conversation.fromJson(json as Map<String, dynamic>);
        setState(() {
          _conversationId = conv.id;
          _messages = conv.messages;
          _loading = false;
        });
        SocketService.instance.joinConversation(conv.id);
        _markRead();
        _scrollToBottom();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _conversationId = widget.conversationId ?? _conversationId;
        });
      }
      return;
    }
    setState(() => _loading = false);
    SocketService.instance.joinConversation(_conversationId!);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _conversationId == null) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post('/chats/$_conversationId/messages', body: {
        'body': text,
      });
      _input.clear();
      setState(() => _sending = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _sendImage() async {
    if (_conversationId == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400);
    if (picked == null) return;
    try {
      final url = await ApiClient.instance.uploadImage(picked.path);
      await ApiClient.instance.post('/chats/$_conversationId/messages', body: {
        'imageUrl': url,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _markRead() async {
    if (_conversationId == null) return;
    await ApiClient.instance.patch('/chats/$_conversationId/read');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحادثة المباشرة'),
      ),
      body: _loading
          ? const LoadingWidget()
          : _conversationId == null
              ? const EmptyStateWidget(
                  icon: Icons.forum_outlined,
                  title: 'المحادثة مغلقة',
                  subtitle: 'ستُفتح المحادثة تلقائياً بعد قبول السائق للطلب',
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final mine = msg.senderId == _myId;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: mine ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: mine ? null : Border.all(color: AppColors.border),
                              ),
                              child: msg.type == 'image'
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      child: Image.network(
                                        msg.imageUrl ?? '',
                                        width: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image, size: 48),
                                      ),
                                    )
                                  : Text(
                                      msg.body,
                                      style: AppTypography.body.copyWith(
                                        color: mine ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image_outlined, color: AppColors.textMuted),
                              onPressed: _sendImage,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _input,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                style: AppTypography.body,
                                decoration: const InputDecoration(
                                  hintText: 'اكتب رسالة هنا...',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _sending ? null : _send,
                              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}