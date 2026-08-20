import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cached_tile_provider.dart';
import '../../core/widgets/ui_components.dart';
import 'order_payment_screen.dart';

enum SelectionMode { pickup, dropoff }

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  static const _initial = LatLng(31.5017, 34.4668); // Gaza City

  final MapController _mapController = MapController();
  final _pickupAddressController = TextEditingController(text: 'مدينة غزة - نقطة الاستلام');
  final _dropoffAddressController = TextEditingController(text: 'دير البلح - نقطة التسليم');
  final _descController = TextEditingController();
  final _weightController = TextEditingController();

  LatLng? _pickup = const LatLng(31.5017, 34.4668);
  LatLng? _dropoff = const LatLng(31.4178, 34.3524);
  SelectionMode _activeMode = SelectionMode.pickup;
  String _size = 'medium';
  bool _loading = false;
  String? _error;

  static const _cities = [
    {'name': 'غزة', 'lat': 31.5017, 'lng': 34.4668, 'enabled': true},
    {'name': 'خانيونس', 'lat': 31.3458, 'lng': 34.3033, 'enabled': true},
    {'name': 'دير البلح (الوسطى)', 'lat': 31.4178, 'lng': 34.3524, 'enabled': true},
    {'name': 'رفح (غير فعال)', 'lat': 31.2968, 'lng': 34.2455, 'enabled': false},
  ];

  void _onMapTap(LatLng point) {
    setState(() {
      if (_activeMode == SelectionMode.pickup) {
        _pickup = point;
        _pickupAddressController.text = 'موقع محدد (${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)})';
        _activeMode = SelectionMode.dropoff;
      } else {
        _dropoff = point;
        _dropoffAddressController.text = 'موقع محدد (${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)})';
      }
    });
  }

  void _moveToCity(Map<String, dynamic> city) {
    if (city['enabled'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('منطقة رفح غير فعالة حالياً بسبب الأوضاع الحالية'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final lat = city['lat'] as double;
    final lng = city['lng'] as double;
    final name = city['name'] as String;
    final pos = LatLng(lat, lng);
    _mapController.move(pos, 14);
    setState(() {
      if (_activeMode == SelectionMode.pickup) {
        _pickup = pos;
        _pickupAddressController.text = name;
      } else {
        _dropoff = pos;
        _dropoffAddressController.text = name;
      }
    });
  }

  double get _distanceKm {
    if (_pickup == null || _dropoff == null) return 0;
    const R = 6371;
    final dLat = (_dropoff!.latitude - _pickup!.latitude) * (math.pi / 180);
    final dLng = (_dropoff!.longitude - _pickup!.longitude) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_pickup!.latitude * (math.pi / 180)) *
            math.cos(_dropoff!.latitude * (math.pi / 180)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * R * math.asin(math.sqrt(a));
  }

  String get _formattedDistance => Order.formatDistance(_distanceKm);

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمة الموقع مغلقة، يرجى تفعيل الـ GPS')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض صلاحية تحديد الموقع')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('صلاحية الموقع مرفوضة دائماً، يرجى تفعيلها من الإعدادات')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final point = LatLng(position.latitude, position.longitude);
      _onMapTap(point);
      _mapController.move(point, 14.5);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع الحالي: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (_pickup == null || _dropoff == null) {
      setState(() => _error = 'يرجى تحديد نقطتي الاستلام والتسليم على الخريطة');
      return;
    }
    if (_descController.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال وصف الطرد');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.post('/orders', body: {
        'pickupLat': _pickup!.latitude,
        'pickupLng': _pickup!.longitude,
        'pickupAddress': _pickupAddressController.text.trim().isEmpty
            ? 'موقع الاستلام'
            : _pickupAddressController.text.trim(),
        'dropoffLat': _dropoff!.latitude,
        'dropoffLng': _dropoff!.longitude,
        'dropoffAddress': _dropoffAddressController.text.trim().isEmpty
            ? 'موقع التسليم'
            : _dropoffAddressController.text.trim(),
        'packageDescription': _descController.text.trim(),
        'packageSize': _size,
        'weightKg': double.tryParse(_weightController.text) ?? 1.0,
        'distanceKm': double.parse(_distanceKm.toStringAsFixed(3)),
        'deliveryFee': 0.0,
      });

      if (!mounted) return;
      
      Map<String, dynamic> orderJson = {};
      if (res is Map<String, dynamic>) {
        orderJson = res;
      } else if (res is List && res.isNotEmpty) {
        orderJson = res.first as Map<String, dynamic>;
      }

      final createdOrder = Order.fromJson(orderJson);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderPaymentScreen(order: createdOrder),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب توصيل جديد')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Preview Header
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _initial,
                      initialZoom: 12.0,
                      onTap: (_, p) => _onMapTap(p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.twsil.mobile',
                        tileProvider: CachedTileProvider(),
                      ),
                      PolylineLayer(
                        polylines: [
                          if (_pickup != null && _dropoff != null)
                            Polyline(
                              points: [_pickup!, _dropoff!],
                              color: AppColors.primary,
                              strokeWidth: 3.5,
                            ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          if (_pickup != null)
                            Marker(
                              point: _pickup!,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.trip_origin, color: AppColors.primary, size: 28),
                            ),
                          if (_dropoff != null)
                            Marker(
                              point: _dropoff!,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.location_on, color: AppColors.danger, size: 28),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _activeMode == SelectionMode.pickup ? 'انقر لتحديد موقع الاستلام' : 'انقر لتحديد موقع التسليم',
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: FloatingActionButton.small(
                      heroTag: 'myLocationFab',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      onPressed: _getCurrentLocation,
                      child: const Icon(Icons.my_location, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // City Shortcuts Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: _cities.map((city) {
                  final enabled = city['enabled'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(city['name'].toString()),
                      selected: false,
                      onSelected: (_) => _moveToCity(city),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Form Inputs Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<SelectionMode>(
                          segments: const [
                            ButtonSegment(value: SelectionMode.pickup, label: Text('الاستلام 🟢')),
                            ButtonSegment(value: SelectionMode.dropoff, label: Text('التسليم 🔴')),
                          ],
                          selected: {_activeMode},
                          onSelectionChanged: (s) => setState(() => _activeMode = s.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'عنوان الاستلام',
                    controller: _pickupAddressController,
                    prefixIcon: Icons.trip_origin,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'عنوان التسليم',
                    controller: _dropoffAddressController,
                    prefixIcon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'وصف الطرد وشروطه',
                    hint: 'مثال: أوراق ثبوتية، ملابس، جهاز إلكتروني',
                    controller: _descController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('حجم الطرد', style: AppTypography.bodyMedium),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<String>(
                              initialValue: _size,
                              items: const [
                                DropdownMenuItem(value: 'small', child: Text('صغير (أوراق / مغلف)')),
                                DropdownMenuItem(value: 'medium', child: Text('متوسط (حقيبة / صندوق)')),
                                DropdownMenuItem(value: 'large', child: Text('كبير (أثاث / كرتونة)')),
                              ],
                              onChanged: (v) => setState(() => _size = v ?? 'medium'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'الوزن (كجم)',
                          hint: '1.0',
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ErrorStateWidget(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المسافة التقديرية:', style: AppTypography.bodyMedium),
                        Text(
                          _formattedDistance,
                          style: AppTypography.h2.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'متابعة وتأكيد الطلب',
                    isLoading: _loading,
                    onPressed: _submit,
                  ),
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