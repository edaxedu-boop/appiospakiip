import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class RiderPaymentsScreen extends StatefulWidget {
  const RiderPaymentsScreen({super.key});

  @override
  State<RiderPaymentsScreen> createState() => _RiderPaymentsScreenState();
}

class _RiderPaymentsScreenState extends State<RiderPaymentsScreen> {
  Map<String, dynamic>? _earningsData;
  bool _isLoading = true;

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.get('/riders/earnings');
      if (mounted) {
        setState(() {
          _earningsData = data;
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
          'Mis Pagos',
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
              onRefresh: _loadEarnings,
              color: _red,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 32),
                    Text(
                      'DETALLE DE GANANCIAS',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final String pendingStr =
        _earningsData?['pending_payout']?.toString() ?? '0.00';
    final String totalStr =
        _earningsData?['total_earnings']?.toString() ?? '0.00';
    final commission = _earningsData?['commission_percentage'] ?? '0';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_red, _red.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BALANCE POR COBRAR',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/. $pendingStr',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL HISTÓRICO',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/. $totalStr',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  'Comisión: $commission% + 100% Propinas',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final List history = _earningsData?['history'] ?? [];
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            'No hay registros de pagos aún.',
            style: GoogleFonts.poppins(color: Colors.black26, fontSize: 13),
          ),
        ),
      );
    }

    return Column(children: history.map((o) => _paymentItem(o)).toList());
  }

  Widget _paymentItem(Map<String, dynamic> o) {
    final bool paid = o['rider_paid'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (paid ? _green : Colors.black12).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              paid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
              color: paid ? _green : Colors.black26,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pedido #${o['order_code'] ?? o['id']}',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (paid) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PAGADO',
                          style: GoogleFonts.poppins(
                            color: _green,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  (() {
                    final fee =
                        double.tryParse(o['delivery_fee']?.toString() ?? '0') ??
                        0;
                    final commPct =
                        double.tryParse(
                          o['commission_applied']?.toString() ?? '80',
                        ) ??
                        80;
                    final commAmount = (fee * commPct) / 100;
                    final tip =
                        double.tryParse(o['tip']?.toString() ?? '0') ?? 0;

                    return 'Ganancia Envío (${commPct.toStringAsFixed(0)}%): S/. ${commAmount.toStringAsFixed(2)}${tip > 0 ? ' + Propina: S/. ${tip.toStringAsFixed(2)}' : ''}';
                  })(),
                  style: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          (() {
            final fee =
                double.tryParse(o['delivery_fee']?.toString() ?? '0') ?? 0;
            final commPct =
                double.tryParse(o['commission_applied']?.toString() ?? '80') ??
                80;
            final tip = double.tryParse(o['tip']?.toString() ?? '0') ?? 0;
            final total = ((fee * commPct) / 100) + tip;

            return Text(
              '+ S/. ${total.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                color: paid ? _green : _red,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            );
          })(),
        ],
      ),
    );
  }
}
