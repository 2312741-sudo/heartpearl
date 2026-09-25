import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/place_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/places_provider.dart';

class AddPlaceSheet extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const AddPlaceSheet({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  static Future<void> show(BuildContext context, {double? lat, double? lng}) {
    HapticHelper.medium();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPlaceSheet(initialLat: lat, initialLng: lng),
    );
  }

  @override
  ConsumerState<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends ConsumerState<AddPlaceSheet> {
  final _labelController = TextEditingController();
  PlaceType _selectedType = PlaceType.home;
  double? _lat;
  double? _lng;
  bool _isLoadingGps = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    _labelController.text = _selectedType.displayName;

    if (_lat == null || _lng == null) {
      _fetchCurrentLocation();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final ownLocation = ref.read(ownLocationProvider).value;
      if (ownLocation != null && ownLocation.hasCoordinate) {
        if (mounted) {
          setState(() {
            _lat = ownLocation.lat;
            _lng = ownLocation.lng;
            _isLoadingGps = false;
          });
        }
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (mounted) {
        setState(() {
          _lat = pos?.latitude ?? _lat ?? 10.7769;
          _lng = pos?.longitude ?? _lng ?? 106.7009;
          _isLoadingGps = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lat ??= 10.7769;
          _lng ??= 106.7009;
          _isLoadingGps = false;
        });
      }
    }
  }

  void _onTypeChanged(PlaceType type) {
    HapticHelper.selection();
    setState(() {
      _selectedType = type;
      if (_labelController.text.isEmpty ||
          PlaceType.values.any((t) => t.displayName == _labelController.text)) {
        _labelController.text = type.displayName;
      }
    });
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có tọa độ vị trí. Vui lòng thử lại.')),
      );
      return;
    }

    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên địa điểm.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticHelper.medium();

    try {
      final place = PlaceModel(
        id: '',
        ownerUid: '',
        type: _selectedType,
        label: label,
        lat: _lat!,
        lng: _lng!,
        radiusMetres: 80.0,
        createdAt: DateTime.now(),
      );

      await ref.read(placesServiceProvider).savePlace(place);
      if (mounted) {
        HapticHelper.success();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã ghim ${_selectedType.defaultEmoji} $label thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu địa điểm: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161618) : Colors.white;
    final textTheme = Theme.of(context).textTheme;
    final placesAsync = ref.watch(userPlacesProvider);
    final userPlaces = placesAsync.value ?? const <PlaceModel>[];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 100 : 30),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pill handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Ghim Địa Điểm Mới',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Type Selector Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: PlaceType.values.map((type) {
                    final isSelected = type == _selectedType;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChanged(type),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(type.defaultEmoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                type.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),

              // Name TextField
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: 'Tên địa điểm',
                    hintText: 'VD: Nhà riêng, Văn phòng Q1...',
                    filled: true,
                    fillColor: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_selectedType.defaultEmoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Location coordinate status & refresh
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: _lat != null ? Colors.greenAccent : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isLoadingGps
                              ? 'Đang xác định vị trí GPS...'
                              : (_lat != null && _lng != null)
                                  ? 'Vị trí: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                                  : 'Chưa có vị trí',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoadingGps ? null : _fetchCurrentLocation,
                        child: const Text('Lấy lại GPS', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Save Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: (_lat != null && _lng != null && !_isSaving) ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Ghim ${_selectedType.defaultEmoji} Vào Bản Đồ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              // Existing places list
              if (userPlaces.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Địa điểm đã ghim (${userPlaces.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: userPlaces.length,
                  itemBuilder: (context, index) {
                    final p = userPlaces[index];
                    return ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                          shape: BoxShape.circle,
                        ),
                        child: Text(p.emoji, style: const TextStyle(fontSize: 18)),
                      ),
                      title: Text(
                        p.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${p.type.displayName} · Bán kính ${p.radiusMetres.round()}m',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        onPressed: () async {
                          HapticHelper.selection();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa địa điểm?'),
                              content: Text('Bạn có chắc muốn xóa "${p.label}" không?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(placesServiceProvider).deletePlace(p.id);
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
