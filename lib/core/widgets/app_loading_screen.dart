import 'package:flutter/material.dart';

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen> with TickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late AnimationController _logoPulseCtrl;
  late Animation<double> _progress;
  late Animation<double> _logoScale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    
    // Animación de la barra: 2 segundos de carga fluida
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOutQuart),
    );

    // Animación de pulso del Logo
    _logoPulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _logoScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _logoPulseCtrl, curve: Curves.easeInOut),
    );

    // Fade in inicial para suavizar la salida del splash nativo
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );

    _progressCtrl.forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _logoPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final bool isDark = brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final Color accentColor = isDark ? Colors.white : Colors.black;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        backgroundColor: bgColor,
        body: FadeTransition(
          opacity: _fade,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centro: Logo + Barra debajo
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO dinámico
                    ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 40,
                              spreadRadius: isDark ? -10 : 0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: Image.asset(
                            'assets/icon.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    
                    // Texto Branding sutil
                    Text(
                      'Moneo Voice',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6.0,
                        color: accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // BARRA DE CARGA centrada y premium
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 70),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Fondo de la barra
                          Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          // Progreso animado
                          AnimatedBuilder(
                            animation: _progress,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                widthFactor: _progress.value,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Porcentaje sutil
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, child) => Text(
                        '${(_progress.value * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Pie de página con copyright o info sutil (estilo Apple)
              Positioned(
                bottom: 50,
                child: Text(
                  'Optimizando motor inteligente...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: accentColor.withValues(alpha: 0.15),
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
