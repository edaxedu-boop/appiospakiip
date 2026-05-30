import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/api_service.dart';
import 'package:pakiip/screens/auth/login_screen.dart';
import 'package:pakiip/screens/rider/rider_orders_screen.dart';
import 'package:pakiip/screens/rider/rider_history_screen.dart';
import 'package:pakiip/screens/rider/rider_payments_screen.dart';

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RiderPanelScreen extends StatefulWidget {
  final String riderName;
  const RiderPanelScreen({super.key, required this.riderName});

  @override
  State<RiderPanelScreen> createState() => _RiderPanelScreenState();
}

class _RiderPanelScreenState extends State<RiderPanelScreen> {
  String _currentStatus = 'offline';
  bool _isUpdatingStatus = false;
  double _balance = 0.00;
  final double _tipsToday = 0.00;
  final int _ordersToday = 0;
  int _pendingOrders = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  String? _currentAddress;
  bool _isLocating = false;
  Timer? _locationTimer;

  static const Color _bg = Colors.white;
  static const Color _red = Color(0xFFFA7516);
  static const Color _cardDark = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _loadStats();
    _startPolling();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentStatus == 'online' || _currentStatus == 'busy') {
        _silentlyUpdateLocation();
        _checkNewOrders();
      }
    });
  }

  Future<void> _checkNewOrders() async {
    try {
      final available = await ApiService.getList('/riders/orders/available');
      int availableCount = available.length;

      // Si de pronto hay más pedidos disponibles que antes
      if (availableCount > 0 &&
          availableCount >
              (_pendingOrders -
                  (_ordersToday > 0 ? 1 : 0) /* aproximación */ )) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡NUEVO PEDIDO DISPONIBLE PARA REPARTIR!',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: _red,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'VER',
                textColor: Colors.black87,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RiderOrdersScreen(riderName: widget.riderName),
                    ),
                  ).then((_) => _loadStats());
                },
              ),
            ),
          );
        }
      }
      _loadStats(silent: true);
    } catch (_) {}
  }

  Future<void> _silentlyUpdateLocation() async {
    if (_profile == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ApiService.patch('/riders/${_profile!['id']}/location', {
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (_) {}
  }

  Future<void> _loadStats({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final available = await ApiService.getList('/riders/orders/available');
      final active = await ApiService.get('/riders/orders/active');
      final profile = await ApiService.get('/riders/me');
      final earnings = await ApiService.get('/riders/earnings');

      int count = available.length;
      if (active.isNotEmpty) count++;

      if (mounted) {
        setState(() {
          _pendingOrders = count;
          _profile = profile;
          _currentStatus = profile['status'] ?? 'offline';

          // Use the pending payout from the API for the main balance display
          _balance =
              double.tryParse(earnings['pending_payout']?.toString() ?? '0') ??
              0.0;

          _isLoading = false;
        });

        // Autolocate if online or busy and we lack local address
        if ((_currentStatus == 'online' || _currentStatus == 'busy') &&
            _currentAddress == null) {
          _getCurrentLocation();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() {
    ApiService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: _red,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // ── Header ─────────────────────────────────────────────────────
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // ── Greeting & Balance ──────────────────────────────────────────
                      Text(
                        'Hola, ${widget.riderName.split(' ')[0]}',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(text: 'Balance: '),
                            TextSpan(
                              text: 'S/. ${_balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ── Service Status Toggle ───────────────────────────────────────
                      _buildStatusToggle(),
                      const SizedBox(height: 16),
                      _buildLocationCard(),
                      const SizedBox(height: 30),

                      // ── Main Action Cards ───────────────────────────────────────────
                      _buildBigCard(
                        title: 'Gestionar\nPedidos',
                        subtitle: 'Ver entregas actuales',
                        icon: Icons.local_shipping_rounded,
                        isPrimary: true,
                        tag: '$_pendingOrders Pedidos',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RiderOrdersScreen(riderName: widget.riderName),
                          ),
                        ).then((_) => _loadStats()),
                      ),
                      const SizedBox(height: 16),

                      _buildBigCard(
                        title: 'Historial de\nPedidos',
                        subtitle: 'Registro de entregas',
                        icon: Icons.history_rounded,
                        isPrimary: false,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RiderHistoryScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildBigCard(
                        title: 'Mis\nPagos',
                        subtitle: 'Ingresos acumulados',
                        icon: Icons.payments_outlined,
                        isPrimary: false,
                        extra: 'S/.',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RiderPaymentsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSupportSection(),
                      const SizedBox(height: 40),

                      // ── Bottom Stats ───────────────────────────────────────────────
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'VIAJES HOY',
                              style: GoogleFonts.poppins(
                                color: Colors.black38,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '$_ordersToday',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _profileAvatar(20, _profile?['image_url']),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAKIIP APP',
                style: GoogleFonts.poppins(
                  color: Colors.black38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Panel de Repartidor',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _headerAction(Icons.settings_rounded, _showProfileSheet),
        const SizedBox(width: 8),
        _headerAction(Icons.logout_rounded, _logout),
      ],
    );
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _red, size: 20),
      ),
    );
  }

  Widget _profileAvatar(double radius, String? url) {
    final hasImg = url != null && url.isNotEmpty;
    final fullUrl = hasImg
        ? (url.startsWith('http') ? url : '${ApiService.baseUrl}$url')
        : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white10,
      backgroundImage: hasImg ? NetworkImage(fullUrl!) : null,
      child: !hasImg
          ? Text(
              widget.riderName[0].toUpperCase(),
              style: GoogleFonts.poppins(
                color: _red,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }

  void _showProfileSheet() {
    if (_profile == null) return;

    final nameCtrl = TextEditingController(text: _profile!['name']);
    final phoneCtrl = TextEditingController(text: _profile!['phone']);
    final emailCtrl = TextEditingController(text: _profile!['email']);
    String? currentImg = _profile!['image_url'];
    bool saving = false;
    bool picking = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Configurar Perfil',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Mantén tus datos actualizados',
                style: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
              ),
              const SizedBox(height: 30),

              Center(
                child: Stack(
                  children: [
                    _profileAvatar(45, currentImg),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () async {
                          if (picking) return;
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 75,
                          );
                          if (file != null) {
                            setS(() => picking = true);
                            try {
                              final res = await ApiService.uploadFile(
                                '/upload/profile',
                                file.path,
                              );
                              final newUrl = res['imageUrl'];
                              setS(() {
                                currentImg = newUrl;
                                picking = false;
                              });
                            } catch (e) {
                              setS(() => picking = false);
                              _snack('Error al subir imagen: $e');
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle,
                          ),
                          child: picking
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    color: Colors.black87,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.black87,
                                  size: 14,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              _profileField(nameCtrl, 'Nombre Completo', Icons.person_outline),
              const SizedBox(height: 16),
              _profileField(
                phoneCtrl,
                'WhatsApp / Teléfono',
                Icons.phone_android_rounded,
              ),
              const SizedBox(height: 16),
              _profileField(
                emailCtrl,
                'Correo Electrónico',
                Icons.email_outlined,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setS(() => saving = true);
                          try {
                            await ApiService.patch('/riders/me', {
                              'name': nameCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'image_url': currentImg,
                            });
                            _loadStats();
                            if (mounted) Navigator.pop(ctx);
                            _snack('Perfil actualizado', isError: false);
                          } catch (e) {
                            setS(() => saving = false);
                            _snack('Error: $e');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black87,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'GUARDAR CAMBIOS',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
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

  Widget _profileField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          icon: Icon(icon, color: _red, size: 20),
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
        ),
        backgroundColor: isError ? _red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStatusToggle() {
    final bool isOnlineOrBusy =
        _currentStatus == 'online' || _currentStatus == 'busy';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: (isOnlineOrBusy && _currentAddress != null)
                  ? (_currentStatus == 'busy' ? Colors.orange : Colors.red)
                  : Colors.grey,
              shape: BoxShape.circle,
              boxShadow: [
                if (isOnlineOrBusy && _currentAddress != null)
                  BoxShadow(
                    color:
                        (_currentStatus == 'busy' ? Colors.orange : Colors.red)
                            .withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado del Servicio',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _currentStatus == 'busy'
                      ? 'Ocupado (Entregando)'
                      : (isOnlineOrBusy && _currentAddress != null)
                      ? 'En línea para recibir pedidos'
                      : (isOnlineOrBusy
                            ? 'En línea (Esperando GPS)'
                            : 'Desconectado'),
                  style: GoogleFonts.poppins(
                    color: _currentStatus == 'busy'
                        ? Colors.orange
                        : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _isUpdatingStatus
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: _red, strokeWidth: 2),
                )
              : Switch(
                  value: isOnlineOrBusy,
                  onChanged: _currentStatus == 'busy'
                      ? null // DISABLED if busy
                      : (v) async {
                          if (v && _currentAddress == null) {
                            _snack(
                              'Debes obtener tu ubicación para activar el servicio',
                            );
                            return;
                          }

                          setState(() => _isUpdatingStatus = true);
                          try {
                            await ApiService.patch(
                              '/riders/${_profile!['id']}/status',
                              {'status': v ? 'online' : 'offline'},
                            );
                            setState(
                              () => _currentStatus = v ? 'online' : 'offline',
                            );
                          } catch (e) {
                            _snack('Error al cambiar estado: $e');
                          } finally {
                            setState(() => _isUpdatingStatus = false);
                          }
                        },
                  activeThumbColor: Colors.black87,
                  activeTrackColor: _currentStatus == 'busy'
                      ? Colors.orange
                      : _red,
                  inactiveTrackColor: Colors.white10,
                ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: _red, size: 18),
              const SizedBox(width: 8),
              Text(
                'Mi Ubicación Actual',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: _red,
                        strokeWidth: 2,
                      ),
                    )
                  : GestureDetector(
                      onTap: _getCurrentLocation,
                      child: Text(
                        'ACTUALIZAR',
                        style: GoogleFonts.poppins(
                          color: _red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentAddress ?? 'Ubicación no detectada aún',
            style: GoogleFonts.poppins(
              color: _currentAddress == null ? Colors.black26 : Colors.black54,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('Los servicios de ubicación están desactivados.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _snack('Permisos de ubicación denegados.');
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition();

      // Get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      String addr = 'Ubicación detectada';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        addr = "${p.street}, ${p.subLocality}, ${p.locality}";
      }

      setState(() {
        _currentAddress = addr;
      });

      // Update backend
      if (_profile != null) {
        await ApiService.patch('/riders/${_profile!['id']}/location', {
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
      }
    } catch (e) {
      _snack('Error de ubicación: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showManualLocationDialog() async {
    final LatLng initial = const LatLng(-12.0463, -77.0427); // Lima default

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _MapPickerDialog(initial: initial),
    );

    if (result != null && result['location'] != null) {
      final loc = result['location'] as LatLng;
      final addr = result['address'] as String?;
      _updateManualLocation(loc.latitude, loc.longitude, addr);
    }
  }

  Future<void> _updateManualLocation(
    double lat,
    double lng,
    String? address,
  ) async {
    setState(() => _isLocating = true);
    try {
      if (_profile != null) {
        await ApiService.patch('/riders/${_profile!['id']}/location', {
          'lat': lat,
          'lng': lng,
        });
        setState(() {
          _currentAddress = address ?? "Simulada: $lat, $lng";
        });
        _snack('Ubicación manual guardada', isError: false);
      }
    } catch (e) {
      _snack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: _red, size: 24),
              const SizedBox(width: 12),
              Text(
                'Soporte Técnico',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _supportItem(Icons.phone_rounded, 'WhatsApp', '+51 910 318 809'),
          const SizedBox(height: 12),
          _supportItem(
            Icons.email_outlined,
            'Correo',
            'pakiipglobal@gmail.com',
          ),
        ],
      ),
    );
  }

  Widget _supportItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.black45, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBigCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
    String? tag,
    String? extra,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: isPrimary ? _red : _cardDark,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isPrimary
                ? _red.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: [
            // Efecto de profundidad 3D
            BoxShadow(
              color: isPrimary
                  ? const Color(0xFFA14500).withValues(
                      alpha: 0.4,
                    ) // Sombra naranja oscura para el primario
                  : Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
            // Sombra suave de elevación
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Faint background icon
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon == Icons.local_shipping_rounded
                    ? Icons.shopping_basket_rounded
                    : icon,
                size: 140,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(icon, color: Colors.black87, size: 32),
                      if (tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              color: _red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (extra != null)
                        Text(
                          extra,
                          style: GoogleFonts.poppins(
                            color: _red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: isPrimary ? Colors.white70 : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  'Fijar ubicación manual (Test)',
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
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
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar dirección...',
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(color: Colors.black12, height: 1),
                            itemBuilder: (ctx, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  s['description'],
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
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
                    elevation: 4,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
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
                              color: Colors.black87,
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
                  'Confirmar Ubicación Test',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
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
