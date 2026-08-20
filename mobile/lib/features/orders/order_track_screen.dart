import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets/ui_components.dart';
import '../auth/auth_cubit.dart';
import 'order_payment_screen.dart';
import 'chat_screen.dart';
import 'rate_order_sheet.dart';
import '../../core/widgets/cached_tile_provider.dart';

class OrderTrackScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackScreen({super.key, required this.orderId});

  @override
  State<OrderTrackScreen> createState() => _OrderTrackScreenState();
}

class _OrderTrackScreenState extends State<OrderTrackScreen> {
  Order? _order;
  List<CaptainOffer> _offers = [];
  bool _loading = true;
  bool _loadingOffers = false;
  String? _error;
  LatLng? _livePosition;

  bool get _isCaptain => context.read<AuthCubit>().state.user?.role == 'captain';

  @override
  void initState() {
    super.initState();
    _load();
    SocketService.instance.on('order:status', (data) {
      final map = data as Map<String, dynamic>;
      if (map['orderId'] == widget.orderId && mounted) {
        _refresh(showLoading: false);
      }
    });
    SocketService.instance.on('offer:created', (data) {
      final map = data as Map<String, dynamic>;
      if (map['orderId'] == widget.orderId && mounted) {
        _loadOffers();
      }
    });
    SocketService.instance.on('offer:accepted', (data) {
      if (mounted) _refresh(showLoading: false);
    });
    SocketService.instance.on('tracking:update', (data) {
      final map = data as Map<String, dynamic>;
      if (map['orderId'] == widget.orderId && mounted) {
        setState(() {
          _livePosition = LatLng(
            (map['lat'] as num).toDouble(),
            (map['lng'] as num).toDouble(),
          );
        });
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _refresh(showLoading: false);
  }

  Future<void> _loadOffers() async {
    if (_order == null) return;
    setState(() => _loadingOffers = true);
    try {
      final res = await ApiClient.instance.get('/orders/${widget.orderId}/offers') as List<dynamic>;
      if (mounted) {
        setState(() {
          _offers = res.map((x) => CaptainOffer.fromJson(x as Map<String, dynamic>)).toList();
          _loadingOffers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOffers = false);
    }
  }

  Future<void> _acceptOffer(CaptainOffer offer) async {
    try {
      await ApiClient.instance.post('/offers/${offer.id}/accept');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول عرض التوصيل وتعيين الكابتن بنجاح 🎉'), backgroundColor: AppColors.primary),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _rejectOffer(CaptainOffer offer) async {
    try {
      await ApiClient.instance.post('/offers/${offer.id}/reject');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض العرض')),
      );
      _loadOffers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _refresh({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final json = await ApiClient.instance.get('/orders/${widget.orderId}');
      if (!mounted) return;
      final order = Order.fromJson(json as Map<String, dynamic>);
      SocketService.instance.joinOrder(order.id);
      if (order.conversationId != null) {
        SocketService.instance.joinConversation(order.conversationId!);
      }
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
        if (order.currentLat != null && order.currentLng != null && _livePosition == null) {
          _livePosition = LatLng(order.currentLat!, order.currentLng!);
        }
      });
      if (order.status == 'awaiting_captain') {
        _loadOffers();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(e);
      });
    }
  }

  Future<void> _acceptOrder() async {
    try {
      await ApiClient.instance.post('/orders/${widget.orderId}/accept');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الطلب بنجاح 🟢')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _transitionOrder(String action, {String? code}) async {
    try {
      await ApiClient.instance.post(
        '/orders/${widget.orderId}/transition',
        body: {'action': action, if (code != null) 'code': code},
      );
      if (!mounted) return;
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CancelReasonSheet(),
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await ApiClient.instance.post('/orders/${widget.orderId}/cancel', body: {'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الطلب')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showPickupCodeDialog() {
    showDialog(
      context: context,
      builder: (_) => _PickupCodeDialog(
        onConfirm: (code) {
          Navigator.of(context).pop();
          _transitionOrder('pickup', code: code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body: const LoadingWidget(),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body: ErrorStateWidget(
          message: _error ?? 'لم يتم العثور على الطلب',
          onRetry: _load,
        ),
      );
    }

    final order = _order!;
    final pickupPoint = LatLng(order.pickupLat, order.pickupLng);
    final dropoffPoint = LatLng(order.dropoffLat, order.dropoffLng);

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب #${order.orderNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _refresh(showLoading: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('حالة الطلب الحالية', style: AppTypography.caption),
                      const SizedBox(height: 2),
                      Text(order.statusLabel, style: AppTypography.h2),
                    ],
                  ),
                  StatusChip.fromStatus(order.status),
                ],
              ),
            ),
            const Divider(),

            // Map Preview Segment
            SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: pickupPoint,
                  initialZoom: 12.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.twsil.mobile',
                    tileProvider: CachedTileProvider(),
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [pickupPoint, dropoffPoint],
                        color: AppColors.primary,
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pickupPoint,
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.trip_origin, color: AppColors.primary, size: 24),
                      ),
                      Marker(
                        point: dropoffPoint,
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.location_on, color: AppColors.danger, size: 24),
                      ),
                      if (_livePosition != null)
                        Marker(
                          point: _livePosition!,
                          width: 36,
                          height: 36,
                          child: const CircleAvatar(
                            backgroundColor: AppColors.success,
                            child: Icon(Icons.navigation, color: Colors.white, size: 18),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Order Details List
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoTile(
                    icon: Icons.trip_origin,
                    color: AppColors.primary,
                    title: 'موقع الاستلام',
                    subtitle: order.pickupAddress,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoTile(
                    icon: Icons.location_on,
                    color: AppColors.danger,
                    title: 'موقع التسليم',
                    subtitle: order.dropoffAddress,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoTile(
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.textPrimary,
                    title: 'وصف ومحتوى الطرد',
                    subtitle: '${order.packageDescription} (${order.packageSizeText} - ${order.weightKg} كجم)',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoTile(
                    icon: Icons.straighten,
                    color: AppColors.info,
                    title: 'المسافة التقديرية',
                    subtitle: order.formattedDistance,
                  ),

                  // PIN Code Display
                  if (order.pickupCode != null && !_isCaptain) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('رمز تسليم الطرد للكابتن:', style: AppTypography.bodyMedium),
                          Text(
                            order.pickupCode!,
                            style: AppTypography.h1.copyWith(color: AppColors.primary, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Incoming Offers Section (for Customer)
                  if (!_isCaptain && order.status == 'awaiting_captain') ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('عروض التوصيل المقدمة 🏷️', style: AppTypography.h2),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          onPressed: _loadOffers,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_loadingOffers)
                      const LoadingWidget()
                    else if (_offers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_empty, color: AppColors.warning, size: 20),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'بانتظار وصول عروض من الكباتن المتاحين بالقرب...',
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _offers.length,
                        itemBuilder: (context, i) {
                          final offer = _offers[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        child: Text(
                                          offer.captainName != null && offer.captainName!.isNotEmpty
                                              ? offer.captainName![0]
                                              : 'ك',
                                          style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              offer.captainName ?? 'كابتن توصيل',
                                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                                const SizedBox(width: 2),
                                                Text(offer.rating.toStringAsFixed(1), style: AppTypography.caption),
                                                const SizedBox(width: AppSpacing.sm),
                                                Text('(${offer.totalDeliveries} توصيلة)', style: AppTypography.caption),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                        child: Text(
                                          '${offer.price} ₪',
                                          style: AppTypography.h2.copyWith(color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    '⏱️ الوقت المتوقع: ${offer.estimatedTimeMinutes} دقيقة',
                                    style: AppTypography.caption,
                                  ),
                                  if (offer.message != null && offer.message!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '💬 "${offer.message}"',
                                      style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: [
                                      if (offer.conversationId != null) ...[
                                        Expanded(
                                          child: SecondaryButton(
                                            label: 'تفاوض 💬',
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ChatScreen(
                                                    orderId: order.id,
                                                    conversationId: offer.conversationId!,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                      ],
                                      Expanded(
                                        child: SecondaryButton(
                                          label: 'رفض',
                                          onPressed: () => _rejectOffer(offer),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        flex: 2,
                                        child: PrimaryButton(
                                          label: 'قبول العرض ✅',
                                          onPressed: () => _acceptOffer(offer),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],

                  // Captain / Customer Actions Section
                  const SizedBox(height: AppSpacing.xl),
                  if (!_isCaptain && order.status == 'payment_pending') ...[
                    PrimaryButton(
                      label: 'تأكيد ودفع رسوم الخدمة',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderPaymentScreen(order: order),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      label: 'إلغاء الطلب',
                      onPressed: _cancelOrder,
                    ),
                  ],

                  if (_isCaptain && order.status == 'awaiting_captain') ...[
                    PrimaryButton(
                      label: 'قبول هذا الطلب الان 🟢',
                      onPressed: _acceptOrder,
                    ),
                  ],

                  if (_isCaptain && order.status == 'accepted') ...[
                    PrimaryButton(
                      label: 'استلام الطرد (إدخال الرمز)',
                      onPressed: _showPickupCodeDialog,
                    ),
                  ],

                  if (_isCaptain && order.status == 'in_transit') ...[
                    PrimaryButton(
                      label: 'تم توصيل الطرد بنجاح ✅',
                      onPressed: () => _transitionOrder('delivered'),
                    ),
                  ],

                  if (order.conversationId != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'المحادثة المباشرة',
                      icon: Icons.chat_bubble_outline,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              orderId: order.id,
                              conversationId: order.conversationId!,
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  if (order.status == 'delivered' && !_isCaptain) ...[
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'تقييم الخدمة والكابتن',
                      icon: Icons.star_outline,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => RateOrderSheet(orderId: order.id),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupCodeDialog extends StatefulWidget {
  final ValueChanged<String> onConfirm;
  const _PickupCodeDialog({required this.onConfirm});

  @override
  State<_PickupCodeDialog> createState() => _PickupCodeDialogState();
}

class _PickupCodeDialogState extends State<_PickupCodeDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إدخال رمز الاستلام'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('اطلب رمز الاستلام المكون من 4 أرقام من العميل وتأكد من استلام الطرد:'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: AppTypography.h1,
            decoration: const InputDecoration(hintText: '0000'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().length == 4) {
              widget.onConfirm(_controller.text.trim());
            }
          },
          child: const Text('تأكيد الاستلام'),
        ),
      ],
    );
  }
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();
  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('سبب الإلغاء', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'اكتب سبب الإلغاء',
            controller: _controller,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'تأكيد الإلغاء',
            onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(_controller.text.trim());
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}