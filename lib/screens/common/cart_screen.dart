import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/restaurant_models.dart';
import '../../services/cart_service.dart';
import '../../services/api_service.dart';
import '../../widgets/delivery_location_dialog.dart';
import 'package:pakiip/screens/common/orders_screen.dart';
import '../../widgets/cart_widgets.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final String restaurantName;
  final String initialAddress;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.restaurantName,
    this.initialAddress = '',
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // 0: Yape, 1: Efectivo
  int _selectedPaymentMethod = 0;
  double _selectedTip = 1.0; // Propina por defecto S/ 1 para el motorizado
  bool _isSubmitting = false;
  double _serviceFee = 2.00;
  double _baseCost1Km = 4.00;
  double _priceIntermediate = 1.00;
  double _priceLong = 2.00;

  // Coupon variables
  final TextEditingController _couponController = TextEditingController();
  bool _isValidatingCoupon = false;
  String? _appliedCouponCode;
  double _couponDiscount = 0.00;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _loadGlobalConfig();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalConfig() async {
    try {
      final config = await ApiService.get('/config/public');
      if (mounted) {
        setState(() {
          // Tarifa de Servicio (Default: 2.00)
          _serviceFee =
              double.tryParse(
                (config['service_fee'] ?? config['serviceFee'] ?? '2.00')
                    .toString(),
              ) ??
              2.00;

          // Precios escalonados
          _baseCost1Km =
              double.tryParse((config['base_cost_1km'] ?? '4.00').toString()) ??
              4.00;
          _priceIntermediate =
              double.tryParse(
                (config['price_per_km_intermediate'] ?? '1.00').toString(),
              ) ??
              1.00;
          _priceLong =
              double.tryParse(
                (config['price_per_km_long'] ?? '2.00').toString(),
              ) ??
              2.00;
        });
      }
    } catch (e) {
      debugPrint('Error loading global config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = Provider.of<CartService>(context);
    final cartItems = cartService.items;

    double subtotal = cartService.totalPrice;

    // Calcular distancia y costo de delivery dinámico
    double? distanceM;
    if (cartService.userLat != null && cartService.restaurantLat != null) {
      distanceM = Geolocator.distanceBetween(
        cartService.userLat!,
        cartService.userLng!,
        cartService.restaurantLat!,
        cartService.restaurantLng!,
      );
    }

    // Fórmula de delivery escalonada
    double deliveryCost = _baseCost1Km; // mínimo por defecto (<= 1 km)
    if (distanceM != null) {
      double distanceKm = distanceM / 1000;
      if (distanceKm > 1.0 && distanceKm <= 3.0) {
        deliveryCost = _baseCost1Km + ((distanceKm - 1.0) * _priceIntermediate);
      } else if (distanceKm > 3.0) {
        deliveryCost =
            _baseCost1Km +
            (2.0 * _priceIntermediate) +
            ((distanceKm - 3.0) * _priceLong);
      }
      deliveryCost = double.parse(deliveryCost.toStringAsFixed(2));
    }

    double serviceFee = _serviceFee;
    double tip = _selectedTip;
    double total = ((subtotal + deliveryCost + serviceFee + tip) - _couponDiscount).clamp(0.00, double.infinity);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Resumen de Pago',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Borrar carrito',
              onPressed: () => _showClearCartDialog(context, cartService),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          cartItems.isEmpty
              ? _buildEmptyCart()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Map / Address Section
                      Container(
                        height:
                            140, // Un poco más alto para que se aprecie el mapa
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.black87,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          children: [
                            // ── Map Background ──
                            if (cartService.userLat != null &&
                                cartService.userLng != null)
                              IgnorePointer(
                                child: GoogleMap(
                                  key: ValueKey(
                                    '${cartService.userLat}_${cartService.userLng}',
                                  ),
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      cartService.userLat!,
                                      cartService.userLng!,
                                    ),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('delivery_pin'),
                                      position: LatLng(
                                        cartService.userLat!,
                                        cartService.userLng!,
                                      ),
                                    ),
                                  },
                                  liteModeEnabled:
                                      true, // Lite mode para mejor performance en listas/resumenes
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                ),
                              )
                            else
                              // Placeholder si no hay coordenadas
                              Positioned.fill(
                                child: Image.network(
                                  'https://images.unsplash.com/photo-1524661135-423995f22d0b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                                  fit: BoxFit.cover,
                                ),
                              ),

                            // ── Overlay Gradient ──
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.1),
                                      Colors.black.withValues(alpha: 0.3),
                                      Colors.white.withValues(alpha: 0.8),
                                      Colors.white,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ── Content ──
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFA7516),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delivery_dining,
                                          color: Colors.black87,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          '${cartService.minTime ?? 25} - ${cartService.maxTime ?? 35} min',
                                          style: GoogleFonts.poppins(
                                            color: Colors.black87,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Color(0xFFFA7516),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Entrega en:',
                                              style: GoogleFonts.poppins(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              cartService.address.isNotEmpty
                                                  ? cartService.address
                                                  : 'Toca Editar para agregar dirección',
                                              style: GoogleFonts.poppins(
                                                color: Colors.black54,
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _changeAddress(cartService),
                                        child: Text(
                                          'Editar',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFFA7516),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tu Pedido
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Tu Pedido',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Restaurant Name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront,
                              color: Color(0xFFFA7516),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cartService.currentRestaurantName ??
                                  widget.restaurantName,
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cart Items
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          return CartItemCard(
                            item: item,
                            cartService: cartService,
                          );
                        },
                      ),

                      // Add More Items
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xFFFA7516),
                          ),
                          label: Text(
                            'Agregar más ítems',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFA7516),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Método de Pago
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Método de Pago',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: PaymentMethodCard(
                                index: 0,
                                selectedIndex: _selectedPaymentMethod,
                                title: 'Yape',
                                subtitle: 'Pago QR',
                                icon: Icons.qr_code_scanner,
                                onTap: (idx) => setState(
                                  () => _selectedPaymentMethod = idx,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PaymentMethodCard(
                                index: 1,
                                selectedIndex: _selectedPaymentMethod,
                                title: 'Efectivo',
                                subtitle: 'Contraentrega',
                                icon: Icons.money,
                                onTap: (idx) => setState(
                                  () => _selectedPaymentMethod = idx,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sección de Cupón de Descuento
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Tienes un cupón de descuento?',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponController,
                                    enabled: _appliedCouponCode == null && !_isValidatingCoupon,
                                    textCapitalization: TextCapitalization.characters,
                                    style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Ingresa código...',
                                      hintStyle: GoogleFonts.poppins(color: Colors.black38),
                                      prefixIcon: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFFA7516)),
                                      filled: true,
                                      fillColor: const Color(0xFFF7F7F7),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFFA7516),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 54,
                                  child: _appliedCouponCode != null
                                      ? ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _appliedCouponCode = null;
                                              _couponDiscount = 0.00;
                                              _couponController.clear();
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            'Quitar',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : ElevatedButton(
                                          onPressed: _isValidatingCoupon
                                              ? null
                                              : () {
                                                  _validateCoupon(
                                                    _couponController.text,
                                                    cartService.currentRestaurantId ?? '0',
                                                    subtotal,
                                                  );
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFA7516),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: _isValidatingCoupon
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  'Aplicar',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                ),
                              ],
                            ),
                            if (_couponError != null) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  _couponError!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            if (_appliedCouponCode != null) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '¡Cupón $_appliedCouponCode aplicado con éxito!',
                                  style: GoogleFonts.poppins(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Cost Breakdown
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            CostRow(
                              label: 'Subtotal',
                              value: 'S/ ${subtotal.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 8),
                            CostRow(
                              label: 'Costo de Envío',
                              value: 'S/ ${deliveryCost.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 8),
                            CostRow(
                              label: 'Tarifa de Servicio',
                              value: 'S/ ${serviceFee.toStringAsFixed(2)}',
                            ),
                            if (_selectedTip > 0) ...[
                              const SizedBox(height: 8),
                              CostRow(
                                label: '🤝 Propina al Motorizado',
                                value: 'S/ ${_selectedTip.toStringAsFixed(2)}',
                                highlight: true,
                              ),
                            ],
                            if (_couponDiscount > 0) ...[
                              const SizedBox(height: 8),
                              CostRow(
                                label: 'Descuento Cupón ($_appliedCouponCode)',
                                value: '- S/ ${_couponDiscount.toStringAsFixed(2)}',
                                highlight: true,
                              ),
                            ],
                            const Divider(color: Colors.white12, height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'S/ ${total.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFA7516),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tip Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '🤝',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Propina para el motorizado',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Opcional — 100% va para el repartidor',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [0.0, 1.0, 3.0, 5.0].map((tip) {
                                final selected = _selectedTip == tip;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedTip = tip),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFFFA7516)
                                              : Colors.white.withValues(
                                                  alpha: 0.05,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFFFA7516)
                                                : Colors.white12,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              tip == 0
                                                  ? 'Sin\npropina'
                                                  : 'S/ ${tip.toInt()}',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                color: selected
                                                    ? Colors.white
                                                    : Colors.black54,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Security Note
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock,
                              color: Colors.black38,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tus pagos son procesados de forma 100% segura',
                              style: GoogleFonts.poppins(
                                color: Colors.black38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFA7516)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedPaymentMethod == 0) {
                        _showYapeDialog(context, total);
                      } else {
                        _showEfectivoDialog(context, total);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA7516),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Confirmar Pedido',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'S/ ${total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ─── Yape QR Dialog ─────────────────────────────────────────────────────────
  void _showYapeDialog(BuildContext context, double total) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.90,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),

              // Yape Logo row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFA7516),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_2,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Paga con Yape',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Escanea el código o copia el número',
                style: GoogleFonts.poppins(color: Colors.black45, fontSize: 13),
              ),

              const SizedBox(height: 20),

              // QR Code
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/QRYAPE.jpeg',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          width: 180,
                          height: 180,
                          child: Center(
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              size: 100,
                              color: Color(0xFFFA7516),
                            ),
                          ),
                        ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Amount
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFA7516).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFA7516).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Monto a pagar: ',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    Text(
                      'S/ ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFA7516),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Name + Copy
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_pin_rounded,
                      color: Color(0xFFFA7516),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Titular / Nombre',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Pakiip Global Sacs',
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CopyButton(textToCopy: 'Pakiip Global Sacs'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Button: Ya realicé el pago
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (!mounted) return;
                      _showYapeUploadSheet(this.context);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA7516),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ya realicé el pago',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Button: Pagaré al momento de la entrega
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPayAtDeliveryConfirm(context, paymentMethod: 'yape');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFFA7516),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delivery_dining,
                        color: Color(0xFFFA7516),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pagaré al momento de la entrega',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFA7516),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Yape Upload Sheet ──────────────────────────────────────────────────────
  void _showYapeUploadSheet(BuildContext context) {
    File? pickedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.80,
          ),
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA7516).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Color(0xFFFA7516),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comprobante de pago',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Adjunta una captura de tu pago Yape',
                          style: GoogleFonts.poppins(
                            color: Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── QR Code Section ───────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Escanea el QR para pagar',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFA7516,
                              ).withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/QRYAPE.jpeg',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 180,
                                  height: 180,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: const Icon(
                                    Icons.qr_code_2,
                                    size: 100,
                                    color: Color(0xFFFA7516),
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pakiip Global Sacs',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Una vez pagado, adjunta la captura abajo',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFA7516),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Image preview or placeholder
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    await showModalBottomSheet(
                      context: ctx,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFFFA7516),
                              ),
                              title: Text(
                                'Tomar foto',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final img = await picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 80,
                                );
                                if (img != null) {
                                  setSheet(() => pickedImage = File(img.path));
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.photo_library,
                                color: Color(0xFFFA7516),
                              ),
                              title: Text(
                                'Elegir de galería',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final img = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                );
                                if (img != null) {
                                  setSheet(() => pickedImage = File(img.path));
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: pickedImage != null
                            ? const Color(0xFFFA7516)
                            : Colors.white12,
                        width: pickedImage != null ? 2 : 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(pickedImage!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Toca para adjuntar captura',
                                style: GoogleFonts.poppins(
                                  color: Colors.black38,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cámara o galería',
                                style: GoogleFonts.poppins(
                                  color: Colors.black26,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                if (pickedImage != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => setSheet(() => pickedImage = null),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    label: Text(
                      'Eliminar imagen',
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Confirm
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: pickedImage != null
                        ? () {
                            Navigator.pop(ctx);
                            _submitOrder(
                              context: context,
                              paymentMethod: 'yape',
                              paymentProof: pickedImage,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA7516),
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pickedImage != null
                              ? 'Confirmar Pedido'
                              : 'Adjunta la captura primero',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Pay at delivery confirm ───────────────────────────────────────────────
  void _showPayAtDeliveryConfirm(BuildContext context, {String paymentMethod = 'cash'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              paymentMethod == 'yape' ? Icons.qr_code_scanner : Icons.delivery_dining,
              color: const Color(0xFFFA7516),
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                paymentMethod == 'yape' ? 'Pago con Yape al entregar' : 'Pago en Efectivo',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Slightly smaller to ensure it fits better
                ),
              ),
            ),
          ],
        ),
        content: Text(
          paymentMethod == 'yape'
            ? 'Tu pedido será confirmado. El repartidor recibirá el pago por Yape al momento de la entrega.'
            : 'Tu pedido será confirmado y el repartidor recibirá el pago en efectivo al momento de la entrega.',
          style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitOrder(context: context, paymentMethod: paymentMethod);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA7516),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Confirmar Pedido',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Order success dialog ──────────────────────────────────────────────────
  void _showOrderSuccessDialog(BuildContext context) {
    final cartService = Provider.of<CartService>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Pedido confirmado!',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu pedido ha sido enviado. Estamos esperando que el restaurante lo confirme.',
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  cartService.clear();
                  Navigator.pop(ctx); // Cerrar dialogo
                  Navigator.pop(context); // Cerrar carrito
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrdersScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFA7516),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Ver mis pedidos',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Efectivo Dialog ────────────────────────────────────────────────────────
  void _showEfectivoDialog(BuildContext context, double total) {
    final TextEditingController amountController = TextEditingController();
    double? change;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFA7516,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.money,
                          color: Color(0xFFFA7516),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pago en Efectivo',
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'El repartidor llevará cambio',
                            style: GoogleFonts.poppins(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Total to pay
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFA7516).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFA7516).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total a pagar',
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'S/ ${total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFA7516),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    '¿Con cuánto pagas?',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick bills
                  Row(
                    children: [20, 50, 100, 200].map((bill) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              amountController.text = '$bill';
                              setModalState(() {
                                final paid = double.tryParse('$bill') ?? 0;
                                change = paid >= total ? paid - total : null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black12.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Center(
                                child: Text(
                                  'S/$bill',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Custom amount input
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      hintText: 'Otro monto...',
                      hintStyle: GoogleFonts.poppins(color: Colors.black26),
                      prefixText: 'S/ ',
                      prefixStyle: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFFA7516),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      final paid = double.tryParse(v) ?? 0;
                      setModalState(() {
                        change = paid >= total ? paid - total : null;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Change indicator
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstChild: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA7516).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFA7516).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.change_circle,
                            color: Color(0xFFFA7516),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vuelto',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'S/ ${change?.toStringAsFixed(2) ?? '0.00'}',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFA7516),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    secondChild: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ingresa un monto mayor al total',
                            style: GoogleFonts.poppins(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: (change != null)
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                  ),

                  const SizedBox(height: 20),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: change != null
                          ? () {
                              Navigator.pop(ctx);
                              _submitOrder(
                                context: context,
                                paymentMethod: 'cash',
                                changeAmount: change,
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFA7516),
                        disabledBackgroundColor: Colors.white12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Confirmar Pedido en Efectivo',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeAddress(CartService cartService) async {
    final result = await DeliveryLocationDialog.show(
      context,
      LocationDialogMode.login,
      initialAddress: cartService.address,
      initialLat: cartService.userLat,
      initialLng: cartService.userLng,
    );
    if (result != null && mounted) {
      cartService.setAddress(
        result['address'],
        lat: result['lat'],
        lng: result['lng'],
      );
      setState(() {}); // Forzar rebuild para el mapa local si es necesario
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _validateCoupon(String code, String restaurantId, double subtotal) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });
    try {
      final res = await ApiService.postAuth('/coupons/validate', {
        'code': code.trim(),
        'restaurant_id': int.parse(restaurantId),
        'subtotal': subtotal,
      });
      if (res['valid'] == true) {
        setState(() {
          _appliedCouponCode = res['code'];
          _couponDiscount = double.tryParse(res['calculated_discount'].toString()) ?? 0.00;
          _couponError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cupón aplicado con éxito! 🎉')),
        );
      } else {
        setState(() {
          _appliedCouponCode = null;
          _couponDiscount = 0.00;
          _couponError = res['error'] ?? 'Cupón inválido';
        });
      }
    } catch (e) {
      setState(() {
        _appliedCouponCode = null;
        _couponDiscount = 0.00;
        _couponError = 'Error al validar el cupón';
      });
    } finally {
      setState(() {
        _isValidatingCoupon = false;
      });
    }
  }

  Future<void> _submitOrder({
    required BuildContext context,
    required String paymentMethod,
    File? paymentProof,
    double? changeAmount,
  }) async {
    final cartService = Provider.of<CartService>(context, listen: false);
    if (cartService.items.isEmpty) return;

    if (mounted) setState(() => _isSubmitting = true);

    try {
      String? proofUrl;
      if (paymentProof != null) {
        final res = await ApiService.uploadFile(
          '/upload/payment-proof',
          paymentProof.path,
        );
        proofUrl = res['imageUrl'] as String?;
      }

      // Obtener teléfono real del cliente desde su perfil
      String? clientPhone;
      try {
        final profile = await ApiService.get('/auth/clients/me');
        clientPhone = profile['phone']?.toString();
      } catch (_) {}

      final itemsData = cartService.items.map((item) {
        return {
          'id': item.product.id,
          'name': item.product.name,
          'price': item.product.price,
          'quantity': item.quantity,
          'options': item.selectedOptions
              .map((o) => {'name': o.name, 'price': o.price})
              .toList(),
        };
      }).toList();

      // Recalcular costos con los valores actuales del estado para asegurar consistencia
      double? distanceM;
      if (cartService.userLat != null && cartService.restaurantLat != null) {
        distanceM = Geolocator.distanceBetween(
          cartService.userLat!,
          cartService.userLng!,
          cartService.restaurantLat!,
          cartService.restaurantLng!,
        );
      }

      // Fórmula de delivery escalonada consistente
      double deliveryCost = _baseCost1Km;
      if (distanceM != null) {
        double dKm = distanceM / 1000;
        if (dKm > 1.0 && dKm <= 3.0) {
          deliveryCost = _baseCost1Km + ((dKm - 1.0) * _priceIntermediate);
        } else if (dKm > 3.0) {
          deliveryCost =
              _baseCost1Km +
              (2.0 * _priceIntermediate) +
              ((dKm - 3.0) * _priceLong);
        }
        deliveryCost = double.parse(deliveryCost.toStringAsFixed(2));
      }

      final total =
          (cartService.totalPrice + deliveryCost + _serviceFee + _selectedTip) - _couponDiscount;

      final data = {
        'restaurant_id': int.parse(cartService.currentRestaurantId ?? '0'),
        'items': itemsData,
        'total': total,
        'delivery_fee': deliveryCost,
        'service_fee': _serviceFee,
        'tip': _selectedTip,
        'payment_method': paymentMethod,
        'payment_proof_url': proofUrl,
        'client_address': cartService.address,
        'client_phone': clientPhone,
        'client_lat': cartService.userLat,
        'client_lng': cartService.userLng,
        'discount': _couponDiscount,
        'coupon_code': _appliedCouponCode,
        'notes': changeAmount != null
            ? 'Paga con S/ ${(changeAmount + total).toStringAsFixed(2)}. Vuelto: S/ ${changeAmount.toStringAsFixed(2)}'
            : null,
      };

      await ApiService.postAuth('/orders', data);

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showOrderSuccessDialog(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al crear pedido: $e')));
      }
    }
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.white12,
          ),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: GoogleFonts.poppins(
              color: Colors.black38,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega productos desde un restaurante',
            style: GoogleFonts.poppins(color: Colors.black26, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA7516),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Explorar restaurantes',
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

  void _showClearCartDialog(BuildContext context, CartService cartService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Vaciar Carrito',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar todos los productos del carrito?',
          style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA7516),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              cartService.clear();
              Navigator.pop(ctx);
            },
            child: Text(
              'Vaciar',
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
}

// ─── Copy Button Widget ────────────────────────────────────────────────────────
class _CopyButton extends StatefulWidget {
  final String textToCopy;
  const _CopyButton({required this.textToCopy});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.textToCopy));
        setState(() => _copied = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _copied
              ? Colors.green.withValues(alpha: 0.15)
              : const Color(0xFF6D1BE0).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _copied
                ? Colors.green.withValues(alpha: 0.4)
                : const Color(0xFF6D1BE0).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check : Icons.copy,
              color: _copied ? Colors.green : const Color(0xFF6D1BE0),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _copied ? 'Copiado' : 'Copiar',
              style: GoogleFonts.poppins(
                color: _copied ? Colors.green : const Color(0xFF6D1BE0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
