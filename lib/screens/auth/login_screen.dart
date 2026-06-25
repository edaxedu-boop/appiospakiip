import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../widgets/delivery_location_dialog.dart';
import 'package:pakiip/screens/admin/admin_coming_soon_screen.dart';
import 'package:pakiip/screens/auth/forgot_password_screen.dart';
import 'package:pakiip/screens/common/home_screen.dart';
import 'package:pakiip/screens/auth/register_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_panel_screen.dart';
import 'package:pakiip/screens/rider/rider_panel_screen.dart';
import 'package:pakiip/services/push_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const Color _red = Color(0xFFFA7516);
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _cardBg = Colors.white;
  static const Color _inputBg = Color(0xFFF7F7F7);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Por favor completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = await ApiService.login(email, password);
      final name = await ApiService.getName() ?? '';

      // Registrar token FCM al iniciar sesión
      PushNotificationService.registerFcmToken();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AdminComingSoonScreen(adminName: name),
          ),
          (route) => false,
        );
      } else if (role == 'restaurant') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantPanelScreen(restaurantName: name),
          ),
          (route) => false,
        );
      } else if (role == 'rider') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => RiderPanelScreen(riderName: name)),
          (route) => false,
        );
      } else {
        // Cliente → solo pedir dirección si aún no tiene una guardada
        try {
          final profile = await ApiService.get('/auth/clients/me');
          final savedAddress = (profile['delivery_address'] ?? '')
              .toString()
              .trim();
          if (!mounted) return;
          if (savedAddress.isEmpty) {
            // No tiene dirección → pedir una
            await DeliveryLocationDialog.show(
              context,
              LocationDialogMode.login,
            );
          }
          // Si ya tiene dirección → ir directo al home
        } catch (_) {
          // Si falla la consulta igual pedimos dirección
          if (mounted) {
            await DeliveryLocationDialog.show(
              context,
              LocationDialogMode.login,
            );
          }
        }
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'No se pudo conectar al servidor. Verifica tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Subtle Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDFDFD), _bg],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Logo outside card for elevation effect
                  Center(
                    child: Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/images/icono1.png',
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox(height: 90),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // The Main Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Bienvenido de nuevo',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Ingresa tus credenciales para continuar',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Email field ────────────────────────────────────────────
                        _buildField(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          hint: 'tu@correo.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // ── Password field ─────────────────────────────────────────
                        _buildField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),

                        // ── Error message ──────────────────────────────────────────
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _red.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: _red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(
                                      color: _red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── Forgot password ────────────────────────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: Text(
                              '¿Olvidaste tu contraseña?',
                              style: GoogleFonts.poppins(
                                color: _red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Login button ───────────────────────────────────────────
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _red.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _red,
                              disabledBackgroundColor: _red.withValues(
                                alpha: 0.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Ingresar',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Register button ────────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _red, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              'Registrarse',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword && _obscurePassword,
        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
        onChanged: (_) {
          if (_errorMessage != null) setState(() => _errorMessage = null);
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
          hintStyle: GoogleFonts.poppins(color: Colors.black12, fontSize: 13),
          prefixIcon: Icon(icon, color: _red, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.black26,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
