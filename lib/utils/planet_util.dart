import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:solar_system/models/base_mesh.dart';
import 'package:solar_system/models/planet.dart';
import 'package:solar_system/params/create_planet_params.dart';
import 'package:solar_system/params/planet_ring_params.dart';
import 'package:solar_system/res/assets/textures.dart';
import 'package:three_dart/three_dart.dart' as three;

const int _sphereSegments = 30;
const int _ringSegments = 32;
const double _ringRotation = -0.5 * math.pi;

// Mobile performance optimization
enum PerformanceMode { high, medium, low, ultraLow }

class MobileOptimization {
  static const Map<PerformanceMode, Map<String, dynamic>> settings = {
    PerformanceMode.high: {
      'targetFPS': 60,
      'segments': 30,
      'lodDistances': [50, 150, 300],
      'textureQuality': 'high',
      'shadowsEnabled': true,
    },
    PerformanceMode.medium: {
      'targetFPS': 30,
      'segments': 20,
      'lodDistances': [40, 120, 250],
      'textureQuality': 'medium',
      'shadowsEnabled': false,
    },
    PerformanceMode.low: {
      'targetFPS': 24,
      'segments': 15,
      'lodDistances': [30, 100, 200],
      'textureQuality': 'low',
      'shadowsEnabled': false,
    },
    PerformanceMode.ultraLow: {
      'targetFPS': 15,
      'segments': 10,
      'lodDistances': [25, 75, 150],
      'textureQuality': 'low',
      'shadowsEnabled': false,
    },
  };
}

enum CelestialBodyType {
  sun,
  mercury,
  venus,
  earth,
  mars,
  jupiter,
  saturn,
  uranus,
  neptune,
  pluto,
}

class CameraFocusTarget {
  final CelestialBodyType type;
  final String name;
  final three.Vector3 position;
  final double? orbitRadius;
  
  CameraFocusTarget({
    required this.type,
    required this.name,
    required this.position,
    this.orbitRadius,
  });
}

class PlanetUtil {
  factory PlanetUtil() {
    return _instance;
  }
  PlanetUtil._();

  static final PlanetUtil _instance = PlanetUtil._();
  static PlanetUtil get instance => _instance;
  
  // Speed control
  double _speedMultiplier = 1.0;
  
  double get speedMultiplier => _speedMultiplier;
  set speedMultiplier(double value) => _speedMultiplier = value;
  
  void pauseAnimation() => _speedMultiplier = 0.0;
  void resumeAnimation() => _speedMultiplier = 1.0;
  void setSpeed(double speed) => _speedMultiplier = speed;

  // Camera focus system
  CelestialBodyType _currentFocus = CelestialBodyType.sun;
  three.Camera? _camera;
  three.Mesh? _sun;
  Planet? _currentPlanets;
  Map<CelestialBodyType, CameraFocusTarget> _focusTargets = {};
  Function(CelestialBodyType)? _onFocusChanged;
  bool _isFollowingPlanet = false;
  three.Vector3? _cameraOffset;
  dynamic _orbitControls;
  
  CelestialBodyType get currentFocus => _currentFocus;
  bool get isFollowingPlanet => _isFollowingPlanet;
  
  void setCameraReference(three.Camera camera) {
    _camera = camera;
  }
  
  void setOrbitControlsReference(dynamic orbitControls) {
    _orbitControls = orbitControls;
  }
  
  void setSunReference(three.Mesh sun) {
    _sun = sun;
  }
  
  void setPlanetReference(Planet planets) {
    _currentPlanets = planets;
  }
  
  void setOnFocusChanged(Function(CelestialBodyType) callback) {
    _onFocusChanged = callback;
  }
  
  void initializeFocusTargets() {
    _focusTargets = {
      CelestialBodyType.sun: CameraFocusTarget(
        type: CelestialBodyType.sun,
        name: 'Sun',
        position: three.Vector3(0, 0, 0),
        orbitRadius: 50,
      ),
      CelestialBodyType.mercury: CameraFocusTarget(
        type: CelestialBodyType.mercury,
        name: 'Mercury',
        position: three.Vector3(28, 0, 0),
        orbitRadius: 20,
      ),
      CelestialBodyType.venus: CameraFocusTarget(
        type: CelestialBodyType.venus,
        name: 'Venus',
        position: three.Vector3(44, 0, 0),
        orbitRadius: 25,
      ),
      CelestialBodyType.earth: CameraFocusTarget(
        type: CelestialBodyType.earth,
        name: 'Earth',
        position: three.Vector3(62, 0, 0),
        orbitRadius: 30,
      ),
      CelestialBodyType.mars: CameraFocusTarget(
        type: CelestialBodyType.mars,
        name: 'Mars',
        position: three.Vector3(78, 0, 0),
        orbitRadius: 25,
      ),
      CelestialBodyType.jupiter: CameraFocusTarget(
        type: CelestialBodyType.jupiter,
        name: 'Jupiter',
        position: three.Vector3(100, 0, 0),
        orbitRadius: 40,
      ),
      CelestialBodyType.saturn: CameraFocusTarget(
        type: CelestialBodyType.saturn,
        name: 'Saturn',
        position: three.Vector3(138, 0, 0),
        orbitRadius: 50,
      ),
      CelestialBodyType.uranus: CameraFocusTarget(
        type: CelestialBodyType.uranus,
        name: 'Uranus',
        position: three.Vector3(176, 0, 0),
        orbitRadius: 35,
      ),
      CelestialBodyType.neptune: CameraFocusTarget(
        type: CelestialBodyType.neptune,
        name: 'Neptune',
        position: three.Vector3(200, 0, 0),
        orbitRadius: 35,
      ),
      CelestialBodyType.pluto: CameraFocusTarget(
        type: CelestialBodyType.pluto,
        name: 'Pluto',
        position: three.Vector3(216, 0, 0),
        orbitRadius: 20,
      ),
    };
  }
  
  void focusOnCelestialBody(CelestialBodyType bodyType) {
    if (_camera == null || !_focusTargets.containsKey(bodyType)) return;
    
    _currentFocus = bodyType;
    final target = _focusTargets[bodyType]!;
    
    if (bodyType == CelestialBodyType.sun) {
      // Special case for Sun - don't follow, just position camera
      _isFollowingPlanet = false;
      _cameraOffset = null;
      
      // Re-enable orbit controls for free camera movement around sun
      _enableOrbitControls();
      
      final sunPosition = _getCurrentPlanetPosition(bodyType);
      final cameraDistance = target.orbitRadius ?? 50;
      final cameraPosition = three.Vector3(
        sunPosition.x + cameraDistance * 0.8,
        cameraDistance * 0.6,
        sunPosition.z + cameraDistance * 0.8,
      );
      
      _animateCameraToPosition(cameraPosition, sunPosition);
    } else {
      // Enable planet following mode for all planets
      _isFollowingPlanet = true;
      
      // Disable orbit controls to prevent interference with planet following
      _disableOrbitControls();
      
      // Calculate initial camera offset relative to planet
      final planetPosition = _getCurrentPlanetPosition(bodyType);
      final cameraDistance = target.orbitRadius ?? 50;
      
      // Set camera offset relative to planet (this will be maintained during orbit)
      _cameraOffset = three.Vector3(
        cameraDistance * 0.8,
        cameraDistance * 0.6,
        cameraDistance * 0.8,
      );
      
      // Initial camera positioning
      _updateCameraForFollowing();
    }
    
    _onFocusChanged?.call(bodyType);
  }
  
  void _enableOrbitControls() {
    if (_orbitControls != null) {
      _orbitControls.enabled = true;
    }
  }
  
  void _disableOrbitControls() {
    if (_orbitControls != null) {
      _orbitControls.enabled = false;
    }
  }
  
  void _updateCameraForFollowing() {
    if (!_isFollowingPlanet || _camera == null || _cameraOffset == null) return;
    
    final planetPosition = _getCurrentPlanetPosition(_currentFocus);
    
    // Position camera relative to planet with the offset
    final cameraPosition = three.Vector3(
      planetPosition.x + _cameraOffset!.x,
      planetPosition.y + _cameraOffset!.y,
      planetPosition.z + _cameraOffset!.z,
    );
    
    // Smoothly update camera position
    _camera!.position.lerp(cameraPosition, 0.1);
    _camera!.lookAt(planetPosition);
  }
  
  void stopFollowing() {
    _isFollowingPlanet = false;
    _cameraOffset = null;
    _enableOrbitControls();
  }
  
  three.Vector3 _getCurrentPlanetPosition(CelestialBodyType bodyType) {
    if (bodyType == CelestialBodyType.sun && _sun != null) {
      return _sun!.position;
    }
    
    if (_currentPlanets == null) {
      return _focusTargets[bodyType]?.position ?? three.Vector3(0, 0, 0);
    }
    
    // Get actual current position from the planet
    switch (bodyType) {
      case CelestialBodyType.mercury:
        return _currentPlanets!.mecury?.currentWorldPosition ?? three.Vector3(28, 0, 0);
      case CelestialBodyType.venus:
        return _currentPlanets!.venus?.currentWorldPosition ?? three.Vector3(44, 0, 0);
      case CelestialBodyType.earth:
        return _currentPlanets!.earth?.currentWorldPosition ?? three.Vector3(62, 0, 0);
      case CelestialBodyType.mars:
        return _currentPlanets!.mars?.currentWorldPosition ?? three.Vector3(78, 0, 0);
      case CelestialBodyType.jupiter:
        return _currentPlanets!.jupiter?.currentWorldPosition ?? three.Vector3(100, 0, 0);
      case CelestialBodyType.saturn:
        return _currentPlanets!.saturn?.currentWorldPosition ?? three.Vector3(138, 0, 0);
      case CelestialBodyType.uranus:
        return _currentPlanets!.uranus?.currentWorldPosition ?? three.Vector3(176, 0, 0);
      case CelestialBodyType.neptune:
        return _currentPlanets!.neptune?.currentWorldPosition ?? three.Vector3(200, 0, 0);
      case CelestialBodyType.pluto:
        return _currentPlanets!.pluto?.currentWorldPosition ?? three.Vector3(216, 0, 0);
      case CelestialBodyType.sun:
        return three.Vector3(0, 0, 0);
    }
  }
  
  void _animateCameraToPosition(three.Vector3 newPosition, three.Vector3 lookAtTarget) {
    if (_camera == null) return;
    
    // Smooth camera animation using lerp
    _animateCamera(newPosition, lookAtTarget);
  }
  
  void _animateCamera(three.Vector3 targetPosition, three.Vector3 lookAtTarget) {
    if (_camera == null) return;
    
    final currentPosition = _camera!.position.clone();
    final distance = currentPosition.distanceTo(targetPosition);
    
    // If we're close enough, just snap to position
    if (distance < 1.0) {
      _camera!.position.copy(targetPosition);
      _camera!.lookAt(lookAtTarget);
      return;
    }
    
    // Smooth interpolation
    final lerpFactor = math.min(0.05, 1.0 / distance * 2.0);
    _camera!.position.lerp(targetPosition, lerpFactor);
    _camera!.lookAt(lookAtTarget);
    
    // Continue animation until we reach the target
    Future.delayed(const Duration(milliseconds: 16), () {
      _animateCamera(targetPosition, lookAtTarget);
    });
  }
  
  List<CameraFocusTarget> getMissionTargets() {
    // Return the main mission locations
    return [
      _focusTargets[CelestialBodyType.sun]!,
      _focusTargets[CelestialBodyType.earth]!,
      _focusTargets[CelestialBodyType.mars]!,
      _focusTargets[CelestialBodyType.jupiter]!,
    ];
  }
  
  List<CameraFocusTarget> getAllTargets() {
    return _focusTargets.values.toList();
  }

  // Mobile optimization properties
  PerformanceMode _performanceMode = PerformanceMode.medium;
  three.Camera? _currentCamera;
  DateTime _lastFrameTime = DateTime.now();
  List<double> _frameTimeHistory = [];
  bool _adaptivePerformance = true;

  // Getters for mobile optimization
  PerformanceMode get performanceMode => _performanceMode;
  bool get adaptivePerformanceEnabled => _adaptivePerformance;
  
  // Mobile optimization methods
  void setPerformanceMode(PerformanceMode mode) {
    _performanceMode = mode;
  }
  
  void enableAdaptivePerformance(bool enabled) {
    _adaptivePerformance = enabled;
  }
  
  // Calculate appropriate LOD based on distance from camera
  int _calculateLOD(three.Vector3 planetPosition, three.Camera camera) {
    final distance = camera.position.distanceTo(planetPosition);
    final settings = MobileOptimization.settings[_performanceMode]!;
    final lodDistances = settings['lodDistances'] as List<int>;
    
    if (distance < lodDistances[0]) return 0; // High detail
    if (distance < lodDistances[1]) return 1; // Medium detail
    if (distance < lodDistances[2]) return 2; // Low detail
    return 3; // Ultra low detail (very far)
  }
  
  // Adaptive frame rate management
  void _updatePerformanceMetrics() {
    if (!_adaptivePerformance) return;
    
    final now = DateTime.now();
    final frameTime = now.difference(_lastFrameTime).inMicroseconds / 1000.0;
    _lastFrameTime = now;
    
    _frameTimeHistory.add(frameTime);
    if (_frameTimeHistory.length > 60) _frameTimeHistory.removeAt(0);
    
    if (_frameTimeHistory.length >= 30) {
      final avgFrameTime = _frameTimeHistory.reduce((a, b) => a + b) / _frameTimeHistory.length;
      final currentFPS = 1000.0 / avgFrameTime;
      final targetFPS = MobileOptimization.settings[_performanceMode]!['targetFPS'] as int;
      
      // Auto-adjust performance mode if needed
      if (currentFPS < targetFPS * 0.8) {
        _autoReducePerformance();
      } else if (currentFPS > targetFPS * 1.2 && _performanceMode != PerformanceMode.high) {
        _autoIncreasePerformance();
      }
    }
  }
  
  void _autoReducePerformance() {
    switch (_performanceMode) {
      case PerformanceMode.high:
        _performanceMode = PerformanceMode.medium;
        break;
      case PerformanceMode.medium:
        _performanceMode = PerformanceMode.low;
        break;
      case PerformanceMode.low:
        _performanceMode = PerformanceMode.ultraLow;
        break;
      case PerformanceMode.ultraLow:
        break; // Can't go lower
    }
  }
  
  void _autoIncreasePerformance() {
    switch (_performanceMode) {
      case PerformanceMode.ultraLow:
        _performanceMode = PerformanceMode.low;
        break;
      case PerformanceMode.low:
        _performanceMode = PerformanceMode.medium;
        break;
      case PerformanceMode.medium:
        _performanceMode = PerformanceMode.high;
        break;
      case PerformanceMode.high:
        break; // Already at highest
    }
  }

  Future<Planet> initializePlanet(three.Scene scene) async {
    return Planet(
      mecury: await _createPlanet(
        CreatePlanetParams(
          size: 3.2,
          texture: textureMecury,
          position: 28,
        ),
        scene,
      ),
      venus: await _createPlanet(
        CreatePlanetParams(
          size: 5.8,
          texture: textureVenus,
          position: 44,
        ),
        scene,
      ),
      saturn: await _createPlanet(
        CreatePlanetParams(
          size: 10,
          texture: textureSaturn,
          position: 138,
          planetRingParams: const PlanetRingParams(
            innerRadius: 10,
            outerRadius: 20,
            texture: textureSaturnRing,
          ),
        ),
        scene,
      ),
      earth: await _createPlanet(
        CreatePlanetParams(
          size: 6,
          texture: textureEarth,
          position: 62,
        ),
        scene,
      ),
      jupiter: await _createPlanet(
        CreatePlanetParams(
          size: 12,
          texture: textureJupiter,
          position: 100,
        ),
        scene,
      ),
      mars: await _createPlanet(
        CreatePlanetParams(
          size: 4,
          texture: textureMars,
          position: 78,
        ),
        scene,
      ),
      uranus: await _createPlanet(
        CreatePlanetParams(
          size: 7,
          texture: textureUranus,
          position: 176,
          planetRingParams: const PlanetRingParams(
            innerRadius: 7,
            outerRadius: 12,
            texture: textureUranus,
          ),
        ),
        scene,
      ),
      neptune: await _createPlanet(
        CreatePlanetParams(
          size: 7,
          texture: textureNeptune,
          position: 200,
        ),
        scene,
      ),
      pluto: await _createPlanet(
        CreatePlanetParams(
          size: 2.8,
          texture: texturePluto,
          position: 216,
        ),
        scene,
      ),
    );
  }

  Future<BaseMesh> _createPlanet(
    CreatePlanetParams createPlanetParams,
    three.Scene scene,
  ) async {
    final geo = three.SphereGeometry(
      createPlanetParams.size,
      _sphereSegments,
      _sphereSegments,
    );
    final mecuryTextureLoader = three.TextureLoader(null);
    final mat = three.MeshStandardMaterial({
      'map': await mecuryTextureLoader.loadAsync(
        createPlanetParams.texture,
      ),
    });
    final mesh = three.Mesh(geo, mat);
    final object3d = three.Object3D()..add(mesh);
    if (createPlanetParams.planetRingParams != null) {
      final ring = createPlanetParams.planetRingParams;
      final ringGeo = three.RingGeometry(
        ring!.innerRadius,
        ring.outerRadius,
        _ringSegments,
      );
      final ringTextureLoader = three.TextureLoader(null);
      final ringMat = three.MeshBasicMaterial({
        'map': await ringTextureLoader.loadAsync(
          ring.texture,
        ),
        'side': three.DoubleSide,
      });
      final ringMesh = three.Mesh(ringGeo, ringMat);
      object3d.add(ringMesh);
      ringMesh.position.x = createPlanetParams.position;
      ringMesh.rotation.x = _ringRotation;
    }
    scene.add(object3d);
    mesh.position.x = createPlanetParams.position;
    return BaseMesh(
      mesh: mesh,
      object3d: object3d,
    );
  }

  Future<void> animate({
    required Planet planet,
    required three.Mesh sun,
    required VoidCallback render,
  }) async {
    // Update performance metrics for mobile optimization
    _updatePerformanceMetrics();
    
    // Calculate frame delay based on performance mode
    final settings = MobileOptimization.settings[_performanceMode]!;
    final targetFPS = settings['targetFPS'] as int;
    final frameDelay = (1000 / targetFPS).round();
    
    // Apply speed multiplier to all rotations
    sun.rotateY(0.004 * _speedMultiplier);
    planet.mecury?.rotateMesh(0.004 * _speedMultiplier);
    planet.venus?.rotateMesh(0.002 * _speedMultiplier);
    planet.earth?.rotateMesh(0.02 * _speedMultiplier);
    planet.mars?.rotateMesh(0.018 * _speedMultiplier);
    planet.jupiter?.rotateMesh(0.04 * _speedMultiplier);
    planet.saturn?.rotateMesh(0.038 * _speedMultiplier);
    planet.uranus?.rotateMesh(0.03 * _speedMultiplier);
    planet.neptune?.rotateMesh(0.032 * _speedMultiplier);
    planet.pluto?.rotateMesh(0.008 * _speedMultiplier);

    ///
    planet.mecury?.rotateObject3D(0.04 * _speedMultiplier);
    planet.venus?.rotateObject3D(0.015 * _speedMultiplier);
    planet.earth?.rotateObject3D(0.01 * _speedMultiplier);
    planet.mars?.rotateObject3D(0.008 * _speedMultiplier);
    planet.jupiter?.rotateObject3D(0.002 * _speedMultiplier);
    planet.saturn?.rotateObject3D(0.0009 * _speedMultiplier);
    planet.uranus?.rotateObject3D(0.0004 * _speedMultiplier);
    planet.neptune?.rotateObject3D(0.0001 * _speedMultiplier);
    planet.pluto?.rotateObject3D(0.00007 * _speedMultiplier);
    
    // Update camera following if enabled
    if (_isFollowingPlanet) {
      _updateCameraForFollowing();
    }
    
    render();
    
    // Use adaptive frame delay instead of fixed 40ms
    Future.delayed(Duration(milliseconds: frameDelay), () {
      animate(
        planet: planet,
        sun: sun,
        render: render,
      );
    });
  }
}
