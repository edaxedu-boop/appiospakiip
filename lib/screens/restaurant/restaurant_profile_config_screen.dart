import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';

class RestaurantProfileConfigScreen extends StatefulWidget {
  const RestaurantProfileConfigScreen({super.key});

  @override
  State<RestaurantProfileConfigScreen> createState() =>
      _RestaurantProfileConfigScreenState();
}

class _RestaurantProfileConfigScreenState
    extends State<RestaurantProfileConfigScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descController = TextEditingController();

  String? _serverImageUrl;
  String? _localImagePath;

  LatLng? _selectedLocation;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  List<Map<String, dynamic>> _allCategories = [];
  List<int> _selectedCategoryIds = [];
  String _selectedRegion = 'Otras';

  static const _regions = [
    'Amazonas',
    'Áncash',
    'Apurímac',
    'Arequipa',
    'Ayacucho',
    'Cajamarca',
    'Callao',
    'Cusco',
    'Huancavelica',
    'Huánuco',
    'Ica',
    'Junín',
    'La Libertad',
    'Lambayeque',
    'Lima',
    'Loreto',
    'Madre de Dios',
    'Moquegua',
    'Pasco',
    'Piura',
    'Puno',
    'San Martín',
    'Tacna',
    'Tumbes',
    'Ucayali',
    'Otras',
  ];

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _fieldBg = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFF2E1A1A);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.get('/restaurants/me');
      final cats = await ApiService.getList('/restaurant-categories/public');

      if (!mounted) return;

      setState(() {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _mapsController.text = data['google_maps_url'] ?? '';
        _descController.text = data['description'] ?? '';
        _serverImageUrl = data['logo_url'];
        _selectedCategoryIds =
            (data['category_ids'] as List?)?.cast<int>() ?? [];
        _selectedRegion = data['region'] ?? 'Otras';

        // Parse coordinates from text or geo
        if (data['lat'] != null && data['lng'] != null) {
          _selectedLocation = LatLng(
            double.parse(data['lat'].toString()),
            double.parse(data['lng'].toString()),
          );
        }

        _allCategories = cats.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _snack('Error al cargar perfil: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _fieldBg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _red),
              title: const Text(
                'Cámara',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _red),
              title: const Text(
                'Galería',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() {
          _localImagePath = pickedFile.path;
          _isUploading = true;
        });

        try {
          final res = await ApiService.uploadFile(
            '/upload/restaurant/hero',
            pickedFile.path,
          );
          setState(() {
            _serverImageUrl = res['imageUrl'];
            _isUploading = false;
          });
          _snack('✓ Imagen optimizada y subida', Colors.green);
        } catch (e) {
          setState(() => _isUploading = false);
          _snack('Error al subir imagen: $e', Colors.red);
        }
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.put('/restaurants/me', {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'google_maps_url': _mapsController.text.trim(),
        'description': _descController.text.trim(),
        'logo_url': _serverImageUrl,
        'category_ids': _selectedCategoryIds,
        'region': _selectedRegion,
        'lat': _selectedLocation?.latitude,
        'lng': _selectedLocation?.longitude,
      });
      setState(() => _isSaving = false);
      _snack('✓ Cambios guardados correctamente', _red);
    } catch (e) {
      setState(() => _isSaving = false);
      _snack('Error al guardar: $e', Colors.red);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _mapsController.dispose();
    _phoneController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Construir URL completa
    final fullImageUrl = _serverImageUrl != null
        ? (_serverImageUrl!.startsWith('http')
              ? _serverImageUrl
              : '${ApiService.baseUrl}$_serverImageUrl')
        : null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _red),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configurar Perfil',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Cover Image Real/Upload ---
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: _fieldBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _border,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: _localImagePath != null
                                      ? (kIsWeb
                                            ? Image.network(
                                                _localImagePath!,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(_localImagePath!),
                                                fit: BoxFit.cover,
                                              ))
                                      : (fullImageUrl != null
                                            ? Image.network(
                                                fullImageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    const _DefaultIllustration(),
                                              )
                                            : const _DefaultIllustration()),
                                ),
                              ),
                              if (_isUploading)
                                Container(
                                  width: double.infinity,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: _red,
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: -12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: _isUploading ? null : _pickImage,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: _red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black45,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Imagen de Portada',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Toca el icono para subir y optimizar peso',
                                style: GoogleFonts.poppins(
                                  color: Colors.black38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildLabel('Nombre del Local'),
                        const SizedBox(height: 6),
                        _buildField(
                          controller: _nameController,
                          hint: 'Ej. La Trattoria Pakiip',
                          prefixIcon: Icons.storefront_outlined,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Dirección'),
                        const SizedBox(height: 6),
                        _buildField(
                          controller: _addressController,
                          hint: 'Usa el selector de mapa para fijar dirección',
                          prefixIcon: Icons.location_on_outlined,
                          readOnly: true,
                          onTap: _showLocationPicker,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Ubicación en Mapa (GPS)'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _showLocationPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _fieldBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedLocation != null
                                    ? _red
                                    : _border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: _selectedLocation != null
                                      ? _red
                                      : Colors.black26,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedLocation != null
                                        ? 'Ubicación fijada (${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)})'
                                        : 'Toca para fijar en el mapa',
                                    style: GoogleFonts.poppins(
                                      color: _selectedLocation != null
                                          ? Colors.black87
                                          : Colors.black26,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_location_alt_outlined,
                                  color: Colors.black38,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Teléfono de Contacto'),
                        const SizedBox(height: 6),
                        _buildField(
                          controller: _phoneController,
                          hint: '+51 987 654 321',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Región (Departamento)'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRegion,
                              isExpanded: true,
                              dropdownColor: _fieldBg,
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: _red,
                              ),
                              items: _regions.map((String reg) {
                                return DropdownMenuItem<String>(
                                  value: reg,
                                  child: Text(reg),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() => _selectedRegion = newValue);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Descripción del Restaurante'),
                        const SizedBox(height: 6),
                        _buildField(
                          controller: _descController,
                          hint: 'Especialidad, tipos de platos, etc...',
                          prefixIcon: null,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),

                        _buildLabel('Categorías (Multi-selección)'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allCategories.map((c) {
                            final id = c['id'] as int;
                            final isSel = _selectedCategoryIds.contains(id);
                            return FilterChip(
                              selected: isSel,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _selectedCategoryIds.add(id);
                                  } else {
                                    _selectedCategoryIds.remove(id);
                                  }
                                });
                              },
                              label: Text(c['name'] ?? ''),
                              labelStyle: GoogleFonts.poppins(
                                color: isSel ? Colors.white : Colors.black54,
                                fontSize: 12,
                              ),
                              backgroundColor: _fieldBg,
                              selectedColor: _red.withValues(alpha: 0.8),
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: isSel ? _red : _border),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // --- Guardar Cambios button ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black87,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.save_rounded,
                              color: Colors.black87,
                              size: 20,
                            ),
                      label: Text(
                        _isSaving ? 'Guardando...' : 'Guardar Cambios',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showLocationPicker() async {
    final LatLng initial =
        _selectedLocation ?? const LatLng(-12.0463, -77.0427); // Lima default

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _MapPickerDialog(initial: initial),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result['location'] as LatLng;
        if (result['address'] != null) {
          _addressController.text = result['address'] as String;
        }
      });
    }
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData? prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.black26, fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: _red, size: 20)
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: prefixIcon == null ? 16 : 0,
            vertical: maxLines > 1 ? 14 : 16,
          ),
        ),
      ),
    );
  }
}

// Ilustración por defecto si no hay imagen
class _DefaultIllustration extends StatelessWidget {
  const _DefaultIllustration();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF7D8C6E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(size: const Size(60, 60), painter: _PlantPainter()),
            const SizedBox(height: 10),
            Text(
              'RESTAURANT',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            Text(
              'SIN PORTADA AÚN',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final archRect = Rect.fromCenter(
      center: Offset(cx, cy + 8),
      width: 64,
      height: 68,
    );
    canvas.drawArc(archRect, 3.14, 3.14, false, paint);
    canvas.drawLine(Offset(cx, cy + 42), Offset(cx, cy - 10), paint);
    final leftPath = Path()
      ..moveTo(cx, cy + 10)
      ..quadraticBezierTo(cx - 22, cy - 8, cx - 10, cy - 20)
      ..quadraticBezierTo(cx - 4, cy, cx, cy + 10);
    canvas.drawPath(leftPath, paint);
    final rightPath = Path()
      ..moveTo(cx, cy + 2)
      ..quadraticBezierTo(cx + 22, cy - 15, cx + 8, cy - 26)
      ..quadraticBezierTo(cx + 2, cy - 8, cx, cy + 2);
    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPickerDialog extends StatefulWidget {
  final LatLng initial;
  const _MapPickerDialog({required this.initial});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late LatLng _current;
  String _currentAddress = 'Cargando dirección...';
  bool _isGeocoding = false;
  GoogleMapController? _mapController;

  final _searchController = TextEditingController();
  List<dynamic> _suggestions = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _reverseGeocode(_current);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isGeocoding = true);
    try {
      final data = await ApiService.get(
        '/maps/geocode?latlng=${pos.latitude},${pos.longitude}',
      );
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        setState(() {
          _currentAddress = data['results'][0]['formatted_address'];
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocode: $e');
    } finally {
      setState(() => _isGeocoding = false);
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
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
        setState(() => _current = target);
        _reverseGeocode(target);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _searchAddress([String? customText]) async {
    final text = customText ?? _searchController.text.trim();
    if (text.isEmpty) return;

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
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
        setState(() {
          _current = target;
          _currentAddress = result['formatted_address'];
          _suggestions = [];
        });
      }
    } catch (e) {
      debugPrint('Error search address: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
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
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.map, color: Color(0xFFFA7516)),
                const SizedBox(width: 12),
                Text(
                  'Fijar ubicación de tu local',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.black45),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _current,
                    zoom: 17,
                  ),
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  onCameraMove: (pos) => setState(() => _current = pos.target),
                  onCameraIdle: () => _reverseGeocode(_current),
                  markers: {
                    Marker(
                      markerId: const MarkerId('local_pick'),
                      position: _current,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // ── Search Bar ──
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _getSuggestions,
                          onSubmitted: (v) => _searchAddress(v),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar dirección...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white54,
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
                                        color: Color(0xFFFA7516),
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.search,
                                    color: Color(0xFFFA7516),
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
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (ctx, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  s['description'],
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () => _searchAddress(s['description']),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                // My Location Button
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: _goToMyLocation,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.my_location,
                      color: Color(0xFFFA7516),
                    ),
                  ),
                ),
                // Center Pin
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 35),
                      child: Icon(
                        Icons.location_pin,
                        color: Color(0xFFFA7516),
                        size: 40,
                      ),
                    ),
                  ),
                ),
                // Address Indicator
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFFA7516),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentAddress,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isGeocoding)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFA7516),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'location': _current,
                    'address': _currentAddress,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFA7516),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirmar Ubicación',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
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
