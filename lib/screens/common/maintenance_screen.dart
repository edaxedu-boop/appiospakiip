import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  const MaintenanceScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    const Color red = Color(0xFFFA7516);
    const Color bg = Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono animado o estático de mantenimiento
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build_rounded,
                  color: red,
                  size: 60,
                ),
              ),
              const SizedBox(height: 48),

              Text(
                'Mantenimiento',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                message.isNotEmpty
                    ? message
                    : 'Estamos realizando mejoras en el sistema para brindarte una mejor experiencia. Volveremos muy pronto.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 60),

              // Badge de marca
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/icono1.png',
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shopping_bag,
                      color: red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pakiip PERÚ',
                    style: GoogleFonts.poppins(
                      color: Colors.black26,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}






