import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'dart:async';

class RiderOrdersScreen extends StatefulWidget {
  final String riderName;
  const RiderOrdersScreen({super.key, required this.riderName});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _availableOrders = [];
  List<dynamic> _activeOrders = [];
  int _selectedActiveIdx = 0;
  bool _isLoading = true;
  bool _isTaking = false;
  Timer? _refreshTimer;

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _blue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _startTimer();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadData(silent: true);
      }
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final available = await ApiService.getList('/riders/orders/available');
      final active = await ApiService.getList('/riders/orders/active');

      if (mounted) {
        setState(() {
          _availableOrders = available;
          _activeOrders = active;
          if (_selectedActiveIdx >= _activeOrders.length) {
            _selectedActiveIdx = 0;
          }
          _isLoading = false;
        });

        // Solo saltar al tab de activo en la carga inicial si no estábamos ahí
        if (!silent && _activeOrders.isNotEmpty && _tabController.index == 0) {
          _tabController.animateTo(1);
        }
      }
    } catch (e) {
      if (mounted) {
        if (!silent) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar datos: $e'),
              backgroundColor: _red,
            ),
          );
        }
      }
    }
  }

  Future<void> _takeOrder(int id) async {
    setState(() => _isTaking = true);
    try {
      await ApiService.patch('/riders/orders/$id/take', {});
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido tomado! Vamos a la ruta.'),
            backgroundColor: _green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al tomar pedido: $e'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  Future<void> _deliverOrder(int id) async {
    setState(() => _isTaking = true);
    try {
      await ApiService.patch('/riders/orders/$id/deliver', {});
      await _loadData();
      if (mounted) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido entregado! Buen trabajo.'),
            backgroundColor: _green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  Future<void> _pickupOrder(int id) async {
    setState(() => _isTaking = true);
    try {
      await ApiService.patch('/riders/orders/$id/pickup', {});
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido recogido! En camino al cliente.'),
            backgroundColor: _green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recoger: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir: $url'),
            backgroundColor: _red,
          ),
        );
      }
    }
  }

  void _makeCall(String? phone) {
    if (phone == null || phone.isEmpty) return;
    _launchUrl('tel:$phone');
  }

  void _openMaps(String? address) {
    if (address == null || address.isEmpty) return;
    final query = Uri.encodeComponent(address);
    _launchUrl('https://www.google.com/maps/search/?api=1&query=$query');
  }

  void _openMapsCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return;
    _launchUrl('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Gestionar Pedidos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _red,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'DISPONIBLES'),
            Tab(text: 'EN CURSO'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _red,
              child: TabBarView(
                controller: _tabController,
                children: [_buildAvailableTab(), _buildActiveTab()],
              ),
            ),
    );
  }

  Widget _buildAvailableTab() {
    if (_availableOrders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.delivery_dining_outlined,
                    size: 64,
                    color: Colors.white10,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay pedidos disponibles\nen este momento.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.black26,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Asegúrate de estar "En Línea" en tu panel para recibir nuevas solicitudes.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _red.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availableOrders.length,
        itemBuilder: (ctx, i) =>
            _orderCard(_availableOrders[i], isAvailable: true),
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.route_outlined, size: 64, color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              'No tienes pedidos activos.\n¡Toma uno de la lista!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black26),
            ),
          ],
        ),
      );
    }

    if (_selectedActiveIdx >= _activeOrders.length) {
      _selectedActiveIdx = 0;
    }
    final currentOrder = _activeOrders[_selectedActiveIdx] as Map<String, dynamic>;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeOrders.length > 1) ...[
            Text(
              'TUS PEDIDOS EN CURSO (${_activeOrders.length})',
              style: GoogleFonts.poppins(
                color: Colors.black38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _activeOrders.length,
                itemBuilder: (ctx, idx) {
                  final o = _activeOrders[idx];
                  final isSelected = idx == _selectedActiveIdx;
                  final code = o['order_code'] ?? o['id'] ?? '';
                  final isReady = o['status'] == 'ready';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        '#$code${isReady ? ' (¡Listo!)' : ''}',
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: _red,
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (_) => setState(() => _selectedActiveIdx = idx),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          _orderCard(currentOrder, isAvailable: false),
          const SizedBox(height: 24),
          _buildDeliverySteps(currentOrder),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o, {required bool isAvailable}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? _blue.withValues(alpha: 0.1)
                      : _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${o['order_code'] ?? o['id']}',
                  style: GoogleFonts.poppins(
                    color: isAvailable ? _blue : _green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (o['created_at'] != null)
                Text(
                  _formatTimeOnly(o['created_at']),
                  style: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 11,
                  ),
                ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isAvailable)
                    ...([
                    (() {
                      final fee = double.tryParse(o['delivery_fee']?.toString() ?? '0') ?? 0;
                      final commPct = o['rider_commission_pct'] ?? o['commission_applied'] ?? 80;
                      final tip = double.tryParse(o['tip']?.toString() ?? '0') ?? 0;
                      final earning = o['rider_earning'] != null 
                          ? (double.tryParse(o['rider_earning'].toString()) ?? 0) 
                          : (fee * commPct / 100);
                      final total = earning + tip;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'TU GANANCIA',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'S/. ${total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              color: _green,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              height: 1.1,
                            ),
                          ),
                          if (tip > 0)
                            Text(
                              'Envío: S/. ${earning.toStringAsFixed(1)} + Propina: S/. ${tip.toStringAsFixed(1)}',
                              style: GoogleFonts.poppins(
                                color: Colors.black45,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      );
                    })()
                  ])
                  else
                    (() {
                      final fee = double.tryParse(o['delivery_fee']?.toString() ?? '0') ?? 0;
                      final commPct = o['rider_commission_pct'] ?? o['commission_applied'] ?? 80;
                      final tip = double.tryParse(o['tip']?.toString() ?? '0') ?? 0;
                      final earning = o['rider_earning'] != null 
                          ? (double.tryParse(o['rider_earning'].toString()) ?? 0) 
                          : (fee * commPct / 100);
                      final total = earning + tip;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'TU GANANCIA',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'S/. ${total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              color: _green,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              height: 1.1,
                            ),
                          ),
                          if (tip > 0)
                            Text(
                              'Envío: S/. ${earning.toStringAsFixed(1)} + Propina: S/. ${tip.toStringAsFixed(1)}',
                              style: GoogleFonts.poppins(
                                color: Colors.black45,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      );
                    })(),
                  if (o['distance_m'] != null)
                    Text(
                      _formatDistance(o['distance_m']),
                      style: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _locationLine(
            icon: Icons.store_rounded,
            color: _red,
            title: 'Recoger en ${o['restaurant_name'] ?? 'Restaurante'}',
            subtitle: o['restaurant_address'] ?? 'Dirección del restaurante',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
            child: Container(width: 1, height: 20, color: Colors.white10),
          ),
          _locationLine(
            icon: Icons.location_on_rounded,
            color: _green,
            title: 'Entregar a ${o['client_name'] ?? 'Cliente'}',
            subtitle: o['client_address'] ?? 'Dirección de entrega',
          ),

          // ── Notas/Descripción (Visible para todos) ──────────
          if (o['notes'] != null && o['notes'].toString().isNotEmpty && o['notes'].toString() != 'Pedido desde panel (Rider)') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blueGrey, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INDICACIONES:',
                          style: GoogleFonts.poppins(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          o['notes'].toString(),
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Detalles del Pedido (Solo para pedidos aceptados) ──────────
          if (!isAvailable) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              'DETALLES DEL PEDIDO',
              style: GoogleFonts.poppins(
                color: Colors.black38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildItemsList(o['items']),
            const SizedBox(height: 16),
            _buildOrderInfoRow(
              Icons.access_time_rounded,
              'Fecha y Hora:',
              _formatDate(o['created_at']),
            ),
            const SizedBox(height: 8),
            _buildOrderInfoRow(
              Icons.payments_outlined,
              'Método de Pago:',
              (() {
                final pm = (o['payment_method'] ?? 'cash').toString().toLowerCase();
                if (pm == 'yape') {
                  return o['payment_proof_url'] != null ? 'Pago con Yape (Ya pagado)' : 'Pago con Yape al entregar';
                }
                return 'Pago en Efectivo';
              })(),
            ),
            if (o['notes'] != null && o['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildOrderInfoRow(
                Icons.info_outline,
                'Notas / Instrucciones:',
                o['notes'].toString(),
              ),
            ],
            const SizedBox(height: 20),
            // ── Resumen financiero del pedido activo ──────────────────
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESUMEN DEL PEDIDO',
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  (() {
                    // Calcular subtotal real sumando items (precio base + opciones) * cantidad
                    double productsSubtotal = 0;
                    if (o['items'] != null) {
                      try {
                        final items = o['items'] is String ? jsonDecode(o['items']) : o['items'];
                        for (var item in items) {
                          double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                          int qty = int.tryParse(
                            (item['quantity'] ?? item['qty'])?.toString() ?? '1'
                          ) ?? 1;
                          // Sumar opciones al precio base
                          double optionsTotal = 0;
                          final opts = item['options'];
                          if (opts is List) {
                            for (var opt in opts) {
                              optionsTotal += double.tryParse(opt['price']?.toString() ?? '0') ?? 0;
                            }
                          }
                          productsSubtotal += (price + optionsTotal) * qty;
                        }
                      } catch (e) {
                        // Fallback: restar del total si falla el parseo
                        productsSubtotal = (double.tryParse(o['total']?.toString() ?? '0') ?? 0) -
                                          (double.tryParse(o['delivery_fee']?.toString() ?? '0') ?? 0) -
                                          (double.tryParse(o['service_fee']?.toString() ?? '0') ?? 0) -
                                          (double.tryParse(o['tip']?.toString() ?? '0') ?? 0);
                      }
                    }

                    final fee = double.tryParse(o['delivery_fee']?.toString() ?? '0') ?? 0;
                    final commPct = o['rider_commission_pct'] ?? o['commission_applied'] ?? 80;
                    final tipValue = double.tryParse(o['tip']?.toString() ?? '0') ?? 0;
                    final discount = double.tryParse(o['discount']?.toString() ?? '0') ?? 0;
                    final service = double.tryParse(o['service_fee']?.toString() ?? '0') ?? 0;
                    final earning = o['rider_earning'] != null 
                        ? (double.tryParse(o['rider_earning'].toString()) ?? 0) 
                        : (fee * commPct / 100);
                    final totalGanancia = earning + tipValue;
                    final totalCliente = double.tryParse(o['total']?.toString() ?? '0') ?? 0;

                    return Column(
                      children: [
                        _summaryRow('Productos Subtotal', 'S/. ${productsSubtotal.toStringAsFixed(2)}'),
                        _summaryRow('Costo Delivery', 'S/. ${fee.toStringAsFixed(2)}'),
                        _summaryRow('Tarifa de Servicio', 'S/. ${service.toStringAsFixed(2)}'),
                        if (tipValue > 0) _summaryRow('Propina Recibida', 'S/. ${tipValue.toStringAsFixed(2)}'),
                        if (discount > 0) _summaryRow('Descuento Especial', '- S/. ${discount.toStringAsFixed(2)}', isGreen: true),
                        const Divider(color: Colors.black12, height: 16),
                        _summaryRow(
                          'MONTO A COBRAR AL CLIENTE',
                          'S/. ${totalCliente.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TU GANANCIA DELIVERY',
                                style: GoogleFonts.poppins(
                                  color: _green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'S/. ${totalGanancia.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: _green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  })(),
                ],
              ),
            ),
            if (o['payment_proof_url'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'COMPROBANTE YAPE',
                style: GoogleFonts.poppins(
                  color: _green,
                  fontSize: 10,
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
                                '${ApiService.baseUrl}${o['payment_proof_url']}',
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
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Image.network(
                      '${ApiService.baseUrl}${o['payment_proof_url']}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.black26),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 20),
          if (isAvailable)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isTaking ? null : () => _takeOrder(o['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isTaking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black87,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'ACEPTAR PEDIDO',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            )
          else
            _buildActionButtons(o),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isGreen = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: isGreen
                  ? _green
                  : (isBold ? Colors.black87 : Colors.black87),
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(dynamic itemsData) {
    if (itemsData == null) return const SizedBox();
    List<dynamic> items = [];
    if (itemsData is String) {
      try {
        // En caso que el backend lo mande como string JSON
        items = jsonDecode(itemsData.toString());
      } catch (_) {}
    } else if (itemsData is List) {
      items = itemsData;
    }

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${item['quantity'] ?? item['qty'] ?? 1}x',
                    style: GoogleFonts.poppins(
                      color: _red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${item['name']}',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: Colors.black26, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.black38, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '--:--';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');

      int hour = dt.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      return '$day/$month - $hourStr:$minute $ampm';
    } catch (_) {
      return dateStr.toString();
    }
  }

  String _formatDistance(dynamic m) {
    if (m == null) return '';
    final meters = double.tryParse(m.toString()) ?? 0.0;
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String _formatTimeOnly(dynamic dateStr) {
    if (dateStr == null) return '--:--';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      int hour = dt.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hourStr:$minute $ampm';
    } catch (_) {
      return '';
    }
  }

  Widget _locationLine({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> o) {
    final status = o['status'];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionBtn(
                icon: Icons.phone_rounded,
                label: 'Llamar',
                color: _blue,
                onTap: () => _makeCall(o['client_phone']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionBtn(
                icon: Icons.store_rounded,
                label: 'Ir al Local',
                color: _red,
                onTap: () {
                  final lat = double.tryParse(o['restaurant_lat']?.toString() ?? '');
                  final lng = double.tryParse(o['restaurant_lng']?.toString() ?? '');
                  if (lat != null && lng != null) {
                    _openMapsCoords(lat, lng);
                  } else {
                    _openMaps(o['restaurant_address']);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionBtn(
                icon: Icons.location_on_rounded,
                label: 'Ir al Cliente',
                color: _green,
                onTap: () {
                  final lat = double.tryParse(o['client_lat']?.toString() ?? '');
                  final lng = double.tryParse(o['client_lng']?.toString() ?? '');
                  if (lat != null && lng != null) {
                    _openMapsCoords(lat, lng);
                  } else {
                    _openMaps(o['client_address']);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (status == 'rider_assigned' || status == 'preparing' || status == 'ready')
          (() {
            final isFavor = o['restaurant_id'] == null;
            final isReady = status == 'ready' || isFavor;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isReady ? _green.withValues(alpha: 0.1) : _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isReady ? _green.withValues(alpha: 0.3) : _blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isReady) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
                    ),
                    const SizedBox(width: 12),
                  ] else
                    const Icon(Icons.check_circle_outline, color: _green, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    isReady
                        ? (isFavor ? '\u00a1PAKIIP FAVOR LISTO PARA RECOGER!' : '\u00a1EL PEDIDO YA EST\u00c1 LISTO!')
                        : 'ESPERANDO QUE EL LOCAL TERMINE...',
                    style: GoogleFonts.poppins(
                      color: isReady ? _green : _blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          })(),
        const SizedBox(height: 16),
        if (status == 'rider_assigned' || status == 'preparing' || status == 'ready') ...[
          const SizedBox(height: 16),
        ],
        if (status == 'rider_assigned' || status == 'preparing' || status == 'ready')
          (() {
            final isFavor = o['restaurant_id'] == null;
            final isReady = status == 'ready' || isFavor;
            return SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isTaking ? null : () => _pickupOrder(o['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReady ? _green : _red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                label: Text(
                  isReady ? 'RECOGER PEDIDO (\u00a1LISTO!)' : 'RECOGER PEDIDO',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          })()
        else if (status == 'in_delivery')
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isTaking ? null : () => _deliverOrder(o['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'MARCAR COMO ENTREGADO',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySteps(Map<String, dynamic> o) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pasos para completar',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _stepRow(1, 'Recoge el pedido en el restaurante', o['status'] == 'ready' || o['status'] == 'in_delivery' || o['status'] == 'delivered' || o['status'] == 'entregado'),
          _stepRow(2, 'Verifica los productos con el ticket', o['status'] == 'in_delivery' || o['status'] == 'entregado'),
          _stepRow(3, 'Dirígete a la ubicación del cliente', o['status'] == 'in_delivery'),
          _stepRow(4, 'Entrega y cobra el monto total', o['status'] == 'entregado'),
        ],
      ),
    );
  }

  Widget _stepRow(int num, String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone ? _green : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '$num',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: isDone ? Colors.black38 : Colors.black87,
                fontSize: 13,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}
