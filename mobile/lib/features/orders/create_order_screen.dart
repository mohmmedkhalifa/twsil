import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cached_tile_provider.dart';
import '../../core/widgets/ui_components.dart';
import 'order_payment_screen.dart';

enum SelectionMode { pickup, dropoff }

/// How the user provides each address. The map is ALWAYS optional.
enum AddressInputMode { map, manual }

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  static const _initial = LatLng(31.5017, 34.4668); // Gaza City

  final MapController _mapController = MapController();

  // Map-mode labels (editable summary of the pinned location).
  final _pickupAddressController = TextEditingController(text: 'مدينة غزة - نقطة الاستلام');
  final _dropoffAddressController = TextEditingController(text: 'دير البلح - نقطة التسليم');

  // Manual address entry (pickup).
  String? _pickupGovernorate;
  final _pickupCityController = TextEditingController();
  final _pickupStreetController = TextEditingController();
  final _pickupDetailsController = TextEditingController();

  // Manual address entry (delivery).
  String? _dropoffGovernorate;
  final _dropoffCityController = TextEditingController();
  final _dropoffStreetController = TextEditingController();
  final _dropoffDetailsController = TextEditingController();

  final _descController = TextEditingController();
  final _weightController = TextEditingController();

  LatLng? _pickup;
  LatLng? _dropoff;
  SelectionMode _activeMode = SelectionMode.pickup;
  AddressInputMode _pickupInputMode = AddressInputMode.map;
  AddressInputMode _dropoffInputMode = AddressInputMode.map;
  String _size = 'medium';

  bool _loading = false;
  String? _error;

  /// Idempotency token: one form session maps to AT MOST one order.
  /// Kept across manual retries so a timeout/re-submit can never create
  /// a duplicate — the backend returns the already-created order.
  late final String _clientRequestId = const Uuid().v4();

  static const _cities = [
    {'name': 'غزة', 'lat': 31.5017, 'lng': 34.4668, 'enabled': true},
    {'name': 'خانيونس', 'lat': 31.3458, 'lng': 34.3033, 'enabled': true},
    {'name': 'دير البلح (الوسطى)', 'lat': 31.4178, 'lng': 34.3524, 'enabled': true},
    {'name': 'رفح', 'lat': 31.2968, 'lng': 34.2455, 'enabled': true},
  ];

  static const _governorates = [
    'غزة',
    'شمال غزة',
    'دير البلح (الوسطى)',
    'خانيونس',
    'رفح',
  ];

  bool get _isPickupActive => _activeMode == SelectionMode.pickup;

  AddressInputMode get _activeInputMode =>
      _isPickupActive ? _pickupInputMode : _dropoffInputMode;

  // ------------------------------------------------------------- map

  void _onMapTap(LatLng point) {
    setState(() {
      if (_isPickupActive) {
        if (_pickupInputMode != AddressInputMode.map) return;
        _pickup = point;
        _pickupAddressController.text =
            'موقع محدد (${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)})';
        _activeMode = SelectionMode.dropoff;
      } else {
        if (_dropoffInputMode != AddressInputMode.map) return;
        _dropoff = point;
        _dropoffAddressController.text =
            'موقع محدد (${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)})';
      }
    });
  }

  void _moveToCity(Map<String, dynamic> city) {
    final lat = city['lat'] as double;
    final lng = city['lng'] as double;
    final name = city['name'] as String;
    final pos = LatLng(lat, lng);
    _mapController.move(pos, 14);
    setState(() {
      if (_isPickupActive) {
        if (_pickupInputMode != AddressInputMode.map) {
          _pickupGovernorate ??= name;
          return;
        }
        _pickup = pos;
        _pickupAddressController.text = name;
      } else {
        if (_dropoffInputMode != AddressInputMode.map) {
          _dropoffGovernorate ??= name;
          return;
        }
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

  String get _formattedDistance =>
      (_pickup == null || _dropoff == null) ? 'غير متاحة' : Order.formatDistance(_distanceKm);

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمة الموقع مغلقة، يمكنك إدخال العنوان يدوياً بدلاً من الخريطة')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض صلاحية الموقع، يمكنك إدخال العنوان يدوياً'),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('صلاحية الموقع مرفوضة، يمكنك إدخال العنوان يدوياً'),
          ),
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

  // ---------------------------------------------------------- manual input

  /// Composed human-readable address for a manually entered point.
  String _composeManualAddress({
    required String? governorate,
    required TextEditingController city,
    required TextEditingController street,
    required TextEditingController details,
  }) {
    final parts = <String>[
      if ((governorate ?? '').trim().isNotEmpty) governorate!.trim(),
      if (city.text.trim().isNotEmpty) city.text.trim(),
      if (street.text.trim().isNotEmpty) street.text.trim(),
      if (details.text.trim().isNotEmpty) details.text.trim(),
    ];
    return parts.join(' - ');
  }

  // ---------------------------------------------------------------- submit

  Future<void> _submit() async {
    // Hard guard: a second tap within the same frame can never re-enter.
    if (_loading) return;

    final pickupAddress = _pickupInputMode == AddressInputMode.map
        ? _pickupAddressController.text.trim()
        : _composeManualAddress(
            governorate: _pickupGovernorate,
            city: _pickupCityController,
            street: _pickupStreetController,
            details: _pickupDetailsController,
          );
    final dropoffAddress = _dropoffInputMode == AddressInputMode.map
        ? _dropoffAddressController.text.trim()
        : _composeManualAddress(
            governorate: _dropoffGovernorate,
            city: _dropoffCityController,
            street: _dropoffStreetController,
            details: _dropoffDetailsController,
          );

    if (_pickupInputMode == AddressInputMode.map && _pickup == null) {
      setState(() => _error = 'يرجى تحديد موقع الاستلام على الخريطة أو التحويل إلى الإدخال اليدوي');
      return;
    }
    if (_dropoffInputMode == AddressInputMode.map && _dropoff == null) {
      setState(() => _error = 'يرجى تحديد موقع التسليم على الخريطة أو التحويل إلى الإدخال اليدوي');
      return;
    }
    if (_pickupInputMode == AddressInputMode.manual &&
        (_pickupGovernorate == null || _pickupCityController.text.trim().isEmpty)) {
      setState(() => _error = 'يرجى إدخال المحافظة والمدينة/المنطقة لنقطة الاستلام');
      return;
    }
    if (_dropoffInputMode == AddressInputMode.manual &&
        (_dropoffGovernorate == null || _dropoffCityController.text.trim().isEmpty)) {
      setState(() => _error = 'يرجى إدخال المحافظة والمدينة/المنطقة لنقطة التسليم');
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
        if (_pickupInputMode == AddressInputMode.map && _pickup != null) ...{
          'pickupLat': _pickup!.latitude,
          'pickupLng': _pickup!.longitude,
        },
        'pickupAddress': pickupAddress.isEmpty ? 'موقع الاستلام' : pickupAddress,
        if (_dropoffInputMode == AddressInputMode.map && _dropoff != null) ...{
          'dropoffLat': _dropoff!.latitude,
          'dropoffLng': _dropoff!.longitude,
        },
        'dropoffAddress': dropoffAddress.isEmpty ? 'موقع التسليم' : dropoffAddress,
        'packageDescription': _descController.text.trim(),
        'packageSize': _size,
        'weightKg': double.tryParse(_weightController.text) ?? 1.0,
        'clientRequestId': _clientRequestId,
      });

      if (!mounted) return;

      Map<String, dynamic> orderJson = {};
      if (res is Map<String, dynamic>) {
        orderJson = res;
      } else if (res is List && res.isNotEmpty) {
        orderJson = res.first as Map<String, dynamic>;
      }

      final createdOrder = Order.fromJson(orderJson);

      // Success: leave this screen. No further POST can happen because
      // the screen (and its submit handler) is disposed by pushReplacement.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderPaymentScreen(order: createdOrder),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Failure: stop loading and let the user retry manually. The same
      // idempotency token is reused, so retrying never duplicates orders.
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(e);
      });
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب توصيل جديد')),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMapSection(),
              _buildCityShortcuts(),
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
                    _buildAddressSection(isPickup: true),
                    const SizedBox(height: AppSpacing.lg),
                    _buildAddressSection(isPickup: false),
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

  Widget _buildMapSection() {
    return SizedBox(
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
                _activeInputMode == AddressInputMode.map
                    ? (_isPickupActive ? 'انقر لتحديد موقع الاستلام' : 'انقر لتحديد موقع التسليم')
                    : 'وضع الإدخال اليدوي للعنوان',
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
    );
  }

  Widget _buildCityShortcuts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: _cities.map((city) {
          return Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(city['name'].toString()),
              selected: false,
              onSelected: (_) => _moveToCity(city),
              labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddressSection({required bool isPickup}) {
    final mode = isPickup ? _pickupInputMode : _dropoffInputMode;
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
              Icon(
                isPickup ? Icons.trip_origin : Icons.location_on_outlined,
                size: 18,
                color: isPickup ? AppColors.primary : AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                isPickup ? 'عنوان الاستلام' : 'عنوان التسليم',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SegmentedButton<AddressInputMode>(
                segments: const [
                  ButtonSegment(value: AddressInputMode.map, label: Text('خريطة')),
                  ButtonSegment(value: AddressInputMode.manual, label: Text('يدوي')),
                ],
                selected: {mode},
                onSelectionChanged: (s) {
                  setState(() {
                    if (isPickup) {
                      _pickupInputMode = s.first;
                      if (s.first == AddressInputMode.manual) _pickup = null;
                    } else {
                      _dropoffInputMode = s.first;
                      if (s.first == AddressInputMode.manual) _dropoff = null;
                    }
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (mode == AddressInputMode.map) ...[
            AppTextField(
              label: isPickup ? 'وصف نقطة الاستلام' : 'وصف نقطة التسليم',
              controller: isPickup ? _pickupAddressController : _dropoffAddressController,
              prefixIcon: isPickup ? Icons.trip_origin : Icons.location_on_outlined,
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              initialValue: isPickup ? _pickupGovernorate : _dropoffGovernorate,
              decoration: InputDecoration(labelText: 'المحافظة *'),
              items: _governorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() {
                if (isPickup) {
                  _pickupGovernorate = v;
                } else {
                  _dropoffGovernorate = v;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'المدينة / المنطقة *',
              hint: 'مثال: الرمال، الشيخ رضوان',
              controller: isPickup ? _pickupCityController : _dropoffCityController,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'الشارع / الحي',
              hint: 'مثال: شارع عمر المختار',
              controller: isPickup ? _pickupStreetController : _dropoffStreetController,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'تفاصيل العنوان / أقرب معلم',
              hint: 'مثال: مقابل مسجد النور، الطابق الثاني',
              controller: isPickup ? _pickupDetailsController : _dropoffDetailsController,
            ),
          ],
        ],
      ),
    );
  }
}
