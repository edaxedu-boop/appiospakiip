import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class RestaurantMapPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final bool isDark;

  const RestaurantMapPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    this.isDark = true,
  });

  /// Abre el picker de mapa y devuelve un mapa con { 'address': String, 'lat': double, 'lng': double } o null.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    double? lat,
    double? lng,
    String? address,
    bool isDark = true,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RestaurantMapPicker(
        initialLat: lat,
        initialLng: lng,
        initialAddress: address,
        isDark: isDark,
      ),
    );
  }

  @override
  State<RestaurantMapPicker> createState() => _RestaurantMapPickerState();
}

class _RestaurantMapPickerState extends State<RestaurantMapPicker> {
  static const Color _red = Color(0xFFFA7516);

  late Color _dialogBg;
  late Color _headerBg;
  late Color _fieldBg;
  late Color _border;
  late Color _textPrimary;
  late Color _textSecondary;
  late Color _textHint;
  late Color _btnOutlineText;

  late final TextEditingController _addressController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();

  LatLng _lastPick = const LatLng(
    -12.1219,
    -77.0282,
  ); // Miraflores, Lima default
  GoogleMapController? _mapController;

  bool _isSearching = false;
  final bool _isValidating =
      false; // Note: We might not need this anymore but keeping it
  bool _showError = false;
  List<dynamic> _suggestions = [];

  @override
  void initState() {
    super.initState();

    // Configuración adaptativa de colores
    if (widget.isDark) {
      _dialogBg = const Color(0xFF181A20);
      _headerBg = const Color(0xFF1F222A);
      _fieldBg = Colors.white.withValues(alpha: 0.05);
      _border = Colors.white10;
      _textPrimary = Colors.white;
      _textSecondary = Colors.white38;
      _textHint = Colors.white24;
      _btnOutlineText = Colors.white70;
    } else {
      _dialogBg = Colors.white;
      _headerBg = const Color(0xFFF9FAFB);
      _fieldBg = const Color(0xFFF3F4F6);
      _border = Colors.black.withValues(alpha: 0.05);
      _textPrimary = Colors.black87;
      _textSecondary = Colors.black54;
      _textHint = Colors.black26;
      _btnOutlineText = Colors.black54;
    }

    _addressController = TextEditingController(
      text: widget.initialAddress ?? '',
    );

    if (widget.initialLat != null && widget.initialLng != null) {
      _lastPick = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _searchController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final data = await ApiService.get(
        '/maps/geocode?latlng=${pos.latitude},${pos.longitude}',
      );
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final addr = data['results'][0]['formatted_address'];
        setState(() {
          _addressController.text = addr;
          _showError = false;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocode: $e');
    }
  }

  Future<bool> _searchAddress([String? customText]) async {
    final text = customText ?? _searchController.text.trim();
    if (text.isEmpty) return false;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    try {
      final data = await ApiService.get(
        '/maps/geocode?address=${Uri.encodeComponent(text)}',
      );
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final lat = result['geometry']['location']['lat'];
        final lng = result['geometry']['location']['lng'];

        final target = LatLng(lat, lng);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        setState(() {
          _lastPick = target;
          _addressController.text = result['formatted_address'];
          _addressController.text = result['formatted_address'];

          _showError = false;
          _suggestions = [];
          _searchController.clear();
        });
        return true;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
    return false;
  }

  Future<void> _getSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final data = await ApiService.get(
        '/maps/autocomplete?input=${Uri.encodeComponent(input)}',
      );
      if (data['status'] == 'OK') {
        setState(() => _suggestions = data['predictions']);
      } else {
        setState(() => _suggestions = []);
      }
    } catch (_) {
      setState(() => _suggestions = []);
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        final target = LatLng(pos.latitude, pos.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        setState(() => _lastPick = target);
      }
    } catch (_) {}
  }

  void _confirm() {
    final text = _addressController.text.trim();
    if (text.isEmpty) {
      setState(() => _showError = true);
      return;
    }

    String finalAddress = text;
    final reference = _referenceController.text.trim();
    if (reference.isNotEmpty) {
      finalAddress = '$text - ref: $reference';
    }

    Navigator.of(context).pop({
      'address': finalAddress,
      'lat': _lastPick.latitude,
      'lng': _lastPick.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: _dialogBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.5 : 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(color: _headerBg),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: _red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ubicación del cliente',
                            style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Ubica al cliente en el mapa',
                            style: GoogleFonts.poppins(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(color: _red, height: 2, width: double.infinity),

              // Search & Map
              Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search layout
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: _textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: GoogleFonts.poppins(
                                    color: _textPrimary,
                                  ),
                                  onChanged: _getSuggestions,
                                  onSubmitted: _searchAddress,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Buscar distrito, avenida...',
                                    hintStyle: GoogleFonts.poppins(
                                      color: _textHint,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isSearching)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: _red,
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: _red,
                                    size: 20,
                                  ),
                                  onPressed: () => _searchAddress(),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Map Container
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: widget.isDark ? 0.3 : 0.05,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Stack(
                            children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _lastPick,
                                  zoom: 16,
                                ),
                                myLocationEnabled: true,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                mapToolbarEnabled: false,
                                mapType: MapType.normal,
                                onMapCreated: (ctrl) =>
                                    setState(() => _mapController = ctrl),
                                onCameraIdle: () => _reverseGeocode(_lastPick),
                                onCameraMove: (pos) {
                                  setState(() {
                                    _lastPick = pos.target;
                                    _suggestions = [];
                                  });
                                },
                              ),
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 30),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 44,
                                    color: _red,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: FloatingActionButton.small(
                                  onPressed: _goToMyLocation,
                                  backgroundColor: _headerBg,
                                  foregroundColor: _red,
                                  elevation: 4,
                                  child: const Icon(Icons.my_location),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Read-only Text Field
                        Text(
                          'Dirección extraída (solo mapa)',
                          style: GoogleFonts.poppins(
                            color: _textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showError ? _red : _border,
                            ),
                          ),
                          child: TextField(
                            controller: _addressController,
                            readOnly: true, // Non-editable now
                            maxLines: 2,
                            minLines: 1,
                            style: GoogleFonts.poppins(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Reference Text Field
                        Text(
                          'Detalles de dirección (ej: Depa 302)',
                          style: GoogleFonts.poppins(
                            color: _textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: TextField(
                            controller: _referenceController,
                            style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              hintText: 'Opcional. Ej. Piso 4',
                              hintStyle: TextStyle(color: _textHint),
                            ),
                          ),
                        ),
                        if (_showError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              'Elige un punto válido en el mapa',
                              style: GoogleFonts.poppins(
                                color: _red,
                                fontSize: 11,
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: _border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.poppins(
                                    color: _btnOutlineText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isValidating ? null : _confirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 4,
                                ),
                                child: _isValidating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black87,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Aceptar',
                                        style: GoogleFonts.poppins(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Suggestions List is POSITIONED ON TOP OF EVERYTHING
                    if (_suggestions.isNotEmpty)
                      Positioned(
                        top: 55, // sits directly under the search field
                        left: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          elevation: 12,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: _headerBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: widget.isDark ? 0.5 : 0.1,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, _) =>
                                  Divider(color: _border, height: 1),
                              itemBuilder: (ctx, i) {
                                final s = _suggestions[i];
                                return ListTile(
                                  leading: Icon(
                                    Icons.location_on,
                                    color: _textSecondary,
                                    size: 18,
                                  ),
                                  title: Text(
                                    s['description'],
                                    style: GoogleFonts.poppins(
                                      color: _textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () => _searchAddress(s['description']),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
