import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import '../../services/api_service.dart';
import 'package:pakiip/screens/auth/login_screen.dart';
import 'package:pakiip/screens/common/home_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_panel_screen.dart';
import 'package:pakiip/screens/rider/rider_panel_screen.dart';
import 'package:pakiip/screens/admin/admin_coming_soon_screen.dart';
import 'package:pakiip/screens/common/maintenance_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    _checkSystemConfig();
  }

  Future<void> _checkForUpdate() async {
    try {
      if (Platform.isAndroid) {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint('Error en InAppUpdate: $e');
    }
  }

  bool _checking = true;
  bool _isMaintenance = false;
  String _maintenanceMsg = '';

  Future<void> _launchWhatsApp(String message) async {
    final url =
        "https://wa.me/51910318809?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Future<void> _checkSystemConfig() async {
    try {
      final config = await ApiService.get('/config/public');
      final role = await ApiService.getRole();
      if (config['maintenance_mode'] == true && role != 'admin') {
        // Solo bloquear si NO es admin
        setState(() {
          _isMaintenance = true;
          _maintenanceMsg =
              config['maintenance_message'] ?? 'Mantenimiento del sistema';
          _checking = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error checking config: $e');
    }

    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (isLoggedIn) {
      final role = await ApiService.getRole();
      final name = await ApiService.getName() ?? '';

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminComingSoonScreen(adminName: name),
          ),
        );
      } else if (role == 'restaurant') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantPanelScreen(restaurantName: name),
          ),
        );
      } else if (role == 'rider') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RiderPanelScreen(riderName: name)),
        );
      } else {
        // Cliente (home normal)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Imagen de fondo con overlay oscuro
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1617347454431-f49d7ff5c3b1?q=80&w=2030&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),

          // Contenido Principal
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo Superior
                Text(
                  'Pakiip',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const Spacer(flex: 2),

                // Texto Central
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        'Entregas rápidas a tu puerta',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tu comida favorita y las compras del super, todo en un solo lugar.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Botón Comenzar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _checking
                      ? const CircularProgressIndicator(color: Color(0xFFFA7516))
                      : Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFA7516).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_isMaintenance) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MaintenanceScreen(message: _maintenanceMsg),
                                  ),
                                );
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFA7516),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Comenzar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.arrow_forward_rounded, size: 24),
                              ],
                            ),
                          ),
                        ),
                ),

                const Spacer(flex: 1),

                // Opciones Inferiores (Cards oscuras)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildBottomCard(
                          label: 'Regístrate como repartidor',
                          icon: Icons.delivery_dining_rounded,
                          onTap: () => _launchWhatsApp('Hola, quiero ser repartidor en Pakiip'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBottomCard(
                          label: 'Registra tu restaurante',
                          icon: Icons.storefront_rounded,
                          onTap: () => _launchWhatsApp('Hola, quiero registrar mi restaurante en Pakiip'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Footer
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'AL CONTINUAR, ACEPTAS NUESTROS TÉRMINOS Y CONDICIONES',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFFA7516), size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}






