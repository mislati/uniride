import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'notifications_screen.dart';
import 'driver_drawer.dart'; 

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final LatLng _campusLocation = const LatLng(10.3158, 11.1732);
  
  bool _isOnline = false;
  bool _isLoading = true;
  String _currentLocation = '';
  final TextEditingController _locationController = TextEditingController();

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
    _fetchInitialStatus();
  }

  Future<void> _fetchInitialStatus() async {
    if (currentUser == null) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _isOnline = doc.get('isOnline') ?? false;
          _currentLocation = doc.get('currentLocation') ?? '';
          _locationController.text = _currentLocation;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (currentUser == null) return;
    
    if (!_isOnline && _currentLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your current location before going online.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent),
      );
      return;
    }

    bool newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'isOnline': newStatus,
        'currentLocation': _currentLocation,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isOnline = !newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _updateRideStatus(String rideId, String newStatus) async {
    if (currentUser == null) return;
    try {
      // NEW FIX: Suspension Check before accepting a ride!
      if (newStatus == 'accepted') {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
        bool isSuspended = (userDoc.data() as Map<String, dynamic>)['isSuspended'] ?? false;
        
        if (isSuspended) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                    SizedBox(width: 10),
                    Text('Account Suspended', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const Text('Contact admin to resolve issue, it\'s likely that you didn\'t settle your outstanding balance.', style: TextStyle(fontSize: 16)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF)),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Understood', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          }
          return; // Stop the code here so they cannot accept the ride
        }
      }

      await FirebaseFirestore.instance.collection('ride_requests').doc(rideId).update({
        'status': newStatus,
        if (newStatus == 'accepted') 'driverId': currentUser!.uid,
      });
    } catch (e) {
      debugPrint('Error updating ride: $e');
    }
  }

  Future<void> _completeRide(String rideId, String destination) async {
    if (currentUser == null) return;
    try {
      double adminCut = 15.0;
      double baseFare = 200.0;
      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('platform').get();
      if (settingsDoc.exists) {
        var data = settingsDoc.data() as Map<String, dynamic>;
        adminCut = (data['adminCutPercentage'] ?? 15.0).toDouble();
        baseFare = (data['baseFare'] ?? 200.0).toDouble();
      }

      DocumentSnapshot rideDoc = await FirebaseFirestore.instance.collection('ride_requests').doc(rideId).get();
      double ridePrice = baseFare;
      if (rideDoc.exists) {
        var rData = rideDoc.data() as Map<String, dynamic>?;
        if (rData != null && rData.containsKey('price')) {
          ridePrice = rData['price'].toDouble();
        }
      }

      double driverNet = ridePrice * (1.0 - (adminCut / 100.0));

      await FirebaseFirestore.instance.collection('ride_requests').doc(rideId).update({
        'status': 'completed',
        'driverNet': driverNet,
      });
      
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'completedRides': FieldValue.increment(1),
        'earnings': FieldValue.increment(driverNet), 
        'currentLocation': destination, 
      });

      if (mounted) {
        setState(() {
          _currentLocation = destination;
          _locationController.text = destination;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Ride Completed! ₦${driverNet.toStringAsFixed(0)} earned.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing ride: $e');
    }
  }

  void _showEarningsAnalytics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('settings').doc('platform').snapshots(),
                builder: (context, settingsSnapshot) {
                  String adminCutText = '15%';
                  double driverFraction = 0.85;
                  
                  if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
                    var data = settingsSnapshot.data!.data() as Map<String, dynamic>;
                    double cut = (data['adminCutPercentage'] ?? 15.0).toDouble();
                    adminCutText = '${cut.toInt()}%';
                    driverFraction = 1.0 - (cut / 100.0);
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your net earnings after the $adminCutText platform fee.', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('ride_requests')
                            .where('driverId', isEqualTo: currentUser?.uid)
                            .where('status', isEqualTo: 'completed')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          
                          double today = 0, week = 0, month = 0, year = 0, allTime = 0;
                          DateTime now = DateTime.now();
                          
                          DateTime startOfDay = DateTime(now.year, now.month, now.day);
                          DateTime startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
                          
                          Map<String, double> monthlyBreakdown = {};

                          if (snapshot.hasData) {
                            for (var doc in snapshot.data!.docs) {
                              var data = doc.data() as Map<String, dynamic>;
                              Timestamp? ts = data['createdAt'] as Timestamp?;
                              
                              if (ts != null) {
                                DateTime date = ts.toDate();
                                
                                double price = (data['price'] ?? 200).toDouble();
                                double netPay = price * driverFraction; 
                                
                                allTime += netPay;
                                if (date.year == now.year) year += netPay;
                                if (date.year == now.year && date.month == now.month) month += netPay;
                                
                                if (date.millisecondsSinceEpoch >= startOfWeek.millisecondsSinceEpoch) week += netPay;
                                
                                if (date.year == now.year && date.month == now.month && date.day == now.day) today += netPay;

                                String monthKey = DateFormat('MMMM yyyy').format(date);
                                monthlyBreakdown[monthKey] = (monthlyBreakdown[monthKey] ?? 0) + netPay;
                              }
                            }
                          }

                          var sortedMonths = monthlyBreakdown.keys.toList()
                            ..sort((a, b) {
                              DateTime dateA = DateFormat('MMMM yyyy').parse(a);
                              DateTime dateB = DateFormat('MMMM yyyy').parse(b);
                              return dateB.compareTo(dateA); 
                            });

                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.60, 
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAnalyticsCard('Today', today, Icons.today, Colors.blue),
                                  const SizedBox(height: 12),
                                  _buildAnalyticsCard('This Week', week, Icons.date_range, Colors.green),
                                  const SizedBox(height: 12),
                                  _buildAnalyticsCard('This Month', month, Icons.calendar_month, Colors.orange),
                                  const SizedBox(height: 12),
                                  _buildAnalyticsCard('This Year', year, Icons.bar_chart, Colors.purple),
                                  const SizedBox(height: 12),
                                  _buildAnalyticsCard('All Time', allTime, Icons.account_balance_wallet, const Color(0xFF5A5BFF)),
                                  
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24.0),
                                    child: Divider(thickness: 1.5),
                                  ),
                                  const Text('Monthly Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  
                                  ...sortedMonths.map((monthKey) => ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                                      child: const Icon(Icons.history, color: Colors.grey, size: 20),
                                    ),
                                    title: Text(monthKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: Text('₦${monthlyBreakdown[monthKey]!.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                    contentPadding: EdgeInsets.zero,
                                  )),
                                  
                                  if (sortedMonths.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 10.0),
                                      child: Text('No past earnings yet.', style: TextStyle(color: Colors.grey)),
                                    ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          );
                        }
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildAnalyticsCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('₦${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      drawer: const DriverDrawer(),
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.40,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _campusLocation, zoom: 15.5),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('driver_location'),
                  position: _campusLocation,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                ),
              },
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(builder: (context) => CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.menu, color: Colors.black), onPressed: () => Scaffold.of(context).openDrawer()))),
                  CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen(isDriverMode: true))))),
                ],
              ),
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.70,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Driver Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                      TextButton(
                        onPressed: _showEarningsAnalytics,
                        child: const Text('View Analytics', style: TextStyle(color: Color(0xFF5A5BFF), fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('settings').doc('platform').snapshots(),
                    builder: (context, settingsSnapshot) {
                      double currentCut = 15.0;
                      if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
                        var sData = settingsSnapshot.data!.data() as Map<String, dynamic>;
                        currentCut = (sData['adminCutPercentage'] ?? 15.0).toDouble();
                      }
                      double driverFraction = 1.0 - (currentCut / 100.0);

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('ride_requests')
                            .where('driverId', isEqualTo: currentUser?.uid)
                            .where('status', isEqualTo: 'completed')
                            .snapshots(),
                        builder: (context, rideSnapshot) {
                          int rides = 0;
                          double totalNetEarnings = 0;

                          if (rideSnapshot.hasData) {
                            rides = rideSnapshot.data!.docs.length;
                            for (var doc in rideSnapshot.data!.docs) {
                              var data = doc.data() as Map<String, dynamic>;
                              double price = (data['price'] ?? 200).toDouble();
                              totalNetEarnings += (price * driverFraction);
                            }
                          }

                          int displayEarnings = totalNetEarnings.toInt(); 

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFF4F6FF), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('₦$displayEarnings', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5A5BFF))),
                                    const Text("Total Net Earnings", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                                Container(height: 40, width: 1, color: Colors.grey),
                                Column(
                                  children: [
                                    Text('$rides', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    const Text('Completed Rides', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  const Text('Current Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) => textEditingValue.text.isEmpty ? const Iterable<String>.empty() : _campusPlaces.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())),
                    onSelected: (String selection) {
                      setState(() => _currentLocation = selection);
                      if (_isOnline) {
                        FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({'currentLocation': selection});
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text.isEmpty && _currentLocation.isNotEmpty) {
                        controller.text = _currentLocation;
                      }
                      return TextField(
                        controller: controller, focusNode: focusNode,
                        onChanged: (value) => _currentLocation = value,
                        decoration: InputDecoration(
                          hintText: 'Where are you parked?',
                          prefixIcon: const Icon(Icons.my_location, color: Color(0xFF5A5BFF)),
                          filled: true, fillColor: const Color(0xFFF4F6FF),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _toggleOnlineStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOnline ? Colors.redAccent : const Color(0xFF5A5BFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Text(_isOnline ? 'Go Offline' : 'Go Online', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('ride_requests').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
                        if (!snapshot.hasData) return const SizedBox.shrink();

                        var allDocs = snapshot.data!.docs;
                        
                        var activeRides = allDocs.where((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String status = data['status'] ?? '';
                          return data['driverId'] == currentUser?.uid && (status == 'accepted' || status == 'arrived' || status == 'in_progress');
                        }).toList();

                        var pendingRequests = allDocs.where((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return data['targetDriverId'] == currentUser?.uid && data['status'] == 'pending';
                        }).toList();

                        bool showPending = pendingRequests.isNotEmpty && (activeRides.isEmpty || activeRides.first['status'] != 'in_progress');

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              if (activeRides.isNotEmpty) _buildActiveRideUI(activeRides.first),
                              if (showPending) _buildIncomingRequestsList(pendingRequests),
                              if (activeRides.isEmpty && !showPending)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text(_isOnline ? 'Looking for passengers...' : 'You are offline. Go online to receive ride requests.', style: const TextStyle(color: Colors.grey)),
                                )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsList(List<QueryDocumentSnapshot> requests) {
    return Column(
      children: requests.map((request) {
        var requestData = request.data() as Map<String, dynamic>;
        int exactPrice = requestData['price'] ?? 200;
        int exactTime = requestData['estimatedTime'] ?? 5;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF5A5BFF), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Incoming Request!', style: TextStyle(color: Color(0xFF5A5BFF), fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withAlpha(26), borderRadius: BorderRadius.circular(10)),
                    child: Text('₦$exactPrice', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Color(0x335A5BFF), shape: BoxShape.circle),
                    child: const Icon(Icons.person, color: Color(0xFF5A5BFF)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To: ${requestData['destination']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Pickup: ${requestData['pickupLocation']} (~$exactTime mins)', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () => _updateRideStatus(request.id, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A5BFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveRideUI(DocumentSnapshot ride) {
    var rideData = ride.data() as Map<String, dynamic>;
    String status = rideData['status'];
    String destination = rideData['destination'];
    String pickup = rideData['pickupLocation'];
    
    int exactPrice = rideData['price'] ?? 200;
    int exactTime = rideData['estimatedTime'] ?? 5;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(rideData['riderId']).get(),
      builder: (context, riderSnapshot) {
        if (!riderSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
        
        var riderInfo = riderSnapshot.data!.data() as Map<String, dynamic>?;
        String riderName = riderInfo?['fullName'] ?? 'Passenger';
        String riderPhone = riderInfo?['phone'] ?? 'N/A';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x4D5A5BFF)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    status == 'in_progress' ? 'Trip in Progress' : 'Active Ride', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: status == 'in_progress' ? Colors.green : const Color(0xFF5A5BFF))
                  ),
                  Text('Collect: ₦$exactPrice', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const CircleAvatar(backgroundColor: Color(0xFF5A5BFF), child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(riderPhone, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green, size: 30),
                    onPressed: () { debugPrint("Calling $riderPhone"); }, 
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              Text('Heading to: $destination', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              if (status != 'in_progress') Text('Pickup: $pickup', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              
              if (status == 'in_progress') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'Estimated time: $exactTime mins',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity, height: 45,
                child: _buildDynamicActionButton(ride.id, status, destination),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildDynamicActionButton(String rideId, String status, String destination) {
    if (status == 'accepted') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => _updateRideStatus(rideId, 'arrived'),
        child: const Text('I have Arrived', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    } else if (status == 'arrived') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => _updateRideStatus(rideId, 'in_progress'),
        child: const Text('Start Trip', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    } else {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => _completeRide(rideId, destination),
        child: const Text('Complete Ride', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }
  }
}