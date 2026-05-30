import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../../services/api_service.dart';
import 'package:pakiip/screens/auth/login_screen.dart';
import '../../widgets/rider_request_sheet.dart';
import 'package:pakiip/screens/auth/change_password_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_categories_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_delivery_config_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_orders_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_products_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_profile_config_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_history_screen.dart';

class RestaurantPanelScreen extends StatefulWidget {
  final String restaurantName;

  const RestaurantPanelScreen({super.key, required this.restaurantName});

  @override
  State<RestaurantPanelScreen> createState() => _RestaurantPanelScreenState();
}

class _RestaurantPanelScreenState extends State<RestaurantPanelScreen> {
  bool _isOpen = true;
  int _pendingOrdersCount = 0;
  double _accumulatedCommission = 0.0;
  Map<String, dynamic>? _restaurantData;

  // Notificaciones de sonido y sistema
  late final AudioPlayer _audioPlayer;
  late final FlutterLocalNotificationsPlugin _localNotifications;
  bool _isAlarmPlaying = false;
  Timer? _pollingTimer;
  int _lastNotificationOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initLocalNotifications();
    _loadOpenStatus();
    _loadPendingOrders();
    // Polling cada 10 segundos para nuevos pedidos
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (t) => _checkNewOrders(),
    );
  }

  void _initLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
  }

  Future<void> _showSystemNotification(int count) async {
    const androidDetails = AndroidNotificationDetails(
      'pakiip_orders',
      'Pedidos Pakiip',
      channelDescription: 'Notificaciones de nuevos pedidos',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      0,
      '¡Nuevo Pedido en Pakiip!',
      'Tienes $count ${count == 1 ? 'pedido pendiente' : 'pedidos pendientes'}. ¡Confírmalos ahora!',
      notificationDetails,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkNewOrders() async {
    try {
      _loadOpenStatus(); // Mantener el estado de abierto/cerrado actualizado
      final orders = await ApiService.getList('/orders/restaurant/all');
      bool hasPending = false;
      int count = 0;

      for (var o in orders) {
        if (o['status'] == 'pending') {
          hasPending = true;
        }
        if (['pending', 'accepted', 'preparing'].contains(o['status'])) {
          count++;
        }
      }

      // Gestionar alarma y notificación de sistema
      if (hasPending) {
        if (!_isAlarmPlaying) _startAlarm();

        // Solo mostrar notificación de sistema si el conteo actual es mayor al de la última notificación
        // para no spamear la barra de notificaciones cada 10 segundos.
        if (count > _lastNotificationOrderCount) {
          _showSystemNotification(count);
          _lastNotificationOrderCount = count;
        }
      } else {
        if (_isAlarmPlaying) _stopAlarm();
        _lastNotificationOrderCount = 0;
      }

      if (mounted) {
        setState(() => _pendingOrdersCount = count);
      }
    } catch (e) {
      debugPrint('Error polling orders: $e');
    }
  }

  void _startAlarm() async {
    try {
      _isAlarmPlaying = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Bell sound preview (Mixkit)
      await _audioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
      );
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _stopAlarm() async {
    try {
      _isAlarmPlaying = false;
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      final orders = await ApiService.getList('/orders/restaurant/all');
      int count = 0;
      double commission = 0.0;
      for (var order in orders) {
        if (order['status'] == 'pending' ||
            order['status'] == 'accepted' ||
            order['status'] == 'preparing') {
          count++;
        }

        // Sumar comisiones de pedidos entregados (delivered)
        if (order['status'] == 'delivered' &&
            order['restaurant_commission'] != null) {
          commission += (order['restaurant_commission'] as num).toDouble();
        }
      }
      if (mounted) {
        setState(() {
          _pendingOrdersCount = count;
          _accumulatedCommission = commission;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOpenStatus() async {
    try {
      final data = await ApiService.get('/restaurants/me');
      if (mounted) setState(() => _restaurantData = data);
      final schedule = data['schedule'] as List<dynamic>?;

      // Fecha y hora actual en Lima (UTC-5)
      final nowLima = DateTime.now().toUtc().subtract(const Duration(hours: 5));

      // Nombre del día en español (coincidir con DB y Backend)
      const dayNames = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      // DateTime.weekday: 1=Lunes, 7=Domingo
      final todayName = dayNames[nowLima.weekday - 1]; 
      final currentMinutes = nowLima.hour * 60 + nowLima.minute;

      // ── Calcular si estamos en horario abierto ─────────────────────
      bool isOpenBySchedule = true; // sin horario = siempre abierto

      if (schedule != null && schedule.isNotEmpty) {
        isOpenBySchedule = false; // Por defecto cerrado si tiene horario
        final todayConfig = schedule.firstWhere(
          (s) => s['day'] == todayName,
          orElse: () => null,
        );
        if (todayConfig != null) {
          if (todayConfig['enabled'] == false) {
            isOpenBySchedule = false;
          } else {
            final openParts = (todayConfig['open'] as String? ?? '00:00').split(
              ':',
            );
            final closeParts = (todayConfig['close'] as String? ?? '23:59')
                .split(':');
            final openMins =
                int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
            final closeMins =
                int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
            isOpenBySchedule =
                currentMinutes >= openMins &&
                currentMinutes <= closeMins;
          }
        }
      }

      if (mounted) setState(() => _isOpen = isOpenBySchedule);
    } catch (_) {}
  }


  static const Color _bg = Colors.white;
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _cardAlt = Color(0xFFF3F4F6);
  static const Color _red = Color(0xFFFA7516);

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cerrar sesión',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Deseas salir del panel?',
          style: GoogleFonts.poppins(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.black45),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _stopAlarm(); // Detener sonido si está sonando antes de irse
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Salir',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Al tocar "Solicitar Repartidor" → formulario directo
  void _showRequestRiderSheet(BuildContext context) {
    _showRiderDetailSheet(
      context,
      order: {'id': '', 'client': '', 'total': 0.0, 'address': '', 'phone': ''},
    );
  }

  // ── Formulario de solicitud de repartidor (campos editables) ─────────────
  void _showRiderDetailSheet(
    BuildContext context, {
    required Map<String, dynamic> order,
  }) {
    if (_restaurantData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron datos del restaurante')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => RiderRequestSheet(
        rawOrder: order,
        restaurantData: _restaurantData!,
        isDark: false,
      ),
    );
  }

  String _getRemainingDays(dynamic expiry) {
    if (expiry == null) return 'Vitalicio';
    try {
      final expiryDate = DateTime.parse(expiry.toString());
      final diff = expiryDate.difference(DateTime.now()).inDays;
      return diff < 0 ? 'Expirado' : '$diff días';
    } catch (_) {
      return '--';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ─── Top Bar ───────────────────────────────────────────────
              Row(
                children: [
                  // Back / logout button
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: _red,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Panel de\nRestaurante',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                  ),
                  // Status indicator (read only)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOpen 
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOpen 
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                          : Colors.white10,
                      )
                    ),
                    child: Text(
                      _isOpen ? 'ABIERTO' : 'CERRADO',
                      style: GoogleFonts.poppins(
                        color: _isOpen
                            ? const Color(0xFF4CAF50)
                            : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── Rest scrolls ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Text(
                        'Hola, ${widget.restaurantName}',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gestiona tu restaurante Pakiip de forma\nsencilla y rápida.',
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Plan Card
                      if (_restaurantData != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _red.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _restaurantData!['plan_id'] == 1
                                      ? Icons.rocket_launch
                                      : Icons.workspace_premium,
                                  color: _red,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PLAN PAKIIP: ${(_restaurantData!['plan_name']?.toString() ?? 'DESCONOCIDO').toUpperCase()}',
                                      style: GoogleFonts.poppins(
                                        color: _red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (_restaurantData!['plan_id'] == 1)
                                      Text(
                                        'Comisión: ${_restaurantData!['commission_rate'] ?? '0'}% por venta',
                                        style: GoogleFonts.poppins(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Días restantes: ${_getRemainingDays(_restaurantData!['plan_expiry'])}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 18),

                      // Grid row 1
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildGridTile(
                              icon: Icons.person_outline,
                              label: 'Configurar\nPerfil',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RestaurantProfileConfigScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            _buildGridTile(
                              icon: Icons.category_outlined,
                              label: 'Editar\nCategorías',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RestaurantCategoriesScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Grid row 2
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildGridTile(
                              icon: Icons.restaurant_menu,
                              label: 'Editar\nProductos',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RestaurantProductsScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            _buildGridTile(
                              icon: Icons.access_time_rounded,
                              label: 'Configurar\nHorario',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RestaurantDeliveryConfigScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildGridTile(
                              icon: Icons.lock_reset_rounded,
                              label: 'Cambiar\nContraseña',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChangePasswordScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            _buildGridTile(
                              icon: Icons.history_rounded,
                              label: 'Historial de\nPedidos',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RestaurantHistoryScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Solicitar Repartidor
                      GestureDetector(
                        onTap: () => _showRequestRiderSheet(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C0F0F),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(
                                0xFFFA7516,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFA7516,
                                  ).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delivery_dining_rounded,
                                  color: Color(0xFFFA7516),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Solicitar Repartidor',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Asigna un repartidor a un pedido',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFFFA7516),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Gestionar Pedidos
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RestaurantOrdersScreen(),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Colors.black87,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gestionar Pedidos',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '$_pendingOrdersCount pedidos pendientes hoy',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.black87,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      _buildSupportSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
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

  Widget _buildGridTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: _cardAlt,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _red, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}






