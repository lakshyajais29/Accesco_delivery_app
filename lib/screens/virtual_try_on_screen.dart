import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isPermissionDenied = false;

  // Scanning state
  bool _isScanning = false;
  bool _isScanComplete = false;
  
  late final AnimationController _scanAnimCtrl;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimCtrl, curve: Curves.easeInOut),
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first);

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('Error initializing camera: $e');
        if (mounted) setState(() => _isPermissionDenied = true);
      }
    } else {
      if (mounted) {
        setState(() {
          _isPermissionDenied = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanAnimCtrl.dispose();
    super.dispose();
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
    });
    _scanAnimCtrl.repeat(reverse: true);

    // Simulate body mapping
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      _scanAnimCtrl.stop();
      setState(() {
        _isScanning = false;
        _isScanComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Feed
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else if (_isPermissionDenied)
            const Center(
              child: Text(
                'Camera permission denied.\nPlease enable it in settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFC8A97E)),
            ),

          // 2. Cinematic Vignette Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),

          // 3. Scanning Animation Overlay
          if (_isScanning)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                final topOffset =
                    (_scanAnimation.value + 1) / 2 * MediaQuery.of(context).size.height;
                return Positioned(
                  top: topOffset,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC8A97E).withOpacity(0.8),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                      color: const Color(0xFFC8A97E),
                    ),
                  ),
                );
              },
            ),
            
          if (_isScanning)
            Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    const Icon(Icons.document_scanner_outlined, color: Color(0xFFC8A97E), size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Processing Body Map...',
                      style: GoogleFonts.jost(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                 ]
               )
            ),

          // 4. Try-On Overlay (Scanned Image Placeholder)
          if (_isScanComplete)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              bottom: MediaQuery.of(context).size.height * 0.35,
              left: MediaQuery.of(context).size.width * 0.1,
              right: MediaQuery.of(context).size.width * 0.1,
              child: Image.network(
                'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=600&q=80',
                fit: BoxFit.contain,
              ),
            ),

          // 5. Top Bar (Close button)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black.withOpacity(0.3),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),

          // 6. Bottom Control Panel (Glassmorphism)
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isScanComplete
                            ? 'VIRTUAL FIT COMPLETE'
                            : 'AI BODY MAPPING',
                        style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 24,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isScanComplete
                            ? 'The leather jacket fits perfectly.'
                            : 'Stand in frame to analyze your measurements.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jost(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: (_isScanning || _isScanComplete) ? () {
                            if (_isScanComplete) Navigator.pop(context);
                        } : _startScan,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B7536), Color(0xFFC8A97E)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _isScanComplete
                                  ? 'ADD TO TRIAL PACK'
                                  : (_isScanning ? 'SCANNING...' : 'START SCAN'),
                              style: GoogleFonts.bebasNeue(
                                color: Colors.white,
                                fontSize: 20,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
