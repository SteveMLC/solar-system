import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:solar_system/models/config_options.dart';
import 'package:solar_system/models/planet.dart';
import 'package:solar_system/res/assets/textures.dart';
import 'package:solar_system/res/extensions/planet_extension.dart';
import 'package:solar_system/utils/planet_util.dart';

import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;

class HomeScene extends StatefulWidget {
  const HomeScene({super.key});

  @override
  State<HomeScene> createState() => _HomeSceneState();
}

class _HomeSceneState extends State<HomeScene> {
  /// Keys
  late final GlobalKey<three_jsm.DomLikeListenableState> _domLikeKey;

  /// three
  three.WebGLRenderer? renderer;
  three.WebGLRenderTarget? renderTarget;

  /// GL
  late FlutterGlPlugin three3dRender;

  /// config
  late double width;
  late double height;
  late three.Scene _scene;
  late three.Camera _camera;
  late three_jsm.OrbitControls _orbitControls;
  Size? screenSize;
  double dpr = 1;
  late int sourceTexture;

  /// planets
  late three.Mesh _sun;
  late Planet _planet;
  
  /// speed control
  double _currentSpeed = 1.0;
  
  /// camera focus system
  CelestialBodyType _currentFocus = CelestialBodyType.sun;
  bool _showPlanetSelector = false;

  @override
  void initState() {
    super.initState();
    _domLikeKey = GlobalKey();
    _planet = const Planet();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        return _handleKeyPress(event);
      },
      child: three_jsm.DomLikeListenable(
        key: _domLikeKey,
        builder: (context) {
        _initSize();
        return Scaffold(
          body: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: width,
                    height: height,
                    color: Colors.black,
                    child: Builder(
                      builder: (BuildContext context) {
                        if (three3dRender.isInitialized) {
                          if (kIsWeb) {
                            return HtmlElementView(
                              viewType: three3dRender.textureId!.toString(),
                            );
                          }
                          return Texture(
                            textureId: three3dRender.textureId!,
                          );
                        }
                        return Container();
                      },
                    ),
                  ),
                  // Keyboard shortcuts help
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        'Press 0-9 to focus • ESC to stop following',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  // Planet Selector Button
                  Positioned(
                    top: 50,
                    right: 20,
                    left: MediaQuery.of(context).size.width > 800 ? null : 20, // Full width on small screens
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Main Focus Button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showPlanetSelector = !_showPlanetSelector;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Focus: ${_getFocusName(_currentFocus)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (PlanetUtil.instance.isFollowingPlanet) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Following',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(width: 8),
                                if (PlanetUtil.instance.isFollowingPlanet) ...[
                                  GestureDetector(
                                    onTap: () {
                                      PlanetUtil.instance.stopFollowing();
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.red),
                                      ),
                                      child: const Text(
                                        'Stop',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Icon(
                                  _showPlanetSelector ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Planet Selection Dropdown
                        if (_showPlanetSelector) ...[
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width > 800 ? 250 : MediaQuery.of(context).size.width - 40,
                              maxHeight: MediaQuery.of(context).size.height * 0.6, // Responsive height
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Mission Targets Section (Fixed Header)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.flag, color: Colors.blue, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'Mission Locations',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Scrollable Content
                                  Flexible(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Mission targets
                                          ...PlanetUtil.instance.getMissionTargets().map((target) => 
                                            _buildPlanetButton(target)
                                          ),
                                          const Divider(color: Colors.white24, height: 1),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 8),
                                            child: Text(
                                              'All Celestial Bodies',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          // Other planets
                                          ...PlanetUtil.instance.getAllTargets()
                                            .where((target) => !PlanetUtil.instance.getMissionTargets().contains(target))
                                            .map((target) => _buildPlanetButton(target)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Speed Control Slider
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Animation Speed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${_currentSpeed.toStringAsFixed(1)}x',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                '0x',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _currentSpeed,
                                  min: 0.0,
                                  max: 5.0,
                                  divisions: 50,
                                  activeColor: Colors.blue,
                                  inactiveColor: Colors.white24,
                                  onChanged: (value) {
                                    setState(() {
                                      _currentSpeed = value;
                                      PlanetUtil.instance.setSpeed(value);
                                    });
                                  },
                                ),
                              ),
                              const Text(
                                '5x',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSpeedButton('Pause', 0.0),
                              _buildSpeedButton('0.5x', 0.5),
                              _buildSpeedButton('1x', 1.0),
                              _buildSpeedButton('2x', 2.0),
                              _buildSpeedButton('5x', 5.0),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ));
  }

  KeyEventResult _handleKeyPress(KeyEvent event) {
    // Quick planet switching with number keys
    switch (event.logicalKey.keyLabel) {
      case '0':
        setState(() => _currentFocus = CelestialBodyType.sun);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.sun);
        return KeyEventResult.handled;
      case '1':
        setState(() => _currentFocus = CelestialBodyType.mercury);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.mercury);
        return KeyEventResult.handled;
      case '2':
        setState(() => _currentFocus = CelestialBodyType.venus);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.venus);
        return KeyEventResult.handled;
      case '3':
        setState(() => _currentFocus = CelestialBodyType.earth);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.earth);
        return KeyEventResult.handled;
      case '4':
        setState(() => _currentFocus = CelestialBodyType.mars);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.mars);
        return KeyEventResult.handled;
      case '5':
        setState(() => _currentFocus = CelestialBodyType.jupiter);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.jupiter);
        return KeyEventResult.handled;
      case '6':
        setState(() => _currentFocus = CelestialBodyType.saturn);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.saturn);
        return KeyEventResult.handled;
      case '7':
        setState(() => _currentFocus = CelestialBodyType.uranus);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.uranus);
        return KeyEventResult.handled;
      case '8':
        setState(() => _currentFocus = CelestialBodyType.neptune);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.neptune);
        return KeyEventResult.handled;
      case '9':
        setState(() => _currentFocus = CelestialBodyType.pluto);
        PlanetUtil.instance.focusOnCelestialBody(CelestialBodyType.pluto);
        return KeyEventResult.handled;
      default:
        // Check for Escape key to stop following
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (PlanetUtil.instance.isFollowingPlanet) {
            PlanetUtil.instance.stopFollowing();
            setState(() {});
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
    }
  }

  Widget _buildSpeedButton(String label, double speed) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentSpeed = speed;
          PlanetUtil.instance.setSpeed(speed);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _currentSpeed == speed 
              ? Colors.blue.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _currentSpeed == speed 
                ? Colors.blue
                : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _currentSpeed == speed 
                ? Colors.blue
                : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanetButton(CameraFocusTarget target) {
    final isSelected = _currentFocus == target.type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFocus = target.type;
          _showPlanetSelector = false;
        });
        PlanetUtil.instance.focusOnCelestialBody(target.type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.blue.withOpacity(0.3)
              : Colors.transparent,
          border: isSelected 
              ? Border.all(color: Colors.blue)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _getPlanetIcon(target.type),
              color: isSelected ? Colors.blue : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                target.name,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected) ...[
              const Icon(
                Icons.check,
                color: Colors.blue,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFocusName(CelestialBodyType type) {
    switch (type) {
      case CelestialBodyType.sun:
        return 'Sun';
      case CelestialBodyType.mercury:
        return 'Mercury';
      case CelestialBodyType.venus:
        return 'Venus';
      case CelestialBodyType.earth:
        return 'Earth';
      case CelestialBodyType.mars:
        return 'Mars';
      case CelestialBodyType.jupiter:
        return 'Jupiter';
      case CelestialBodyType.saturn:
        return 'Saturn';
      case CelestialBodyType.uranus:
        return 'Uranus';
      case CelestialBodyType.neptune:
        return 'Neptune';
      case CelestialBodyType.pluto:
        return 'Pluto';
    }
  }

  IconData _getPlanetIcon(CelestialBodyType type) {
    switch (type) {
      case CelestialBodyType.sun:
        return Icons.wb_sunny;
      case CelestialBodyType.mercury:
        return Icons.circle;
      case CelestialBodyType.venus:
        return Icons.brightness_3;
      case CelestialBodyType.earth:
        return Icons.public;
      case CelestialBodyType.mars:
        return Icons.landscape;
      case CelestialBodyType.jupiter:
        return Icons.blur_circular;
      case CelestialBodyType.saturn:
        return Icons.radio_button_unchecked;
      case CelestialBodyType.uranus:
        return Icons.trip_origin;
      case CelestialBodyType.neptune:
        return Icons.water_drop;
      case CelestialBodyType.pluto:
        return Icons.fiber_manual_record;
    }
  }

  void _initSize() {
    if (screenSize != null) {
      return;
    }

    final mediaQuery = MediaQuery.of(context);

    screenSize = mediaQuery.size;
    dpr = mediaQuery.devicePixelRatio;

    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    width = screenSize!.width;
    height = screenSize!.height;

    three3dRender = FlutterGlPlugin();

    final options = ConfigOptions(
      antialias: true,
      alpha: true,
      width: width.toInt(),
      height: height.toInt(),
      dpr: dpr,
    );

    await three3dRender.initialize(options: options.toMap());

    setState(() {});

    Future.delayed(const Duration(milliseconds: 100), () async {
      await three3dRender.prepareContext();

      await _initScene();
    });
  }

  Future<void> _initScene() async {
    await _initRenderer();
    _scene = three.Scene();
    _camera = three.PerspectiveCamera(45, width / height, 0.1, 1000);
    _orbitControls = three_jsm.OrbitControls(_camera, _domLikeKey);

    _camera.position.set(190, 140, 140);
    _orbitControls.update();
    
    // Initialize camera focus system
    PlanetUtil.instance.setCameraReference(_camera);
    PlanetUtil.instance.setOrbitControlsReference(_orbitControls);
    PlanetUtil.instance.initializeFocusTargets();
    PlanetUtil.instance.setOnFocusChanged((newFocus) {
      setState(() {
        _currentFocus = newFocus;
      });
    });

    ///
    final ambientLight = three.AmbientLight(0x333333);
    _scene.add(ambientLight);

    ///
    final backgroundTextureLoader = three.TextureLoader(null);
    final backgroundTexture = await backgroundTextureLoader.loadAsync(
      textureStars,
    );

    ///
    final sunGeo = three.SphereGeometry(16, 30, 30);
    final sunTextureLoader = three.TextureLoader(null);
    final sunMat = three.MeshBasicMaterial({
      'map': await sunTextureLoader.loadAsync(
        textureSun,
      ),
    });
    _sun = three.Mesh(sunGeo, sunMat);
    _scene.add(_sun);

    _planet = await _planet.initializePlanets(_scene);
    
    // Set references for camera focus system
    PlanetUtil.instance.setSunReference(_sun);
    PlanetUtil.instance.setPlanetReference(_planet);

    final pointLight = three.PointLight(0xFFFFFFFF, 2, 300);
    _scene
      ..add(pointLight)
      ..background = backgroundTexture;

    ///
    await _planet.animate(
      sun: _sun,
      planet: _planet,
      render: () {
        renderer!.render(_scene, _camera);
      },
    );
  }

  Future<void> _initRenderer() async {
    final options = ConfigOptions(
      antialias: true,
      alpha: true,
      width: width,
      height: height,
      gl: three3dRender.gl,
    );

    renderer = three.WebGLRenderer(
      options.toMap(),
    );
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height);
    renderer!.shadowMap.enabled = true;

    if (!kIsWeb) {
      final pars = three.WebGLRenderTargetOptions({'format': three.RGBAFormat});
      renderTarget = three.WebGLRenderTarget(
        (width * dpr).toInt(),
        (height * dpr).toInt(),
        pars,
      );
      renderTarget!.samples = 4;
      renderer!.setRenderTarget(renderTarget);
      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget!);
    } else {
      renderTarget = null;
    }
  }
}
