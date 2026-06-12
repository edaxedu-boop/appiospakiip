import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../services/api_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const Color _bg = Colors.white;
  static const Color _red = Color(0xFFFA7516);

  bool _loading = true;
  List<dynamic> _orders = [];
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(
        '/admin/orders?page=$_currentPage&limit=20',
      );
      if (mounted) {
        setState(() {
          _orders = res['orders'];
          _totalPages = res['pagination']['pages'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Error al cargar pedidos: $e', Colors.red);
      }
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Gestión de Pedidos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded, color: _red, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _red))
                : _orders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _orders.length,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemBuilder: (context, index) => _orderCard(_orders[index]),
                  ),
          ),
          _paginationControls(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.black12,
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay pedidos registrados',
            style: GoogleFonts.poppins(
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = o['status'] ?? 'pending';
    String formattedDate = '';
    try {
      var date = DateTime.parse(o['created_at']);
      if (!date.isUtc) {
        final str = o['created_at'].toString();
        if (!str.contains('Z') && !str.contains('+') && !str.contains('-')) {
          date = DateTime.parse('${str}Z');
        }
      }
      final peruDate = date.toUtc().subtract(const Duration(hours: 5));
      formattedDate = DateFormat('dd MMM, hh:mm a', 'es').format(peruDate);
    } catch (_) {
      formattedDate = o['created_at'].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withValues(alpha: 0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 8),
            blurRadius: 15,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(o),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _statusIcon(status),
                    color: _statusColor(status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              o['restaurant_name'] ?? 'Restaurante',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'S/. ${_format(o['total'])}',
                            style: GoogleFonts.poppins(
                              color: _red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '#${o['order_code'] ?? o['id']}',
                            style: GoogleFonts.robotoMono(
                              color: Colors.black38,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: GoogleFonts.poppins(
                          color: Colors.black26,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black12,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _paginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pageButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _loadOrders();
                    }
                  : null,
            ),
            Text(
              'Página $_currentPage de $_totalPages',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            _pageButton(
              icon: Icons.arrow_forward_ios_rounded,
              onTap: _currentPage < _totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _loadOrders();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageButton({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.black.withValues(alpha: 0.03)
              : _red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.black12 : _red,
          size: 18,
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: _red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalle del Pedido',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '#${o['order_code'] ?? o['id']}',
                          style: GoogleFonts.robotoMono(
                            color: _red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(o['status'] ?? 'pending'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('CLIENTE', o['client_name'] ?? 'N/A'),
                    _detailRow('TELÉFONO', o['client_phone'] ?? 'N/A'),
                    _detailRow('DIRECCIÓN', o['client_address'] ?? 'N/A'),

                    if (o['payment_proof_url'] != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'COMPROBANTE DE PAGO',
                        style: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showFullImage(
                          '${ApiService.baseUrl}${o['payment_proof_url']}',
                        ),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                            image: DecorationImage(
                              image: NetworkImage(
                                '${ApiService.baseUrl}${o['payment_proof_url']}',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    Text(
                      'PRODUCTOS',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...((o['items'] as List? ?? []).map((i) {
                      final qty = i['qty'] ?? i['quantity'] ?? 1;
                      final basePrice = _num(i['price']);
                      double optionsTotal = 0.0;
                      List<dynamic> options = [];
                      if (i['options'] is List) {
                        options = i['options'];
                        for (var opt in options) {
                          optionsTotal += _num(opt['price']);
                        }
                      }
                      final finalItemPrice = basePrice + optionsTotal;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: GoogleFonts.poppins(
                                      color: _red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${i['name'] ?? 'Producto'}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  'S/. ${_format(finalItemPrice * qty)}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            if (options.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 42,
                                  top: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: options.map((opt) {
                                    final optName = opt['name'] ?? 'Opción';
                                    final optPrice = _num(opt['price']);
                                    return Text(
                                      '• $optName ${optPrice > 0 ? '(+S/. ${_format(optPrice)})' : ''}',
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
                    }).toList()),

                    const SizedBox(height: 32),
                    (() {
                      double trueSubtotal = 0;
                      final items = o['items'] as List? ?? [];
                      for (var i in items) {
                        final qty = i['qty'] ?? i['quantity'] ?? 1;
                        final basePrice = _num(i['price']);
                        double optTotal = 0;
                        if (i['options'] is List) {
                          for (var opt in i['options']) {
                            optTotal += _num(opt['price']);
                          }
                        }
                        trueSubtotal += (basePrice + optTotal) * qty;
                      }

                      double restCommission = _num(o['restaurant_commission']);
                      // Fallback dinámico si la comisión guardada es 0 (para corregir pedidos antiguos o errores)
                      if (restCommission <= 0) {
                        int planId = _num(o['restaurant_plan_id']).toInt();
                        if (planId == 1) {
                          // Pakiip Emprende
                          double rate = _num(o['restaurant_commission_rate']);
                          restCommission = trueSubtotal * (rate / 100);
                        }
                      }

                      double restPayout = trueSubtotal - restCommission;

                      double deliveryFee = _num(o['delivery_fee']);
                      double tip = _num(o['tip']);
                      double serviceFee = _num(o['service_fee']);
                      double discount = _num(o['discount']);

                      double riderEarning = _num(o['rider_earning']);
                      if (riderEarning <= 0) {
                        // Usamos la tasa del motorizado si está disponible, de lo contrario fallback al 80%
                        double riderCommRate = _num(o['rider_commission_rate']);
                        if (riderCommRate <= 0) riderCommRate = 80;
                        riderEarning =
                            (deliveryFee * (riderCommRate / 100)) + tip;
                      }

                      // Ganancia de pakiip = comision_restaurante + tarifa_servicio + (delivery - ganancia_repartidor_sin_propina) - descuento
                      double deliveryAppProfit =
                          deliveryFee - (riderEarning - tip);
                      if (deliveryAppProfit < 0) deliveryAppProfit = 0;
                      double appProfit =
                          restCommission + serviceFee + deliveryAppProfit - discount;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RESUMEN DE COBRO AL CLIENTE',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                _totalRow('Monto Productos', trueSubtotal),
                                _totalRow('Costo Delivery', o['delivery_fee']),
                                _totalRow('Tarifa Pakiip', o['service_fee']),
                                if (tip > 0)
                                  _totalRow('Propina (Motorizado)', tip),
                                if (discount > 0)
                                  _totalRow('Descuento Admin', -discount, color: Colors.green),
                                const Divider(
                                  height: 24,
                                  color: Colors.black12,
                                ),
                                _totalRow(
                                  'TOTAL DEL PEDIDO',
                                  o['total'],
                                  isBold: true,
                                  fontSize: 18,
                                  color: _red,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'DESGLOSE FINANCIERO (ADMIN)',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.blueGrey.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _totalRow(
                                  'Venta Bruta (Restaurante)',
                                  trueSubtotal,
                                ),
                                _totalRow(
                                  'Comisión App (Restaurante)',
                                  -restCommission,
                                  color: Colors.redAccent,
                                ),
                                const Divider(
                                  height: 16,
                                  color: Colors.black12,
                                ),
                                _totalRow(
                                  'Pago Neto al Restaurante',
                                  restPayout,
                                  isBold: true,
                                  color: Colors.green,
                                ),

                                const SizedBox(height: 24),
                                _totalRow(
                                  'Costo Delivery (Cliente)',
                                  deliveryFee,
                                ),
                                if (tip > 0)
                                  _totalRow('Propina (Cliente)', tip),
                                const Divider(
                                  height: 16,
                                  color: Colors.black12,
                                ),
                                _totalRow(
                                  'Ganancia del Motorizado',
                                  riderEarning,
                                  isBold: true,
                                  color: Colors.blue,
                                ),

                                const SizedBox(height: 24),
                                _totalRow(
                                  'Comisión App (Restaurante)',
                                  restCommission,
                                ),
                                _totalRow('Tarifa de Servicio App', serviceFee),
                                _totalRow(
                                  'Margen App (Delivery)',
                                  deliveryAppProfit,
                                ),
                                if (discount > 0)
                                  _totalRow('Descuento Financiado por App', -discount, color: Colors.redAccent),
                                const Divider(
                                  height: 16,
                                  color: Colors.black12,
                                ),
                                _totalRow(
                                  'Ganancia Neta Pakiip',
                                  appProfit,
                                  isBold: true,
                                  color: Colors.purple,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _promptDiscount(o),
                              icon: const Icon(Icons.local_offer_rounded, color: Colors.white),
                              label: Text(
                                discount > 0 ? 'Editar Descuento' : 'Aplicar Descuento',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _red,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      );
                    })(),
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

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.black26,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _promptDiscount(Map<String, dynamic> o) {
    final controller = TextEditingController(text: _num(o['discount']).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Aplicar Descuento',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingrese el monto de descuento en S/.',
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'S/. ',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _red, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.black38, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text) ?? 0.0;
              if (val < 0) {
                _snack('El descuento no puede ser negativo', Colors.red);
                return;
              }
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close details sheet
              _applyDiscount(o['id'].toString(), val);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Aplicar',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyDiscount(String orderId, double discount) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.patch('/admin/orders/$orderId/discount', {
        'discount': discount,
      });
      _snack(res['message'] ?? 'Descuento aplicado', Colors.green);
      _loadOrders();
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error al aplicar descuento: $e', Colors.red);
    }
  }

  Widget _totalRow(
    String label,
    dynamic val, {
    bool isBold = false,
    Color? color,
    double fontSize = 13,
  }) {
    final double value = _num(val);
    final String formattedVal = value < 0
        ? '- S/. ${value.abs().toStringAsFixed(2)}'
        : 'S/. ${value.toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isBold ? Colors.black87 : Colors.black54,
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            formattedVal,
            style: GoogleFonts.poppins(
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'delivered':
      case 'completed':
        return const Color(0xFF4CAF50); // Green
      case 'cancelled':
        return Colors.red;
      case 'accepted':
        return Colors.blue;
      case 'in_delivery':
        return Colors.purple;
      case 'rider_assigned':
        return Colors.indigo;
      case 'ready':
        return Colors.teal;
      case 'preparing':
        return Colors.orange;
      case 'pending':
        return Colors.amber;
      default:
        return Colors.amber;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'delivered':
      case 'completed':
        return 'ENTREGADO';
      case 'cancelled':
        return 'CANCELADO';
      case 'in_delivery':
        return 'EN CAMINO';
      case 'rider_assigned':
        return 'MOTORIZADO ASIGNADO';
      case 'ready':
        return 'LISTO';
      case 'accepted':
        return 'ACEPTADO';
      case 'preparing':
        return 'PREPARANDO';
      case 'pending':
        return 'PENDIENTE';
      default:
        return (s ?? 'PENDIENTE').toUpperCase();
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'delivered':
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'in_delivery':
        return Icons.two_wheeler_rounded;
      case 'rider_assigned':
        return Icons.motorcycle_rounded;
      case 'ready':
        return Icons.shopping_bag_outlined;
      case 'accepted':
        return Icons.thumb_up_alt_outlined;
      case 'preparing':
        return Icons.restaurant_rounded;
      default:
        return Icons.timer_outlined;
    }
  }

  double _num(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }

  String _format(dynamic val) => _num(val).toStringAsFixed(2);
}
