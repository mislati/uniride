import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RideMatrixHelper {
  static Map<String, dynamic> _matrix = {};
  static bool _isLoaded = false;

  // 1. Load JSON into memory
  static Future<void> init() async {
    if (_isLoaded) return;
    try {
      final String response = await rootBundle.loadString('assets/UniRide_Location_Combinations.json');
      _matrix = json.decode(response);
      _isLoaded = true;
      debugPrint("SUCCESS: Campus Matrix Loaded with ${_matrix.keys.length} locations!");
    } catch (e) {
      debugPrint("ERROR loading campus matrix: $e");
    }
  }

  // 2. Get exact route details (checks both directions)
  static Map<String, dynamic>? getRouteDetails(String pickup, String destination) {
    if (!_isLoaded || pickup.isEmpty || destination.isEmpty || pickup == destination) return null;
    
    // Check Forward (A to B)
    if (_matrix.containsKey(pickup) && _matrix[pickup].containsKey(destination)) {
      return _matrix[pickup][destination];
    }
    
    // Check Backward (B to A)
    if (_matrix.containsKey(destination) && _matrix[destination].containsKey(pickup)) {
      return _matrix[destination][pickup];
    }
    
    return null; 
  }

  // 3. Helper to grab price
  static int getPrice(String pickup, String destination) {
    final route = getRouteDetails(pickup, destination);
    return route != null ? (route['price_naira'] ?? 200) : 200; // Fallback to 200
  }

  // 4. Helper to grab time
  static int getTime(String pickup, String destination) {
    final route = getRouteDetails(pickup, destination);
    return route != null ? (route['time_min'] ?? 5) : 5; // Fallback to 5 mins
  }
}