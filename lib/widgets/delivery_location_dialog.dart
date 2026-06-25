import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

enum LocationDialogMode { login, register }

class DeliveryLocationDialog extends StatefulWidget {
  final LocationDialogMode mode;
  final String initialAddress;
  final double? initialLat;
  final double? initialLng;

  const DeliveryLocationDialog({
    super.key,
    required this.mode,
    this.initialAddress = '',
    this.initialLat,
    this.initialLng,
  });

  /// Show the dialog and wait for the user to confirm an address.
  /// Returns a Map with 'address', 'lat', and 'lng' or null if cancelled.
  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    LocationDialogMode mode, {
    String initialAddress = '',
    double? initialLat,
    double? initialLng,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeliveryLocationDialog(
        mode: mode,
        initialAddress: initialAddress,
        initialLat: initialLat,
        initialLng: initialLng,
      ),
    );
  }

  @override
  State<DeliveryLocationDialog> createState() => _DeliveryLocationDialogState();
}

class _DeliveryLocationDialogState extends State<DeliveryLocationDialog> {
  late final TextEditingController _addressController;
  bool _showError = false;
  bool _isSaving = false;
  List<dynamic> _suggestions = [];
  bool _isSearching = false;

  // State for interactive map
  LatLng _lastPick = const LatLng(-12.1219, -77.0282); // Miraflores, Lima
  GoogleMapController? _mapController;
  String _lastGeocodedAddress = '';
  bool _isValidating = false;

  final TextEditingController _searchController = TextEditingController();

  static const Color _red = Color(0xFFFA7516);
  static const Color _bg = Colors.white;
  static const Color _card = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _lastGeocodedAddress = widget.initialAddress;
    if (widget.initialLat != null && widget.initialLng != null) {
      _lastPick = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final text = _addressController.text.trim();
    if (text.isEmpty) {
      setState(() => _showError = true);
      return;
    }

    // Si el texto actual no es el último geocodificado bien, intentamos buscarlo una última vez
    if (text != _lastGeocodedAddress) {
      setState(() => _isValidating = true);
      final ok = await _searchAddress(text);
      setState(() => _isValidating = false);
      if (!ok) {
        setState(() => _showError = true);
        return;
      }
    }

    setState(() => _isSaving = true);

    // Guardar en la base de datos (silencioso si falla)
    try {
      await ApiService.putAuth('/auth/clients/me', {
        'delivery_address': _addressController.text.trim(),
        'lat': _lastPick.latitude,
        'lng': _lastPick.longitude,
      });
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop({
        'address': _addressController.text.trim(),
        'lat': _lastPick.latitude,
        'lng': _lastPick.longitude,
      });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final data = await ApiService.get(
        '/maps/geocode?latlng=${pos.latitude},${pos.longitude}',
      );
      if (!mounted) return;
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final addr = data['results'][0]['formatted_address'];
        setState(() {
          _addressController.text = addr;
          _lastGeocodedAddress = addr;
          _showError = false;
        });
      }
    } catch (e) {
      debugPrint('Error en reverse geocode: $e');
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
      if (!mounted) return false;
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final lat = result['geometry']['location']['lat'];
        final lng = result['geometry']['location']['lng'];

        final target = LatLng(lat, lng);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        setState(() {
          _lastPick = target;
          _addressController.text = result['formatted_address'];
          _lastGeocodedAddress = result['formatted_address'];
          _showError = false;
          _suggestions = []; // Limpiar sugerencias al buscar
          _searchController.clear(); // Limpiar el buscador del mapa
        });
        return true;
      }
    } catch (e) {
      debugPrint('Error en búsqueda: $e');
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
      if (!mounted) return;
      if (data['status'] == 'OK') {
        setState(() {
          _suggestions = data['predictions'];
        });
      } else {
        debugPrint(
          'Autocomplete status not OK: ${data['status']} - ${data['error_message']}',
        );
        setState(() {
          _suggestions = [];
        });
      }
    } catch (e) {
      debugPrint('Error suggestions: $e');
      setState(() {});
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
        if (!mounted) return;
        final target = LatLng(pos.latitude, pos.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        setState(() => _lastPick = target);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.mode == LocationDialogMode.login;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.hardEdge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Header ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(color: _card),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: _red,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLogin
                                ? '¿Dónde te entregamos?'
                                : 'Configura tu dirección',
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            isLogin
                                ? 'Confirma o cambia tu dirección de entrega'
                                : 'Indica dónde quieres recibir tus pedidos',
                            style: GoogleFonts.poppins(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Interactive Google Map ──────────────────────────────────
              SizedBox(
                height: 250,
                width: double.infinity,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _lastPick,
                        zoom: 16,
                      ),
                      onMapCreated: (c) => _mapController = c,
                      onCameraMove: (pos) =>
                          setState(() => _lastPick = pos.target),
                      onCameraIdle: () => _reverseGeocode(_lastPick),
                      markers: {
                        Marker(
                          markerId: const MarkerId('current_pick'),
                          position: _lastPick,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                    ),

                    // ── Search Bar Overlay ──
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 60, // Dejar espacio para el botón de ubicación
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _getSuggestions,
                              onSubmitted: (v) => _searchAddress(v),
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Buscar calle o lugar...',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.black38,
                                  fontSize: 13,
                                ),
                                prefixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _red,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.search_rounded,
                                        color: _red,
                                        size: 18,
                                      ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          if (_suggestions.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black12,
                                  width: 1,
                                ),
                              ),
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _suggestions.length,
                                separatorBuilder: (_, _) => const Divider(
                                  color: Colors.black12,
                                  height: 1,
                                ),
                                itemBuilder: (ctx, i) {
                                  final s = _suggestions[i];
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Text(
                                      s['description'],
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    onTap: () {
                                      _searchController.text = s['description'];
                                      _searchAddress(s['description']);
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    // My Location Button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: FloatingActionButton.small(
                          onPressed: _goToMyLocation,
                          backgroundColor: Colors.white,
                          elevation: 0,
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: _red,
                          ),
                        ),
                      ),
                    ),
                    // Floating Center Pin
                    IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 35),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_pin,
                                color: _red,
                                size: 45,
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Address field ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dirección de entrega',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _showError ? _red : Colors.black12,
                          width: _showError ? 1.5 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _addressController,
                        readOnly: true,
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Usa el buscador arriba o mueve el mapa...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.black26,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            color: _red,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    if (_showError) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: _red,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _addressController.text.trim().isEmpty
                                  ? 'Por favor indica una ubicación'
                                  : 'Dirección no válida o no encontrada',
                              style: GoogleFonts.poppins(
                                color: _red,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ─── Confirm button ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (_isSaving || _isValidating) ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Colors.black87.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: (_isSaving || _isValidating)
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Confirmar dirección',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
