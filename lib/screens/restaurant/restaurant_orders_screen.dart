import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum _OrderStatus {
  nuevo,
  enPreparacion,
  motorizadoAsignado,
  listoEntrega,
  enCamino,
  entregado,
  cancelado,
}

class _OrderItem {
  final String name;
  final int qty;
  final double price;
  final List<dynamic> options;

  _OrderItem({
    required this.name,
    required this.qty,
    required this.price,
    this.options = const [],
  });

  double get totalWithOptions {
    double optSum = 0;
    for (var opt in options) {
      optSum += double.tryParse(opt['price']?.toString() ?? '0') ?? 0;
    }
    return (price + optSum) * qty;
  }
}

class _Order {
  final String id;
  final String client;
  final String address;
  final String phone;
  final String paymentMethod;
  final String notes;
  final double total;
  final double deliveryFee;
  final int minutesAgo;
  final List<_OrderItem> items;
  final String orderCode;
  final DateTime? createdAt;
  final double serviceFee;
  final double tip;
  final String? paymentProofUrl;
  final double restaurantCommission;
  final double restaurantPayout;
  final bool isManual;
  final double discount;
  _OrderStatus status;

  _Order({
    required this.id,
    required this.orderCode,
    required this.client,
    this.address = '',
    this.phone = '',
    this.paymentMethod = '',
    this.notes = '',
    required this.total,
    this.deliveryFee = 0.0,
    this.serviceFee = 2.0, // Default fallback
    required this.minutesAgo,
    this.createdAt,
    required this.items,
    required this.status,
    this.paymentProofUrl,
    this.tip = 0.0,
    this.restaurantCommission = 0.0,
    this.restaurantPayout = 0.0,
    this.isManual = false,
    this.discount = 0.0,
  });

  int get productCount => items.fold(0, (s, i) => s + i.qty);
  double get itemsTotal => items.fold(0.0, (s, i) => s + i.totalWithOptions);

  /// El subtotal es el valor que realmente va para el restaurante
  /// (Solo el valor de los productos + sus opciones)
  double get subtotal => itemsTotal;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class RestaurantOrdersScreen extends StatefulWidget {
  const RestaurantOrdersScreen({super.key});

  @override
  State<RestaurantOrdersScreen> createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends State<RestaurantOrdersScreen> {
  Timer? _timer;
  Timer? _refreshTimer;
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _green = Color(0xFF2ECC71);
  static const Color _teal = Color(0xFF00BFA5);

  int _filterIdx = 0;
  final List<String> _filters = [
    'Todos',
    'Pendientes',
    'En Cocina',
    'Listos',
    'En Camino',
    'Entregados',
    'Cancelados',
  ];

  final List<_Order> _orders = [];
  bool _isLoading = true;
  double _ventasHoyVal = 0.0;
  double _serviceFee = 1.0; // Valor por defecto actualizado a 1.0

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() {});
    });
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (t) {
      if (mounted) {
        _loadOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      // Intentar obtener la configuración para el service_fee
      try {
        final config = await ApiService.get('/config/public');
        if (config['service_fee'] != null) {
          _serviceFee =
              double.tryParse(config['service_fee'].toString()) ?? 1.0;
        }
      } catch (e) {
        debugPrint('Error cargando config: $e');
      }

      final data = await ApiService.getList('/orders/restaurant/all');
      final orders = <_Order>[];
      double ventas = 0;

      for (var json in data) {
        _OrderStatus status;
        switch (json['status']) {
          case 'pending':
            status = _OrderStatus.nuevo;
            break;
          case 'accepted':
          case 'preparing':
            status = _OrderStatus.enPreparacion;
            break;
          case 'rider_assigned':
            status = _OrderStatus.motorizadoAsignado;
            break;
          case 'ready':
            status = _OrderStatus.listoEntrega;
            break;
          case 'in_delivery':
            status = _OrderStatus.enCamino;
            break;
          case 'delivered':
            status = _OrderStatus.entregado;
            break;
          case 'cancelled':
            status = _OrderStatus.cancelado;
            break;
          default:
            continue;
        }

        final itemsList = (json['items'] as List<dynamic>?) ?? [];
        final items = itemsList
            .map(
              (i) => _OrderItem(
                name: i['name'].toString(),
                qty: i['quantity'] as int? ?? 1,
                price: double.tryParse(i['price'].toString()) ?? 0,
                options: (i['options'] as List<dynamic>?) ?? [],
              ),
            )
            .toList();

        final createdStr = json['created_at'];
        DateTime? createdAt;
        int minutesAgo = 0;
        if (createdStr != null) {
          try {
            createdAt = DateTime.parse(createdStr).toLocal();
            minutesAgo = DateTime.now().difference(createdAt).inMinutes;
          } catch (_) {}
        }

        final totalParsed = double.tryParse(json['total']?.toString() ?? '0') ?? 0;
        final deliveryFee = double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0;
        final tip = double.tryParse(json['tip']?.toString() ?? '0') ?? 0;

        // Calcular subtotal real de los productos (sumando items ya procesados arriba)
        double itemsTotalSum = items.fold(0.0, (s, i) => s + i.totalWithOptions);

        // Derivar service fee si viene en 0 pero el total no cuadra
        double serviceFeeVal = double.tryParse(json['service_fee']?.toString() ?? '0') ?? 0;
        if (serviceFeeVal == 0 && totalParsed > (itemsTotalSum + deliveryFee + tip)) {
           serviceFeeVal = totalParsed - itemsTotalSum - deliveryFee - tip;
        } else if (serviceFeeVal == 0) {
           serviceFeeVal = _serviceFee; // Fallback al global si sigue siendo 0
        }

        final bool isManual = itemsList.isNotEmpty && (itemsList[0]['name'] == 'Pedido Manual' || itemsList[0]['name'] == 'Favor');
        final discountVal = double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0;

        final currentOrder = _Order(
          id: json['id'].toString(),
          orderCode: json['order_code']?.toString() ?? json['id'].toString(),
          client: json['client_name'] ?? 'Cliente',
          address: json['client_address'] ?? 'No especificada',
          phone: json['client_phone'] ?? '',
          paymentMethod: json['payment_method'] ?? 'cash',
          notes: json['notes'] ?? '',
          total: totalParsed,
          deliveryFee: deliveryFee,
          serviceFee: serviceFeeVal,
          minutesAgo: minutesAgo,
          createdAt: createdAt,
          items: items,
          status: status,
          paymentProofUrl: json['payment_proof_url'],
          tip: tip,
          restaurantCommission: double.tryParse(json['restaurant_commission']?.toString() ?? '0') ?? 0.0,
          restaurantPayout: double.tryParse(json['restaurant_payout']?.toString() ?? '0') ?? 0.0,
          isManual: isManual,
          discount: discountVal,
        );

        if (status == _OrderStatus.entregado) {
          ventas += currentOrder.subtotal;
        }

        orders.add(currentOrder);
      }

      if (mounted) {
        setState(() {
          _orders.clear();
          _orders.addAll(orders);
          _ventasHoyVal = ventas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<_Order> get _filtered {
    if (_orders.isEmpty) return [];
    switch (_filterIdx) {
      case 1:
        return _orders.where((o) => o.status == _OrderStatus.nuevo).toList();
      case 2:
        return _orders
            .where((o) => o.status == _OrderStatus.enPreparacion)
            .toList();
      case 3:
        return _orders
            .where((o) => o.status == _OrderStatus.listoEntrega)
            .toList();
      case 4:
        return _orders.where((o) => o.status == _OrderStatus.enCamino).toList();
      case 5:
        return _orders
            .where((o) => o.status == _OrderStatus.entregado)
            .toList();
      case 6:
        return _orders
            .where((o) => o.status == _OrderStatus.cancelado)
            .toList();
      default:
        // Todos los activos (no entregados ni cancelados)
        return _orders
            .where(
              (o) =>
                  o.status != _OrderStatus.entregado &&
                  o.status != _OrderStatus.cancelado,
            )
            .toList();
    }
  }

  int _countByStatus(_OrderStatus s) =>
      _orders.where((o) => o.status == s).length;
  int get _activeCount => _orders
      .where(
        (o) =>
            o.status != _OrderStatus.entregado &&
            o.status != _OrderStatus.cancelado,
      )
      .length;
  int get _completedToday =>
      _orders.where((o) => o.status == _OrderStatus.entregado).length;

  double get _ventasHoy => _ventasHoyVal;

  Future<void> _advance(_Order o) async {
    String nextStatusStr;
    _OrderStatus nextStatus;

    if (o.status == _OrderStatus.nuevo) {
      nextStatusStr = 'preparing';
      nextStatus = _OrderStatus.enPreparacion;
    } else if (o.status == _OrderStatus.enPreparacion || o.status == _OrderStatus.motorizadoAsignado) {
      nextStatusStr = 'ready';
      nextStatus = _OrderStatus.listoEntrega;
    } else {
      // El restaurante ya no puede avanzar a 'in_delivery'. 
      // Eso lo hace el motorizado al recoger el pedido.
      return;
    }

    try {
      await ApiService.patch('/orders/${o.id}/status', {
        'status': nextStatusStr,
      });
      if (mounted) {
        setState(() {
          o.status = nextStatus;
          if (nextStatus == _OrderStatus.entregado) {
            _ventasHoyVal += o.total;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error actualizando pedido: $e')),
        );
      }
    }
  }

  Future<void> _cancelOrder(_Order o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Cancelar Pedido?',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'El pedido #${o.orderCode} será cancelado. ¿Confirmar?',
          style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cerrar',
              style: GoogleFonts.poppins(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Confirmar',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.patch('/orders/${o.id}/status', {'status': 'cancelled'});
      if (mounted) {
        setState(() {
          o.status = _OrderStatus.cancelado;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pedido cancelado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showOrderDetails(_Order o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Detalles del Pedido #${o.orderCode}',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cliente
                    _detailInfo('Cliente', o.client, Icons.person_outline),
                    _detailInfo(
                      'Pago',
                      o.paymentMethod.toLowerCase() == 'yape' 
                        ? (o.paymentProofUrl != null ? 'Pago con Yape (Ya pagado)' : 'Pago con Yape al entregar') 
                        : 'Pago en Efectivo',
                      Icons.payment,
                    ),
                    if (o.paymentProofUrl != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'COMPROBANTE YAPE',
                        style: GoogleFonts.poppins(
                          color: _red,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      child: Image.network(
                                        '${ApiService.baseUrl}${o.paymentProofUrl}',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.black87,
                                        ),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Image.network(
                              '${ApiService.baseUrl}${o.paymentProofUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.black26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),

                    Text(
                      o.isManual ? 'INDICACIONES DEL ENVÍO' : 'PRODUCTOS',
                      style: GoogleFonts.poppins(
                        color: _red,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (o.isManual)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _red.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          o.notes.isEmpty ? 'Sin descripción' : o.notes,
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      )
                    else
                      ...o.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${item.qty}x',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  'S/. ${(item.price * item.qty).toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (item.options.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 32,
                                  top: 4,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: item.options.map<Widget>((opt) {
                                    final optName = opt['name'] ?? 'Opción';
                                    final optPrice =
                                        double.tryParse(
                                          opt['price']?.toString() ?? '0',
                                        ) ??
                                        0;
                                    return Text(
                                      '• $optName ${optPrice > 0 ? '(+S/. ${optPrice.toStringAsFixed(2)})' : ''}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black38,
                                        fontSize: 12,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    if (o.notes.isNotEmpty) ...[
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),
                      Text(
                        'NOTAS / INSTRUCCIONES',
                        style: GoogleFonts.poppins(
                          color: _red,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          o.notes,
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    _priceRow('Venta Productos', o.subtotal),
                    _priceRow('Envío (Pakiip)', o.deliveryFee),
                    _priceRow('Servicio (Pakiip)', o.serviceFee),
                    if (o.tip > 0) _priceRow('Propina (Motorizado)', o.tip),
                    if (o.discount > 0) _priceRow('Descuento Especial', -o.discount, color: Colors.green),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL A PAGAR POR CLIENTE',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'S/. ${o.total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: _green,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comisión Pakiip por Venta',
                          style: GoogleFonts.poppins(
                            color: Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '-S/. ${o.restaurantCommission.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL NETO PARA RESTAURANTE',
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'S/. ${(o.subtotal - o.restaurantCommission).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailInfo(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: _red, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.black38, fontSize: 10),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _priceRow(String label, double val, {Color? color}) {
    final formattedVal = val < 0 
        ? '- S/. ${val.abs().toStringAsFixed(2)}' 
        : 'S/. ${val.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.black45, fontSize: 13),
          ),
          Text(
            formattedVal,
            style: GoogleFonts.poppins(color: color ?? Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  String _filterLabel(int i) {
    switch (i) {
      case 0:
        return 'Todos ($_activeCount)';
      case 1:
        return 'Pendientes (${_countByStatus(_OrderStatus.nuevo)})';
      case 2:
        return 'En Cocina (${_countByStatus(_OrderStatus.enPreparacion)})';
      case 3:
        return 'Listos (${_countByStatus(_OrderStatus.listoEntrega)})';
      case 4:
        return 'En Camino (${_countByStatus(_OrderStatus.enCamino)})';
      case 5:
        return 'Entregados (${_countByStatus(_OrderStatus.entregado)})';
      case 6:
        return 'Cancelados (${_countByStatus(_OrderStatus.cancelado)})';
      default:
        return _filters[i];
    }
  }

  Widget _buildCountdown(_Order o) {
    if (o.createdAt == null) return const SizedBox.shrink();
    final limit = o.createdAt!.add(const Duration(minutes: 49));
    final diff = limit.difference(DateTime.now());

    if (diff.isNegative) {
      return Text(
        'EXPIRADO',
        style: GoogleFonts.poppins(
          color: _red,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }

    final mins = diff.inMinutes;
    final secs = diff.inSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: mins < 5
            ? _red.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        timeStr,
        style: GoogleFonts.poppins(
          color: mins < 5 ? _red : Colors.black45,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ── order card ────────────────────────────────────────────────────────────
  Widget _buildOrderCard(_Order order) {
    switch (order.status) {
      case _OrderStatus.nuevo:
        return _newOrderCard(order);
      case _OrderStatus.enPreparacion:
        return _preparingCard(order);
      case _OrderStatus.motorizadoAsignado:
        return _motorizadoAsignadoCard(order);
      case _OrderStatus.listoEntrega:
        return _readyCard(order);
      case _OrderStatus.enCamino:
        return _onTheWayCard(order);
      case _OrderStatus.entregado:
        return _deliveredCard(order);
      case _OrderStatus.cancelado:
        return _cancelledCard(order);
    }
  }

  // ● NUEVO PEDIDO ────────────────────────────────────────────────────────────
  Widget _newOrderCard(_Order o) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _red.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge(
                        'NUEVO PEDIDO',
                        _red.withValues(alpha: 0.1),
                        const Color(0xFF9E4600), // Darker orange for better contrast
                        isManual: o.isManual,
                      ),
                      const SizedBox(width: 8),
                      _buildCountdown(o),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${o.orderCode} – ${o.client}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Colors.black38,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'hace ${o.minutesAgo} min',
                        style: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/. ${o.subtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: _red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${o.productCount} productos',
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Items list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: o.items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Text(
                          '${item.qty}x ${item.name}',
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'S/. ${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.black45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        const SizedBox(height: 14),
        const Divider(color: Color(0xFFE8E8E8), height: 1),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => _showOrderDetails(o),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver detalles del pedido',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16, color: Colors.black54),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _actionBtn(
                  label: 'Aceptar',
                  icon: Icons.check_circle_outline,
                  color: _red,
                  textColor: Colors.black87,
                  onTap: () => _advance(o),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  label: 'Cancelar',
                  icon: Icons.close,
                  color: const Color(0xFF3D0808),
                  textColor: Colors.white, // Improved contrast
                  onTap: () => _cancelOrder(o),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ● EN PREPARACIÓN ──────────────────────────────────────────────────────────
  Widget _preparingCard(_Order o) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _teal.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge(
                    'EN PREPARACIÓN',
                    _teal.withValues(alpha: 0.12),
                    const Color(0xFF00695C), // Dark Teal
                    isManual: o.isManual,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${o.orderCode} – ${o.client}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Colors.black38,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'hace ${o.minutesAgo} min',
                        style: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/. ${o.subtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${o.productCount} productos',
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(color: Color(0xFFE8E8E8), height: 1),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => _showOrderDetails(o),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver detalles del pedido',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16, color: Colors.black54),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Cancelar',
                  icon: Icons.close,
                  color: const Color(0xFF3D0808),
                  textColor: Colors.white, // Improved contrast
                  onTap: () => _cancelOrder(o),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  label: 'Listo',
                  icon: Icons.done_all,
                  color: _red,
                  textColor: Colors.black87,
                  onTap: () => _advance(o),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  // ● MOTORIZADO ASIGNADO ──────────────────────────────────────────────────────────
  Widget _motorizadoAsignadoCard(_Order o) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _blue.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge(
                    'MOTORIZADO ASIGNADO',
                    _blue.withValues(alpha: 0.12),
                    const Color(0xFF0D47A1), // Dark Blue
                    isManual: o.isManual,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${o.orderCode} – ${o.client}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.delivery_dining, color: _blue, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Un motorizado ha tomado el pedido',
                        style: GoogleFonts.poppins(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/. ${o.subtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFFE8E8E8), height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: () => _showOrderDetails(o),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver detalles',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Icon(Icons.expand_more, size: 16, color: Colors.black54),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _advance(o),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.restaurant, color: Colors.black87, size: 20),
              label: Text(
                'MARCAR COMO LISTO',
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

  // ● LISTO PARA ENTREGA ──────────────────────────────────────────────────────
  Widget _readyCard(_Order o) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _green.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge(
                    'LISTO PARA ENTREGA',
                    _green.withValues(alpha: 0.12),
                    const Color(0xFF1B5E20),
                    isManual: o.isManual,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${o.orderCode} – ${o.client}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: _green, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Terminado hace ${o.minutesAgo} min',
                        style: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/. ${o.subtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${o.productCount} productos',
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(color: Color(0xFFE8E8E8), height: 1),

        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GestureDetector(
            onTap: () => _showOrderDetails(o),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver detalles del pedido',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16, color: Colors.black54),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, color: _green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ESPERANDO RECOJO DEL MOTORIZADO',
                  style: GoogleFonts.poppins(
                    color: _green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ● EN CAMINO ──────────────────────────────────────────────────────────────
  Widget _onTheWayCard(_Order o) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _blue.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge('EN CAMINO', _blue.withValues(alpha: 0.12), const Color(0xFF0D47A1)),
                  const SizedBox(height: 6),
                  Text(
                    '#${o.orderCode} – ${o.client}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'S/. ${o.subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFFE8E8E8), height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: GestureDetector(
            onTap: () => _showOrderDetails(o),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver detalles (En tránsito)',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16, color: Colors.black54),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static const Color _blue = Color(0xFF2196F3);

  // ● PEDIDO CANCELADO ────────────────────────────────────────────────────────
  Widget _cancelledCard(_Order o) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: Opacity(
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badge(
                      'CANCELADO',
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black45,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '#${o.orderCode} – ${o.client}',
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'S/. ${o.subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE8E8E8), height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () => _showOrderDetails(o),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ver detalles del pedido',
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more,
                    size: 16,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ● PEDIDO ENTREGADO ────────────────────────────────────────────────────────
  Widget _deliveredCard(_Order o) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge('ENTREGADO', _green.withValues(alpha: 0.1), const Color(0xFF1B5E20), isManual: o.isManual),
                  const SizedBox(height: 6),
                  Text(
                    '#${o.orderCode} – ${o.client}',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'S/. ${o.subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFFE8E8E8), height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: GestureDetector(
            onTap: () => _showOrderDetails(o),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver detalles del pedido',
                  style: GoogleFonts.poppins(
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16, color: Colors.black38),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ── helpers ───────────────────────────────────────────────────────────────
  Widget _badge(String label, Color bg, Color fg, {bool isManual = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: isManual ? const Color(0xFFFA7516) : bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isManual ? 'SOLICITUD MOTORIZADO' : label,
      style: GoogleFonts.poppins(
        color: isManual ? Colors.white : fg,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final ventas = _ventasHoy.toDouble();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _red),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Pedidos',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'PANEL DE ADMINISTRADOR',
              style: GoogleFonts.poppins(
                color: _red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ventas ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ventas (S/.)',
                  style: GoogleFonts.poppins(
                    color: Colors.black45,
                    fontSize: 12,
                  ),
                ),
                Text(
                  ventas
                      .toStringAsFixed(2)
                      .replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (m) => '${m[1]},',
                      ),
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Filters ───────────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final active = _filterIdx == i;
                return GestureDetector(
                  onTap: () => setState(() => _filterIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active ? _red : _card,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: active ? _red : _border),
                    ),
                    child: Text(
                      _filterLabel(i),
                      style: GoogleFonts.poppins(
                        color: active ? Colors.white : Colors.black54,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // ── Section label ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _filterIdx == 0
                      ? 'Pedidos Entrantes'
                      : _filterLabel(_filterIdx),
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Orders list ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _red))
                : filtered.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildOrderCard(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.no_meals, color: _red, size: 48),
        const SizedBox(height: 16),
        Text(
          'Has gestionado todos los pedidos críticos.',
          style: GoogleFonts.poppins(
            color: Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Total de hoy: $_completedToday pedidos completados',
          style: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
        ),
      ],
    ),
  );
}
