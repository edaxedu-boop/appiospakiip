import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'restaurant_map_picker.dart';

class RiderRequestSheet extends StatefulWidget {
  final Map<String, dynamic> rawOrder;
  final Map<String, dynamic> restaurantData;
  final bool isDark;

  const RiderRequestSheet({
    super.key,
    required this.rawOrder,
    required this.restaurantData,
    this.isDark = true,
  });

  @override
  State<RiderRequestSheet> createState() => _RiderRequestSheetState();
}

class _RiderRequestSheetState extends State<RiderRequestSheet> {
  static const Color orange = Color(0xFFFA7516);
  
  late Color _sheetBg;
  late Color _cardBg;
  late Color _fieldBg;
  late Color _border;
  late Color _textPrimary;
  late Color _textSecondary;
  late Color _textHint;
  late Color _closeBtnBg;

  late final TextEditingController clientCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController chargeCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController pickupAddressCtrl;
  late final TextEditingController recipientNameCtrl;
  late final TextEditingController recipientPhoneCtrl;

  bool get isFavor => widget.restaurantData['id'] == '0' || widget.restaurantData['id'] == 0;

  bool submitting = false;
  double serviceFee = 2.0;
  double baseCost1Km = 4.00;
  double priceIntermediate = 1.00;
  double priceLong = 2.00;
  double deliveryCost = 0.0;
  bool isLoadingConfig = true;

  double? clientLat;
  double? clientLng;
  double? pickupLat;
  double? pickupLng;
  double distanceKm = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Configuración adaptativa de colores
    if (widget.isDark) {
      _sheetBg = const Color(0xFF120909);
      _cardBg = const Color(0xFF1C0F0F);
      _fieldBg = const Color(0xFF120909);
      _border = const Color(0xFF2A1515);
      _textPrimary = Colors.white;
      _textSecondary = Colors.white38;
      _textHint = Colors.white24;
      _closeBtnBg = const Color(0xFF2A1515);
    } else {
      _sheetBg = Colors.white;
      _cardBg = const Color(0xFFF9FAFB);
      _fieldBg = const Color(0xFFF3F4F6); // Gris suave para inputs
      _border = Colors.black.withValues(alpha: 0.05);
      _textPrimary = Colors.black87;
      _textSecondary = Colors.black54;
      _textHint = Colors.black26;
      _closeBtnBg = Colors.black.withValues(alpha: 0.05);
    }

    clientCtrl = TextEditingController();
    addressCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    
    final total = widget.rawOrder['total'] is num ? (widget.rawOrder['total'] as num).toDouble() : 0.0;
    chargeCtrl = TextEditingController(text: total > 0 ? total.toStringAsFixed(2) : '');
    notesCtrl = TextEditingController();
    pickupAddressCtrl = TextEditingController();
    recipientNameCtrl = TextEditingController();
    recipientPhoneCtrl = TextEditingController();

    if (isFavor) {
      pickupLat = double.tryParse(widget.restaurantData['lat']?.toString() ?? '');
      pickupLng = double.tryParse(widget.restaurantData['lng']?.toString() ?? '');
      pickupAddressCtrl.text = widget.restaurantData['name'] ?? '';
    }

    // Prellenar con ubicación actual del usuario/restaurante
    pickupLat = double.tryParse(widget.restaurantData['lat']?.toString() ?? '');
    pickupLng = double.tryParse(widget.restaurantData['lng']?.toString() ?? '');
    pickupAddressCtrl.text = widget.restaurantData['name'] ?? '';

    chargeCtrl.addListener(() => setState(() {}));

    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ApiService.get('/config/public');
      setState(() {
        serviceFee = double.tryParse(config['service_fee']?.toString() ?? '2.0') ?? 2.0;
        baseCost1Km = double.tryParse(config['base_cost_1km']?.toString() ?? '4.00') ?? 4.00;
        priceIntermediate = double.tryParse(config['price_per_km_intermediate']?.toString() ?? '1.00') ?? 1.00;
        priceLong = double.tryParse(config['price_per_km_long']?.toString() ?? '2.00') ?? 2.00;
        isLoadingConfig = false;
        _calculateDeliveryCost();
      });
    } catch (_) {
      setState(() => isLoadingConfig = false);
    }
  }

  void _calculateDeliveryCost() {
    if (clientLat == null || clientLng == null || pickupLat == null || pickupLng == null) {
      deliveryCost = 0.0;
      return;
    }
    
    final distanceMeters = Geolocator.distanceBetween(
      pickupLat!,
      pickupLng!,
      clientLat!,
      clientLng!,
    );
    
    distanceKm = distanceMeters / 1000.0;
    
    // Fórmula escalonada
    deliveryCost = baseCost1Km;
    if (distanceKm > 1.0 && distanceKm <= 3.0) {
      deliveryCost = baseCost1Km + ((distanceKm - 1.0) * priceIntermediate);
    } else if (distanceKm > 3.0) {
      deliveryCost = baseCost1Km + (2.0 * priceIntermediate) + ((distanceKm - 3.0) * priceLong);
    }
    
    deliveryCost = double.parse(deliveryCost.toStringAsFixed(2));
  }

  @override
  void dispose() {
    clientCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();
    chargeCtrl.dispose();
    notesCtrl.dispose();
    pickupAddressCtrl.dispose();
    recipientNameCtrl.dispose();
    recipientPhoneCtrl.dispose();
    super.dispose();
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required IconData icon,
    required Color iconColor,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: keyboard,
                readOnly: readOnly,
                enabled: !readOnly,
                style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  hintText: hint,
                  hintStyle: GoogleFonts.poppins(color: _textHint, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: _textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 10,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _costRow(String title, String cost, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12)),
        Text(cost, style: GoogleFonts.poppins(color: color ?? _textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Future<void> _pickPickupLocation() async {
    FocusScope.of(context).unfocus();
    final result = await RestaurantMapPicker.show(
      context,
      lat: pickupLat,
      lng: pickupLng,
      address: pickupAddressCtrl.text,
      isDark: widget.isDark,
    );
    if (result != null) {
      setState(() {
        pickupAddressCtrl.text = result['address'];
        pickupLat = result['lat'];
        pickupLng = result['lng'];
        _calculateDeliveryCost();
      });
    }
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final result = await RestaurantMapPicker.show(
      context,
      lat: clientLat,
      lng: clientLng,
      address: addressCtrl.text,
      isDark: widget.isDark,
    );
    if (result != null) {
      setState(() {
        addressCtrl.text = result['address'];
        clientLat = result['lat'];
        clientLng = result['lng'];
        _calculateDeliveryCost();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAmount = double.tryParse(chargeCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final totalCliente = productAmount + deliveryCost + serviceFee;

    return Container(
      decoration: BoxDecoration(
        color: _sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining_rounded, color: orange, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitar Repartidor',
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Llena los datos del envío',
                        style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _closeBtnBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: _textSecondary, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Nombre (Sender or Restaurant)
            _detailLabel(isFavor ? 'QUIEN ENVÍA (NOMBRE)' : 'NOMBRE DEL CLIENTE'),
            const SizedBox(height: 6),
            _buildField(
              ctrl: clientCtrl,
              icon: Icons.person_outline,
              iconColor: orange,
              hint: isFavor ? 'Tu nombre' : 'Ej. Juan Pérez',
            ),
            const SizedBox(height: 12),

            // Teléfono Sender (Only for Favor)
            if (isFavor) ...[
              _detailLabel('TELÉFONO DE QUIEN ENVÍA'),
              const SizedBox(height: 6),
              _buildField(
                ctrl: phoneCtrl,
                icon: Icons.phone_outlined,
                iconColor: const Color(0xFF4CAF50),
                hint: 'Tu número de teléfono',
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
            ],

            // Pickup Address (Only for Favor)
            if (isFavor) ...[
              _detailLabel('DIRECCIÓN DE RECOJO (Toque para mapa)'),
              const SizedBox(height: 6),
              _buildField(
                ctrl: pickupAddressCtrl,
                icon: Icons.store_outlined,
                iconColor: orange,
                hint: '¿Dónde recogemos el favor?',
                readOnly: true,
                onTap: _pickPickupLocation,
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Default pickup for standard orders (optional to show or just use restaurant location)
            ],

            // Delivery Address
            _detailLabel(isFavor ? 'DIRECCIÓN DE ENTREGA' : 'DIRECCIÓN DE ENTREGA (Toque para mapa)'),
            const SizedBox(height: 6),
            _buildField(
              ctrl: addressCtrl,
              icon: Icons.location_on_outlined,
              iconColor: orange,
              hint: isFavor ? '¿A dónde lo llevamos?' : 'Toca para buscar en el mapa...',
              readOnly: true,
              onTap: _pickLocation,
            ),
            const SizedBox(height: 12),

            // Recipient Info (Only for Favor)
            if (isFavor) ...[
              _detailLabel('QUIEN RECIBE (NOMBRE)'),
              const SizedBox(height: 6),
              _buildField(
                ctrl: recipientNameCtrl,
                icon: Icons.person_add_alt_1_outlined,
                iconColor: orange,
                hint: 'Nombre del destinatario',
              ),
              const SizedBox(height: 12),

              _detailLabel('TELÉFONO DE QUIEN RECIBE'),
              const SizedBox(height: 6),
              _buildField(
                ctrl: recipientPhoneCtrl,
                icon: Icons.phone_android_outlined,
                iconColor: const Color(0xFF4CAF50),
                hint: 'Número del destinatario',
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Standard phone for restaurant orders
              _detailLabel('NÚMERO DEL CLIENTE'),
              const SizedBox(height: 6),
              _buildField(
                ctrl: phoneCtrl,
                icon: Icons.phone_outlined,
                iconColor: const Color(0xFF4CAF50),
                hint: 'Ej. +51 987 654 321',
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),

            // Descripción/Notas
            _detailLabel('DESCRIPCIÓN / INDICACIONES (OPCIONAL)'),
            const SizedBox(height: 6),
            _buildField(
              ctrl: notesCtrl,
              icon: Icons.description_outlined,
              iconColor: Colors.blueGrey,
              hint: 'Ej. Traer cambio de 50, tocar timbre...',
            ),
            const SizedBox(height: 16),

            // Monto
            _detailLabel('MONTO A COBRAR POR EL PRODUCTO'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      'S/.',
                      style: GoogleFonts.poppins(
                        color: orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: chargeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        hintText: '0.00',
                        hintStyle: GoogleFonts.poppins(color: _textHint, fontSize: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Desglose
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (clientLat != null && clientLng != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Distancia: ${distanceKm.toStringAsFixed(1)} km',
                        style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
                      ),
                    ),
                  _costRow('Monto a cobrar por producto', 'S/. ${productAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  if (isLoadingConfig)
                    const Center(child: CircularProgressIndicator(color: orange))
                  else ...[
                    _costRow('Costo de delivery', 'S/. ${deliveryCost.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _costRow('Tarifa de servicio', 'S/. ${serviceFee.toStringAsFixed(2)}'),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: _border),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: orange.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total a cobrar al cliente\n(incl. delivery + tarifa)',
                            style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          'S/. ${totalCliente.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón Aceptar
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: submitting || isLoadingConfig
                    ? null
                    : () async {
                        if (clientCtrl.text.isEmpty ||
                            addressCtrl.text.isEmpty ||
                            chargeCtrl.text.isEmpty ||
                            clientLat == null || 
                            clientLng == null ||
                            (isFavor && (pickupLat == null || pickupLng == null))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Por favor completa todos los campos y ubica los puntos en el mapa'),
                            ),
                          );
                          return;
                        }

                        setState(() => submitting = true);
                        try {
                          await ApiService.postAuth('/orders', {
                            'restaurant_id': isFavor ? null : widget.restaurantData['id'],
                            'client_name': isFavor ? recipientNameCtrl.text.trim() : clientCtrl.text.trim(),
                            'client_address': addressCtrl.text.trim(),
                            'client_lat': clientLat,
                            'client_lng': clientLng,
                            'client_phone': isFavor ? recipientPhoneCtrl.text.trim() : phoneCtrl.text.trim(),
                            'total': totalCliente,
                            'delivery_fee': deliveryCost,
                            'service_fee': serviceFee,
                            'status': 'ready', // Immediately notify nearby riders
                            'pickup_address': isFavor ? pickupAddressCtrl.text.trim() : null,
                            'pickup_lat': pickupLat,
                            'pickup_lng': pickupLng,
                            'recipient_name': isFavor ? recipientNameCtrl.text.trim() : null,
                            'recipient_phone': isFavor ? recipientPhoneCtrl.text.trim() : null,
                            'sender_name': isFavor ? clientCtrl.text.trim() : null,
                            'sender_phone': isFavor ? phoneCtrl.text.trim() : null,
                            'items': [
                              {
                                'name': isFavor ? 'Pakiip Favor' : 'Pedido Manual',
                                'qty': 1,
                                'price': productAmount,
                              },
                            ],
                            'payment_method': 'cash',
                            'notes': notesCtrl.text.trim().isEmpty 
                                ? (isFavor ? 'Favor personalizado' : 'Pedido desde panel') 
                                : notesCtrl.text.trim(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Repartidor solicitado con éxito!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => submitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                icon: submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  submitting ? 'Enviando...' : 'Confirmar Solicitud',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}






