import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import 'dart:async';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0; // 0: Activos, 1: Historial
  bool _isLoading = true;
  List<dynamic> _activeOrders = [];
  List<dynamic> _historyOrders = [];
  double _serviceFee = 1.0; 
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _startTimer();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _selectedTab == 0) { // Solo actualizar si está en tab de Activos
        _loadOrders(silent: true);
      }
    });
  }

  Future<void> _loadOrders({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() => _isLoading = true);
      }
      try {
        final config = await ApiService.get('/config/public');
        if (config['service_fee'] != null) {
          _serviceFee = double.tryParse(config['service_fee'].toString()) ?? 1.0;
        }
      } catch (_) {}

      final data = await ApiService.getList('/orders/my');
      final active = [];
      final history = [];

      for (var order in data) {
        if (['delivered', 'cancelled'].contains(order['status'])) {
          history.add(order);
        } else {
          active.add(order);
        }
      }

      if (mounted) {
        setState(() {
          _activeOrders = active;
          _historyOrders = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }


  Widget _tabItem(String label, int index) {
    bool isSel = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: isSel ? Colors.black87 : Colors.black45,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'Mis Pedidos',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFFFA7516)),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    _tabItem('Activos', 0),
                    _tabItem('Historial', 1),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFA7516)),
                    )
                  : _selectedTab == 0
                      ? _buildActiveOrders()
                      : _buildHistoryOrders(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrders() {
    if (_activeOrders.isEmpty) {
      return Center(
        child: Text(
          'No tienes pedidos activos',
          style: GoogleFonts.poppins(color: Colors.black45),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _activeOrders.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedidos Activos',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA7516).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_activeOrders.length} en curso',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFFA7516),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final order = _activeOrders[index - 1];
        return _buildOrderCardObj(order);
      },
    );
  }

  Widget _buildHistoryOrders() {
    if (_historyOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.black12),
            const SizedBox(height: 16),
            Text(
              'No tienes pedidos pasados',
              style: GoogleFonts.poppins(color: Colors.black45),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _historyOrders.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 10),
            child: Text(
              'Historial de Pedidos',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          );
        }
        final order = _historyOrders[index - 1];
        return _buildOrderCardObj(order);
      },
    );
  }

  Widget _buildOrderCardObj(dynamic order) {
    int currentStep = 1;
    String statusStr = 'Recibido';
    switch (order['status']) {
      case 'pending': currentStep = 1; statusStr = 'Pendiente'; break;
      case 'accepted':
      case 'preparing': currentStep = 2; statusStr = 'Preparando'; break;
      case 'ready': currentStep = 2; statusStr = 'Preparado'; break;
      case 'in_delivery': currentStep = 3; statusStr = 'En Camino'; break;
      case 'delivered': currentStep = 4; statusStr = 'Entregado'; break;
      case 'cancelled': currentStep = 0; statusStr = 'Cancelado'; break;
    }

    final createdAtStr = order['created_at'];
    DateTime createdAt = DateTime.now();
    if (createdAtStr != null) {
      try { createdAt = DateTime.parse(createdAtStr).toLocal(); } catch (e) {}
    }
    final formattedDate = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    final totalParsed = double.tryParse(order['total']?.toString() ?? '0') ?? 0;
    final bool isFavor = order['restaurant_id'] == 0 || order['restaurant_name'] == 'Mi ubicación';
    final String displayName = isFavor ? 'Pakiip Favor 🚀' : (order['restaurant_name'] ?? 'Restaurante');
    final rawImage = order['restaurant_logo']?.toString() ?? '';
    final imageUrl = rawImage.isEmpty ? '' : (rawImage.startsWith('http') ? rawImage : '${ApiService.baseUrl}$rawImage');
    final String displayImage = isFavor ? '' : imageUrl;

    return _buildOrderCard(
      restaurantName: displayName,
      image: displayImage,
      isFavor: isFavor,
      orderId: order['order_code'] != null ? '#${order['order_code']}' : '#PK-${order['id']}',
      date: formattedDate,
      price: 'S/. ${totalParsed.toStringAsFixed(2)}',
      status: statusStr,
      currentStep: currentStep,
      onDetails: () => _showOrderDetails(order),
    );
  }

  Widget _buildOrderCard({
    required String restaurantName,
    required String image,
    required String orderId,
    required String date,
    required String price,
    required String status,
    required int currentStep,
    required VoidCallback onDetails,
    bool isFavor = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          // Efecto 3D
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
          // Sombra suave ambiental
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: isFavor ? const Color(0xFFFA7516).withValues(alpha: 0.1) : const Color(0xFFF5F5F5),
                  image: image.isNotEmpty ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover) : null,
                ),
                child: image.isEmpty 
                  ? Icon(isFavor ? Icons.delivery_dining_rounded : Icons.restaurant, color: const Color(0xFFFA7516), size: 30) 
                  : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurantName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text('Pedido $orderId • $date', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45)),
                    const SizedBox(height: 4),
                    Text(price, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFFA7516))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFE55409)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTimelineStep('Recibido', 1, currentStep),
              _buildTimelineLine(1, currentStep),
              _buildTimelineStep('Preparando', 2, currentStep),
              _buildTimelineLine(2, currentStep),
              _buildTimelineStep('En Camino', 3, currentStep),
              _buildTimelineLine(3, currentStep),
              _buildTimelineStep('Entregado', 4, currentStep),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.black12),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onDetails,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Ver detalles del pedido', style: GoogleFonts.poppins(color: const Color(0xFFFA7516), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFFFA7516)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, int stepIndex, int currentStep) {
    bool isActive = stepIndex <= currentStep;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFFA7516) : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFFFA7516) : Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildTimelineLine(int stepIndex, int currentStep) {
    bool isActive = stepIndex < currentStep;
    return Container(
      width: 20, height: 2,
      color: isActive ? const Color(0xFFFA7516) : const Color(0xFFF5F5F5),
      margin: const EdgeInsets.only(bottom: 20),
    );
  }

  void _showOrderDetails(dynamic order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Resumen del Pedido', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            if (order['order_code'] != null) Text('Código: ${order['order_code']}', style: GoogleFonts.poppins(color: const Color(0xFFFA7516), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 24),
            Expanded(
              child: ShortDetails(order: order, serviceFee: _serviceFee),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

class ShortDetails extends StatelessWidget {
  final dynamic order;
  final double serviceFee;
  const ShortDetails({super.key, required this.order, required this.serviceFee});

  @override
  Widget build(BuildContext context) {
    final bool isFavor = order['restaurant_id'] == 0 || order['restaurant_name'] == 'Mi ubicación';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isFavor ? Icons.delivery_dining_rounded : Icons.restaurant, color: const Color(0xFFFA7516), size: 20),
              const SizedBox(width: 8),
              Text(isFavor ? 'Pakiip Favor' : (order['restaurant_name'] ?? 'Restaurante'), style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.black12),
          const SizedBox(height: 16),
          Text(isFavor ? 'DETALLES DEL FAVOR' : 'PRODUCTOS', style: GoogleFonts.poppins(color: Colors.black45, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (isFavor)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFA7516).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFA7516).withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFFA7516), size: 18),
                      const SizedBox(width: 8),
                      Text('Indicaciones:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFFA7516))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(order['notes']?.toString() ?? 'Sin descripción', style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, height: 1.4)),
                ],
              ),
            )
          else
            ...(order['items'] as List<dynamic>? ?? []).map((item) {
              final qty = item['quantity'] ?? 1;
              final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(6)), child: Text('${qty}x', style: GoogleFonts.poppins(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item['name'] ?? 'Producto', style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14))),
                    Text('S/. ${(price * qty).toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
          const Divider(color: Colors.black12),
          const SizedBox(height: 24),
          _row(Icons.location_on_outlined, 'Dirección', order['client_address'] ?? 'No especificada'),
          const SizedBox(height: 16),
          _row(Icons.payment, 'Método de pago', (() {
            final pm = (order['payment_method'] ?? 'cash').toString().toLowerCase();
            if (pm == 'yape') return 'Pago con Yape';
            return 'Pago en Efectivo';
          })()),
          const SizedBox(height: 24),
          const Divider(color: Colors.black12),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;
              final delivery = double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0;
              final tip = double.tryParse(order['tip']?.toString() ?? '0') ?? 0;
              // Leer service_fee directamente del backend
              final service = double.tryParse(order['service_fee']?.toString() ?? '0') ?? serviceFee;

              // Calcular subtotal sumando precio base + opciones de cada item
              double subtotal = 0;
              if (order['items'] != null) {
                try {
                  final items = order['items'] is String ? jsonDecode(order['items']) : order['items'];
                  for (var item in items) {
                    double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                    int qty = int.tryParse(
                      (item['quantity'] ?? item['qty'])?.toString() ?? '1'
                    ) ?? 1;
                    // Sumar opciones
                    double optionsTotal = 0;
                    final opts = item['options'];
                    if (opts is List) {
                      for (var opt in opts) {
                        optionsTotal += double.tryParse(opt['price']?.toString() ?? '0') ?? 0;
                      }
                    }
                    subtotal += (price + optionsTotal) * qty;
                  }
                } catch (e) {
                  // Fallback: restar del total
                  subtotal = total - delivery - service - tip;
                }
              }

              return Column(
                children: [
                  _price('Subtotal', subtotal),
                  _price('Costo de envío', delivery),
                  _price('Tarifa de servicio', service),
                  if (tip > 0) _price('Propina (Motorizado)', tip),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('S/. ${total.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: const Color(0xFFFA7516), fontWeight: FontWeight.bold, fontSize: 22)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String t, String v) => Row(children: [Icon(icon, color: Colors.black45, size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: GoogleFonts.poppins(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)), Text(v, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14))]))]);
  Widget _price(String l, double a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14)), Text('S/. ${a.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500))]));
}







