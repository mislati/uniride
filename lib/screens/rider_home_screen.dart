import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notifications_screen.dart';
import 'mode_switch_drawer.dart'; 
import 'ride_matrix_helper.dart'; 

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  String _pickupLocation = '';
  String _selectedDestination = '';
  
  bool _isBooking = false;
  String? _currentRideId;
  String _userName = 'Rider';
  
  // Dynamic Ride Details
  int _estimatedPrice = 200;
  int _estimatedTime = 5;
  
  Timer? _dispatchTimer;
  
  final LatLng _campusLocation = const LatLng(10.3158, 11.1732); 
  
  final List<String> _campusPlaces = [
    '1st Gate', '2nd Gate', 'Diploma Gate', 'Admin Block', 'Senate Building',
    'ICT', 'NITDA Complex', 'Main Library', 'Convocation Square', 'Security Office',
    'Male Hostel', 'Male Hostel Mosque', 'GSU Juma\'a Mosque', 'Old Female Hostel',
    'New Female Hostel', 'Center of Open and Distance Learning',
    'Center for Entrepreneur Development', 'GSU Postgraduate School',
    'School of Basic and Remedial Studies', 'University Zoo', 'University Clinic',
    'Medical College', 'Faculty of Science Complex', 'Faculty of pharmaceutical Science',
    'Faculty of Law', 'Faculty of Arts and Social Sciences', 'Faculty of Education',
    'SRC garden', 'Mango Garden', 'Love Garden',
    'Faculty Rooms', 'A Block', 'E Block', 'LC1 LC2 LC3 LC4 LC5 LC6',
    'LT 1&2', 'LT3', 'LT4', 'LT 5&6', 'LT 7&8', 'LT 9&10',
    'LT11', 'LT12 & LT13', 'LT14', 'LTA & LTB', 'New MPH', 'Old MPH', 'English Theatre',
    'Science Complex Commercial Center', 'T Junction'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _checkForActiveRide();
  }

  @override
  void dispose() {
    _dispatchTimer?.cancel();
    super.dispose();
  }

  // Recalculates price and time instantly when dropdowns change
  void _calculateRideDetails() {
    if (_pickupLocation.isNotEmpty && _selectedDestination.isNotEmpty && _pickupLocation != _selectedDestination) {
      setState(() {
        _estimatedPrice = RideMatrixHelper.getPrice(_pickupLocation, _selectedDestination);
        _estimatedTime = RideMatrixHelper.getTime(_pickupLocation, _selectedDestination);
      });
    } else {
      setState(() {
        _estimatedPrice = 200; // Reset
        _estimatedTime = 5;
      });
    }
  }

  Future<void> _fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _userName = data?['fullName'] ?? 'Rider';
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _checkForActiveRide() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      var query = await FirebaseFirestore.instance
          .collection('ride_requests')
          .where('riderId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'accepted', 'arrived', 'in_progress'])
          .get();

      if (query.docs.isNotEmpty && mounted) {
        setState(() {
          _currentRideId = query.docs.first.id;
        });
        
        if (query.docs.first.get('status') == 'pending') {
          _startDispatchTimer(_currentRideId!);
        }
      }
    } catch (e) {
      debugPrint("Error checking active rides: $e");
    }
  }

  Future<void> _createRideRequest() async {
    if (_pickupLocation.isEmpty) {
      _showError('Please select a pickup location.');
      return;
    }
    if (_selectedDestination.isEmpty) {
      _showError('Please select your destination.');
      return;
    }
    if (_pickupLocation == _selectedDestination) {
      _showError('Pickup and destination cannot be the same.');
      return;
    }
    
    setState(() => _isBooking = true);
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      var driversQuery = await FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'driver')
          .where('isOnline', isEqualTo: true)
          .where('currentLocation', isEqualTo: _pickupLocation.trim())
          .get();

      if (driversQuery.docs.isEmpty) {
        _showError('No drivers are available at this location right now. Please try again later.');
        setState(() => _isBooking = false);
        return;
      }

      List<String> driverQueue = driversQuery.docs.map((doc) => doc.id).toList();

      DocumentReference docRef = await FirebaseFirestore.instance.collection('ride_requests').add({
        'riderId': user.uid,
        'pickupLocation': _pickupLocation.trim(),
        'destination': _selectedDestination.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'targetDriverId': driverQueue[0], 
        'driverQueue': driverQueue,       
        'queueIndex': 0, 
        'price': _estimatedPrice,        
        'estimatedTime': _estimatedTime, 
      });

      if (mounted) {
        setState(() {
          _currentRideId = docRef.id;
          _isBooking = false;
        });
        _selectedDestination = '';
        _startDispatchTimer(docRef.id);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error booking ride. Please try again.');
        setState(() => _isBooking = false);
      }
    }
  }

  void _startDispatchTimer(String rideId) {
    _dispatchTimer?.cancel();
    _dispatchTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      try {
        DocumentSnapshot rideDoc = await FirebaseFirestore.instance.collection('ride_requests').doc(rideId).get();
        if (!rideDoc.exists) {
          timer.cancel();
          return;
        }

        var data = rideDoc.data() as Map<String, dynamic>;
        
        if (data['status'] != 'pending') {
          timer.cancel();
          return;
        }

        List<dynamic> queue = data['driverQueue'] ?? [];
        int currentIndex = data['queueIndex'] ?? 0;
        int nextIndex = currentIndex + 1;

        if (nextIndex < queue.length) {
          await FirebaseFirestore.instance.collection('ride_requests').doc(rideId).update({
            'targetDriverId': queue[nextIndex],
            'queueIndex': nextIndex,
          });
        } else {
          timer.cancel();
          await FirebaseFirestore.instance.collection('ride_requests').doc(rideId).update({
            'status': 'failed_no_drivers',
          });
          if (mounted) {
            _showError('All nearby drivers are currently busy. Please try again in a few minutes.');
            setState(() => _currentRideId = null);
          }
        }
      } catch (e) {
        debugPrint('Timer error: $e');
      }
    });
  }

  Future<void> _cancelRide() async {
    if (_currentRideId == null) return;
    try {
      _dispatchTimer?.cancel();
      await FirebaseFirestore.instance.collection('ride_requests').doc(_currentRideId).delete();
      if (mounted) setState(() => _currentRideId = null);
    } catch (e) {
      debugPrint("Error canceling ride: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.info_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      drawer: const ModeSwitchDrawer(),
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.70,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _campusLocation, zoom: 15.5),
              myLocationButtonEnabled: false, zoomControlsEnabled: false,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(builder: (context) => CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.menu, color: Colors.black), onPressed: () => Scaffold.of(context).openDrawer()))),
                  // FIX IS HERE: isDriverMode is set to false
                  CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen(isDriverMode: false))))),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.45, minChildSize: 0.20, maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
                ),
                padding: const EdgeInsets.all(24.0),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 20),
                        _currentRideId == null ? _buildBookingUI() : _buildLiveStatusUI(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookingUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello $_userName,', style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const Text('Where are you heading?!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 20),
        
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) => textEditingValue.text.isEmpty ? const Iterable<String>.empty() : _campusPlaces.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())),
          onSelected: (String selection) {
            setState(() => _pickupLocation = selection);
            _calculateRideDetails();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller, focusNode: focusNode,
              onChanged: (value) {
                setState(() => _pickupLocation = value);
                _calculateRideDetails(); 
              },
              decoration: InputDecoration(
                hintText: 'Pickup Location (e.g., Male Hostel)',
                prefixIcon: const Icon(Icons.my_location, color: Color(0xFF5A5BFF)),
                filled: true, fillColor: const Color(0xFFF4F6FF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) => textEditingValue.text.isEmpty ? const Iterable<String>.empty() : _campusPlaces.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())),
          onSelected: (String selection) {
            setState(() => _selectedDestination = selection);
            _calculateRideDetails(); 
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller, focusNode: focusNode,
              onChanged: (value) {
                _selectedDestination = value;
                _calculateRideDetails(); 
              },
              decoration: InputDecoration(
                hintText: 'Destination (e.g., Convocation Square)',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true, fillColor: const Color(0xFFF4F6FF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        if (_pickupLocation.isNotEmpty && _selectedDestination.isNotEmpty && _pickupLocation != _selectedDestination)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: const Color(0xFFF4F6FF), borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFF5A5BFF)),
                    const SizedBox(height: 4),
                    Text('~$_estimatedTime mins', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Icon(Icons.payments_outlined, color: Colors.green),
                    const SizedBox(height: 4),
                    Text('₦$_estimatedPrice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity, height: 60,
          child: ElevatedButton(
            onPressed: _isBooking ? null : _createRideRequest,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
            child: _isBooking ? const CircularProgressIndicator(color: Colors.white) : const Text('Request a Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        
        const SizedBox(height: 30),
        const Text('Active Drivers Nearby', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        
        _pickupLocation.isEmpty
            ? const Text('Enter a pickup location to see nearby drivers.', style: TextStyle(color: Colors.grey))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'driver')
                    .where('isOnline', isEqualTo: true)
                    .where('currentLocation', isEqualTo: _pickupLocation.trim())
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(color: Color(0xFF5A5BFF));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No drivers currently available at this location.', style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE2E4F0), 
                          child: Icon(Icons.motorcycle, color: Color(0xFF5A5BFF))
                        ),
                        title: Text(doc['fullName'] ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Ready at $_pickupLocation'),
                        trailing: const Icon(Icons.circle, color: Colors.green, size: 12),
                      );
                    }).toList(),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildLiveStatusUI() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('ride_requests').doc(_currentRideId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
        
        var rideData = snapshot.data!.data() as Map<String, dynamic>;
        String status = rideData['status'] ?? "pending";
        String destination = rideData['destination'] ?? 'Unknown';
        int savedPrice = rideData['price'] ?? 200;
        int savedTime = rideData['estimatedTime'] ?? 5;
        String? driverId = rideData['driverId'];
        
        if (status == 'pending') {
          return SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Color(0xFF5A5BFF)),
                const SizedBox(height: 16),
                const Text('Pinging nearby drivers...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Heading to $destination', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text('₦$savedPrice • ~$savedTime mins', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 24),
                TextButton.icon(onPressed: _cancelRide, icon: const Icon(Icons.cancel, color: Colors.red), label: const Text('Cancel Request', style: TextStyle(color: Colors.red)))
              ],
            ),
          );
        } else if ((status == 'accepted' || status == 'arrived' || status == 'in_progress') && driverId != null) {
          
          String statusMsg = 'Driver Accepted!';
          Color statusColor = Colors.green;
          if (status == 'arrived') {
            statusMsg = 'Driver Arrived!';
            statusColor = Colors.orange;
          } else if (status == 'in_progress') {
            statusMsg = 'Ride in Progress';
            statusColor = const Color(0xFF5A5BFF);
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(driverId).get(),
            builder: (context, driverSnapshot) {
              if (!driverSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              String driverName = driverData['fullName'] ?? 'Your Driver';
              String driverPhone = driverData['phone'] ?? 'N/A';
              String bikeBrand = driverData['bikeBrand'] ?? 'Standard Bike';
              
              return SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 40)),
                    const SizedBox(height: 16),
                    Text(statusMsg, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: statusColor)),
                    Text('Est. Trip Time: $savedTime mins', style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF4F6FF), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE2E4F0))),
                      child: Row(
                        children: [
                          const CircleAvatar(backgroundColor: Color(0xFF5A5BFF), child: Icon(Icons.person, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text(bikeBrand, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call, color: Colors.green, size: 30), 
                            onPressed: () { 
                              Uri callUri = Uri(scheme: 'tel', path: driverPhone);
                              launchUrl(callUri); 
                            }
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on, color: Colors.redAccent),
                      title: Text(destination, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('₦$savedPrice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    ),
                    if (status != 'in_progress')
                      TextButton.icon(onPressed: _cancelRide, icon: const Icon(Icons.cancel, color: Colors.red), label: const Text('Cancel Request', style: TextStyle(color: Colors.red)))
                  ],
                ),
              );
            },
          );
        } else if (status == 'completed') {
          return SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF5A5BFF), shape: BoxShape.circle), child: const Icon(Icons.star, color: Colors.white, size: 40)),
                const SizedBox(height: 16),
                const Text('You have arrived!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5A5BFF))),
                Text('Total Paid: ₦$savedPrice', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { setState(() { _currentRideId = null; }); }, child: const Text('Book Another Ride', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))
              ],
            ),
          );
        } else if (status == 'failed_no_drivers') {
           return SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.time_to_leave, color: Colors.grey, size: 60),
                const SizedBox(height: 16),
                const Text('No Drivers Available', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('All drivers at your location are currently busy. Please wait a moment and try again.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { setState(() { _currentRideId = null; }); }, child: const Text('Try Again', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}