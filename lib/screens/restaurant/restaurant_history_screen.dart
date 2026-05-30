import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class RestaurantHistoryScreen extends StatefulWidget {
  const RestaurantHistoryScreen({super.key});

  @override
  State<RestaurantHistoryScreen> createState() => _RestaurantHistoryScreenState();
}

class _RestaurantHistoryScreenState extends State<RestaurantHistoryScreen> {
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);

  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Usamos el endpoint correcto que definimos en el backend
      final list = await ApiService.getList('/orders/restaurant/all');
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '--:--';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregado':
      case 'delivered':
        return Colors.green;
      case 'cancelado':
      case 'cancelled':
        return Colors.red;
      case 'nuevo':
      case 'new':
        return Colors.blue;
      default:
        return _red;
    }
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return 'Entregado';
      case 'cancelled': return 'Cancelado';
      case 'new': return 'Nuevo';
      case 'preparing': return 'Preparando';
      case 'ready': return 'Listo';
      case 'on_the_way': return 'En camino';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Historial de Pedidos',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black45),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? _buildErrorView()
              : _orders.isEmpty
                  ? _buildEmptyView()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _orders.length,
                      itemBuilder: (ctx, i) => _buildOrderCard(_orders[i]),
                    ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_outlined, color: Colors.black12, size: 64),
          const SizedBox(height: 16),
          Text(
            'No hay pedidos en el historial',
            style: GoogleFonts.poppins(color: Colors.black38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el historial',
              style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadHistory,
              style: ElevatedButton.styleFrom(backgroundColor: _red),
              child: Text('Reintentar', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'desconocido';
    final code = order['order_code'] ?? '---';
    final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
    final client = order['client_name'] ?? order['client'] ?? 'Cliente';
    
    double subtotal = 0;
    try {
      dynamic itemsData = order['items'];
      List<dynamic> items = [];
      if (itemsData is List) {
        items = itemsData;
      } else if (itemsData is String) {
        items = jsonDecode(itemsData);
      }
      for (var item in items) {
        final qty = item['qty'] ?? 1;
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        double itemTotal = price;
        
        final options = item['options'];
        if (options is List) {
          for (var opt in options) {
            final optPrice = double.tryParse(opt['price']?.toString() ?? '0') ?? 0.0;
            itemTotal += optPrice;
          }
        }
        subtotal += (itemTotal * qty);
      }
    } catch (_) {
      subtotal = total - 
        (double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0) - 
        (double.tryParse(order['service_fee']?.toString() ?? '0') ?? 0) -
        (double.tryParse(order['tip']?.toString() ?? '0') ?? 0);
    }

    final List<dynamic> itemsList = (() {
      try {
        dynamic itemsData = order['items'];
        if (itemsData is List) return itemsData;
        if (itemsData is String) return jsonDecode(itemsData);
      } catch (_) {}
      return [];
    })();
    final bool isManual = itemsList.isNotEmpty && (itemsList[0]['name'] == 'Pedido Manual' || itemsList[0]['name'] == 'Favor');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Row(
          children: [
            Text(
              '#$code',
              style: GoogleFonts.poppins(
                color: _red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (isManual) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'MANUAL',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _translateStatus(status).toUpperCase(),
                style: GoogleFonts.poppins(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              client,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              _formatDate(order['created_at']),
              style: GoogleFonts.poppins(color: Colors.black38, fontSize: 12),
            ),
          ],
        ),
        trailing: Text(
          'S/. ${total.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: _border),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.info_outline,
                  'Estado: ${_translateStatus(status).toUpperCase()}',
                  color: _getStatusColor(status),
                ),
                const SizedBox(height: 6),
                _infoRow(Icons.location_on_outlined, order['client_address'] ?? 'Sin dirección'),
                const SizedBox(height: 6),
                _infoRow(Icons.phone_outlined, 'Teléfono: ${order['client_phone'] ?? 'No disponible'}'),
                const SizedBox(height: 6),
                _infoRow(Icons.payment_outlined, 'Pago: ${order['payment_method'] ?? 'No especificado'}'),
                if (order['notes'] != null && order['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.note_outlined, 'Nota: ${order['notes']}'),
                ],
                const SizedBox(height: 16),
                Text(
                  isManual ? 'INDICACIONES DEL ENVÍO' : 'PRODUCTOS',
                  style: GoogleFonts.poppins(
                    color: Colors.black26,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                if (isManual)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _red.withOpacity(0.1)),
                    ),
                    child: Text(
                      order['notes']?.toString() ?? 'Sin descripción',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  ..._buildItemsList(order['items']),
                const SizedBox(height: 16),
                const Divider(color: _border),
                _priceRow('Subtotal', subtotal),
                _priceRow('Costo Delivery', double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0),
                _priceRow('Tarifa de Servicio', double.tryParse(order['service_fee']?.toString() ?? '0') ?? 0),
                (() {
                  final tip = double.tryParse(order['tip']?.toString() ?? '0') ?? 0;
                  if (tip > 0) {
                    return _priceRow('Propina (Motorizado)', tip);
                  }
                  return const SizedBox.shrink();
                })(),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'S/. ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: _red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _red.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESUMEN FINANCIERO',
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _priceRow('Pagado por el cliente', total),
                      (() {
                        final comm = double.tryParse(order['restaurant_commission']?.toString() ?? '0') ?? 0;
                        if (comm > 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Comisión App',
                                  style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13),
                                ),
                                Text(
                                  '- S/. ${comm.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      })(),
                      const Divider(color: Colors.black12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TU GANANCIA',
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          (() {
                            final comm = double.tryParse(order['restaurant_commission']?.toString() ?? '0') ?? 0;
                            final finalPayout = subtotal - comm;
                            return Text(
                              'S/. ${finalPayout.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            );
                          })(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemsList(dynamic itemsData) {
    List<dynamic> items = [];
    if (itemsData is List) {
      items = itemsData;
    } else if (itemsData is String) {
      try {
        // En algunos casos el backend envía el JSON como string
        items = jsonDecode(itemsData);
      } catch (_) {}
    }

    return items.map((item) {
      final qty = item['qty'] ?? 1;
      final name = item['name'] ?? 'Producto';
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      
      double itemTotal = price;
      List<dynamic> options = [];
      if (item['options'] is List) {
        options = item['options'];
        for (var opt in options) {
          final optPrice = double.tryParse(opt['price']?.toString() ?? '0') ?? 0.0;
          itemTotal += optPrice;
        }
      }
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${qty}x',
                    style: GoogleFonts.poppins(
                      color: _red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
                  ),
                ),
                Text(
                  'S/. ${(itemTotal * qty).toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
            if (options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: options.map((opt) {
                    final optName = opt['name'] ?? 'Opción';
                    final optPrice = double.tryParse(opt['price']?.toString() ?? '0') ?? 0.0;
                    return Text(
                      '• $optName ${optPrice > 0 ? '(+S/. ${optPrice.toStringAsFixed(2)})' : ''}',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 11,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _priceRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
          ),
          Text(
            'S/. ${value.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.black26, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: color ?? Colors.black54,
              fontSize: 13,
              fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
