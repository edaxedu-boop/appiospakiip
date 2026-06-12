import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key});

  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getList('/riders/orders/history');
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _red),
        );
      }
    }
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
          'Historial de Pedidos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: _red,
              child: _history.isEmpty ? _buildEmptyState() : _buildList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, size: 64, color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes pedidos entregados.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      itemBuilder: (ctx, i) => _historyCard(_history[i]),
    );
  }

  Widget _historyCard(Map<String, dynamic> o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1.2,
        ),
        boxShadow: [
          // Efecto de profundidad 3D
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
          // Sombra de elevación suave
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
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
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${o['order_code'] ?? o['id']}',
                  style: GoogleFonts.poppins(
                    color: _green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(o['delivered_at'] ?? o['created_at']),
                style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  (() {
                    final fee =
                        double.tryParse(o['delivery_fee']?.toString() ?? '0') ??
                        0;
                    final commPct =
                        o['rider_commission_pct'] ??
                        o['commission_applied'] ??
                        80; // Fallback a 80% si no existe

                    final earning = o['rider_earning'] != null
                        ? (double.tryParse(o['rider_earning'].toString()) ?? 0)
                        : (fee * commPct / 100);

                    final tip =
                        double.tryParse(o['tip']?.toString() ?? '0') ?? 0;
                    final total = earning + tip;
                    return Text(
                      'S/. ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: _green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    );
                  })(),
                  Text(
                    'Tu ganancia',
                    style: GoogleFonts.poppins(
                      color: Colors.black26,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          (() {
            final fee =
                double.tryParse(o['delivery_fee']?.toString() ?? '0') ?? 0;
            final commPct =
                o['rider_commission_pct'] ?? o['commission_applied'] ?? 80;

            final earning = o['rider_earning'] != null
                ? (double.tryParse(o['rider_earning'].toString()) ?? 0)
                : (fee * commPct / 100);

            final tip = double.tryParse(o['tip']?.toString() ?? '0') ?? 0;

            return Text(
              'Envío ($commPct%): S/. ${earning.toStringAsFixed(2)}${tip > 0 ? ' + Propina: S/. ${tip.toStringAsFixed(2)}' : ''}',
              style: GoogleFonts.poppins(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            );
          })(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.store_rounded, color: _red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o['restaurant_name'] ?? 'Restaurante',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: _green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o['client_address'] ?? 'Dirección',
                  style: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ENTREGADO',
                style: GoogleFonts.poppins(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Row(
                children: [
                  if ((o['tip'] ?? 0) > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '🤝 +S/. ${o['tip']}',
                        style: GoogleFonts.poppins(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  (() {
                    final discount = double.tryParse(o['discount']?.toString() ?? '0') ?? 0;
                    return Text(
                      'Cobrado: S/. ${o['total']}${discount > 0 ? ' (Desc: S/. ${discount.toStringAsFixed(2)})' : ''}',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    );
                  })(),
                ],
              ),
            ],
          ),
        ],
      ),
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
}
