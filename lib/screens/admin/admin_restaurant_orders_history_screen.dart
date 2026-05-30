import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../services/api_service.dart';

class AdminRestaurantOrdersHistoryScreen extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;
  final int? initialMonth;
  final int? initialYear;

  const AdminRestaurantOrdersHistoryScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.initialMonth,
    this.initialYear,
  });

  @override
  State<AdminRestaurantOrdersHistoryScreen> createState() =>
      _AdminRestaurantOrdersHistoryScreenState();
}

class _AdminRestaurantOrdersHistoryScreenState
    extends State<AdminRestaurantOrdersHistoryScreen> {
  static const Color _bg = Colors.white;
  static const Color _red = Color(0xFFFA7516);

  bool _loading = true;
  List<dynamic> _orders = [];
  String? _selectedDateStr; // YYYY-MM-DD
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _selectedMonth = widget.initialMonth;
    _selectedYear = widget.initialYear;
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      String query = '';
      if (_selectedDateStr != null) {
        query = '?day=$_selectedDateStr';
      } else if (_selectedMonth != null && _selectedYear != null) {
        query = '?month=$_selectedMonth&year=$_selectedYear';
      }

      final data = await ApiService.getList(
        '/admin/restaurants/${widget.restaurantId}/orders$query',
      );
      if (mounted) {
        setState(() {
          _orders = data;
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

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
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
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial de Pedidos',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.restaurantName,
              style: GoogleFonts.poppins(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showFilters,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: _red, size: 20),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          _buildFilterStatus(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _red))
                : _orders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _orders.length,
                    itemBuilder: (ctx, i) => _orderCard(_orders[i]),
                  ),
          ),
          _buildSummaryFooter(),
        ],
      ),
    );
  }

  Widget _buildFilterStatus() {
    String text = 'Mostrando todos los pedidos';
    if (_selectedDateStr != null) {
      text = 'Filtrando día: $_selectedDateStr';
    } else if (_selectedMonth != null && _selectedYear != null) {
      try {
        final monthName = DateFormat(
          'MMMM',
          'es',
        ).format(DateTime(_selectedYear!, _selectedMonth!));
        text = 'Mes: ${monthName.toUpperCase()} $_selectedYear';
      } catch (_) {
        text = 'Mes: $_selectedMonth / $_selectedYear';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: _red.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: _red),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_selectedDateStr != null || _selectedMonth != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDateStr = null;
                  _selectedMonth = null;
                  _selectedYear = null;
                });
                _loadOrders();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Limpiar',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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
            'No hay pedidos para este periodo',
            style: GoogleFonts.poppins(
              color: Colors.black38,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(dynamic o) {
    final status = o['status'] ?? 'pending';
    String formattedDate = '';
    try {
      final date = DateTime.parse(o['created_at']);
      formattedDate = DateFormat('dd MMM, HH:mm', 'es').format(date);
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
                              o['client_name'] ?? 'Cliente',
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
                          _statusBadgeWidget(status),
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

  Widget _statusBadgeWidget(String status) {
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

  void _showDetails(dynamic o) {
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
                  _statusBadgeWidget(o['status'] ?? 'pending'),
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
                    ...((o['items'] is List ? (o['items'] as List) : []).map((
                      i,
                    ) {
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
                      final items = o['items'] is List
                          ? (o['items'] as List)
                          : [];
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
                      if (restCommission <= 0) {
                        int planId = _num(o['restaurant_plan_id']).toInt();
                        if (planId == 1) {
                          double rate = _num(o['restaurant_commission_rate']);
                          restCommission = trueSubtotal * (rate / 100);
                        }
                      }

                      double restPayout = trueSubtotal - restCommission;
                      double deliveryFee = _num(o['delivery_fee']);
                      double tip = _num(o['tip']);
                      double serviceFee = _num(o['service_fee']);

                      double riderEarning = _num(o['rider_earning']);
                      if (riderEarning <= 0) {
                        double riderCommRate = _num(o['rider_commission_rate']);
                        if (riderCommRate <= 0) riderCommRate = 80;
                        riderEarning =
                            (deliveryFee * (riderCommRate / 100)) + tip;
                      }

                      double deliveryAppProfit =
                          deliveryFee - (riderEarning - tip);
                      if (deliveryAppProfit < 0) deliveryAppProfit = 0;
                      double appProfit =
                          restCommission + serviceFee + deliveryAppProfit;

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
                                _totalRow('Costo Delivery', deliveryFee),
                                _totalRow('Tarifa Pakiip', serviceFee),
                                if (tip > 0)
                                  _totalRow('Propina (Motorizado)', tip),
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

  Widget _totalRow(
    String label,
    dynamic val, {
    bool isBold = false,
    Color? color,
    double fontSize = 13,
  }) {
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
            'S/. ${_format(val)}',
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Filtrar Historial',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 24),
            _filterOption(
              icon: Icons.calendar_today_rounded,
              title: 'Filtrar por Día',
              subtitle: 'Selecciona una fecha específica',
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: _red),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null && mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedDateStr = DateFormat('yyyy-MM-dd').format(date);
                    _selectedMonth = null;
                    _selectedYear = null;
                  });
                  _loadOrders();
                }
              },
            ),
            const SizedBox(height: 12),
            _filterOption(
              icon: Icons.date_range_rounded,
              title: 'Filtrar por Mes',
              subtitle: 'Resumen mensual de ventas',
              onTap: () {
                Navigator.pop(ctx);
                _selectMonthYear();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _red, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black12,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _selectMonthYear() {
    final now = DateTime.now();
    int m = now.month;
    int y = now.year;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Seleccionar Mes/Año',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: m,
                isExpanded: true,
                dropdownColor: Colors.white,
                items: List.generate(12, (i) => i + 1).map((val) {
                  String mName = val.toString();
                  try {
                    mName = DateFormat(
                      'MMMM',
                      'es',
                    ).format(DateTime(2022, val));
                  } catch (_) {}
                  return DropdownMenuItem(
                    value: val,
                    child: Text(
                      mName,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setS(() => m = v!),
              ),
              const SizedBox(height: 10),
              DropdownButton<int>(
                value: y,
                isExpanded: true,
                dropdownColor: Colors.white,
                items: [2024, 2025, 2026].map((val) {
                  return DropdownMenuItem(
                    value: val,
                    child: Text(
                      '$val',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setS(() => y = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(
                  color: Colors.black38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedDateStr = null;
                  _selectedMonth = m;
                  _selectedYear = y;
                });
                _loadOrders();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Aplicar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryFooter() {
    if (_orders.isEmpty) return const SizedBox.shrink();

    double totalSales = 0;
    double totalCommission = 0;

    for (var o in _orders) {
      if (['delivered', 'completed'].contains(o['status'])) {
        final items = o['items'] is List ? (o['items'] as List) : [];
        double orderSub = 0;
        for (var i in items) {
          final qty = i['qty'] ?? i['quantity'] ?? 1;
          final base = _num(i['price']);
          double opts = 0;
          if (i['options'] is List) {
            for (var opt in i['options']) {
              opts += _num(opt['price']);
            }
          }
          orderSub += (base + opts) * qty;
        }

        double comm = _num(o['restaurant_commission']);
        if (comm <= 0) {
          int planId = _num(o['restaurant_plan_id']).toInt();
          if (planId == 1) {
            double rate = _num(o['restaurant_commission_rate']);
            comm = orderSub * (rate / 100);
          }
        }
        totalSales += orderSub;
        totalCommission += comm;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RESUMEN DEL PERIODO',
                  style: GoogleFonts.poppins(
                    color: Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Solo Entregados',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF4CAF50),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _summaryItem(
                  'Ventas Totales',
                  'S/. ${totalSales.toStringAsFixed(2)}',
                  Icons.payments_outlined,
                ),
                const SizedBox(width: 16),
                _summaryItem(
                  'Comisiones',
                  'S/. ${totalCommission.toStringAsFixed(2)}',
                  Icons.receipt_long_outlined,
                  color: _red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? Colors.black87).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? Colors.black26, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: color ?? Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'delivered':
      case 'completed':
        return const Color(0xFF4CAF50);
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
