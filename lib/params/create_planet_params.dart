import 'dart:convert';

import 'package:solar_system/params/planet_ring_params.dart';

class CreatePlanetParams {
  CreatePlanetParams({
    required this.size,
    required this.texture,
    required this.position,
    this.planetRingParams,
    this.lodLevels,
    this.lowResTexture,
    this.segments,
  });
  final double size;
  final String texture;
  final String? lowResTexture; // For distant viewing
  final double position;
  final PlanetRingParams? planetRingParams;
  final List<int>? lodLevels; // [high, medium, low] segment counts
  final int? segments; // Override default segments

  // LOD configuration for mobile optimization
  static const Map<String, List<int>> defaultLOD = {
    'high': [30, 20, 10],    // Close, medium, far distances
    'medium': [20, 15, 8],   // Balanced performance
    'low': [15, 10, 6],      // Maximum performance
  };

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'size': size,
      'texture': texture,
      'lowResTexture': lowResTexture,
      'position': position,
      'planet_ring': planetRingParams,
      'lodLevels': lodLevels,
      'segments': segments,
    };
  }

  String toJson() => json.encode(toMap());
}
