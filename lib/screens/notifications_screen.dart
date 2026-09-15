import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  final bool isDriverMode; // <--- ADDED THIS FLAG

  const NotificationsScreen({super.key, required this.isDriverMode});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isDriverMode ? 'Driver Notifications' : 'Rider Notifications', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: user == null
          ? const Center(child: Text("Please log in to view notifications."))
          : StreamBuilder<QuerySnapshot>(
              // Fetch rides where they are the driver OR rider based on the current UI mode
              stream: FirebaseFirestore.instance
                  .collection('ride_requests')
                  .where(isDriverMode ? 'driverId' : 'riderId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var docs = snapshot.data!.docs;
                
                // Filter out 'pending' for drivers so they don't see rides they haven't accepted yet
                if (isDriverMode) {
                  docs = docs.where((d) {
                    var data = d.data() as Map<String, dynamic>;
                    return data['status'] != 'pending';
                  }).toList();
                  if (docs.isEmpty) return _buildEmptyState();
                }

                // Sort notifications so the newest updates appear at the top
                docs.sort((a, b) {
                  Timestamp? timeA = a.data().toString().contains('createdAt') ? a['createdAt'] as Timestamp? : null;
                  Timestamp? timeB = b.data().toString().contains('createdAt') ? b['createdAt'] as Timestamp? : null;
                  if (timeA == null || timeB == null) return 0;
                  return timeB.compareTo(timeA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var ride = docs[index];
                    var rideData = ride.data() as Map<String, dynamic>;
                    
                    String status = rideData['status'] ?? 'unknown';
                    String destination = rideData['destination'] ?? 'Unknown Location';
                    String pickup = rideData['pickupLocation'] ?? 'Unknown Location';
                    int exactPrice = rideData['price'] ?? 200;
                    
                    // Calculate driver net safely for completion notification
                    double driverNet = exactPrice * 0.85; 
                    if (rideData.containsKey('driverNet')) {
                      driverNet = rideData['driverNet'].toDouble();
                    }

                    String title = '';
                    String message = '';
                    IconData icon = Icons.notifications;
                    Color iconColor = Colors.grey;

                    if (isDriverMode) {
                      // --- DRIVER NOTIFICATION MESSAGES ---
                      if (status == 'accepted') {
                        title = 'New Ride Accepted';
                        message = 'You accepted a ride. Please head to $pickup to pick up your passenger.';
                        icon = Icons.motorcycle;
                        iconColor = const Color(0xFF5A5BFF);
                      } else if (status == 'arrived') {
                        title = 'Arrived at Pickup';
                        message = 'You have arrived at $pickup. Waiting for the passenger.';
                        icon = Icons.location_on;
                        iconColor = Colors.orangeAccent;
                      } else if (status == 'in_progress') {
                        title = 'Trip Started';
                        message = 'You are currently driving your passenger to $destination.';
                        icon = Icons.map;
                        iconColor = Colors.blue;
                      } else if (status == 'completed') {
                        title = 'Ride Completed';
                        message = 'You successfully dropped off your passenger at $destination and earned ₦${driverNet.toStringAsFixed(0)}.';
                        icon = Icons.star;
                        iconColor = Colors.green;
                      } else if (status == 'cancelled') {
                        title = 'Ride Cancelled';
                        message = 'The ride from $pickup to $destination was cancelled.';
                        icon = Icons.cancel;
                        iconColor = Colors.redAccent;
                      } else {
                        return const SizedBox.shrink();
                      }
                    } else {
                      // --- RIDER NOTIFICATION MESSAGES ---
                      if (status == 'pending') {
                        title = 'Searching for Driver';
                        message = 'Looking for a driver to take you to $destination.';
                        icon = Icons.search;
                        iconColor = const Color(0xFF5A5BFF);
                      } else if (status == 'accepted') {
                        title = 'Ride Accepted!';
                        message = 'A driver is on the way to pick you up for your trip to $destination.';
                        icon = Icons.motorcycle;
                        iconColor = Colors.orange;
                      } else if (status == 'arrived') {
                        title = 'Driver is Outside!';
                        message = 'Your driver has arrived at your pickup location.';
                        icon = Icons.location_on;
                        iconColor = Colors.orangeAccent;
                      } else if (status == 'in_progress') {
                        title = 'Trip in Progress';
                        message = 'You are currently en route to $destination. Ride safe!';
                        icon = Icons.map;
                        iconColor = Colors.blue;
                      } else if (status == 'completed') {
                        title = 'Trip Completed';
                        message = 'You have arrived at $destination. Total fare was ₦$exactPrice. Hope you had a great ride!';
                        icon = Icons.star;
                        iconColor = Colors.green;
                      } else if (status == 'cancelled') {
                        title = 'Ride Cancelled';
                        message = 'Your ride request to $destination was cancelled.';
                        icon = Icons.cancel;
                        iconColor = Colors.redAccent;
                      } else if (status == 'failed_no_drivers') {
                        title = 'No Drivers Available';
                        message = 'All drivers are currently busy. Please try requesting your ride to $destination again shortly.';
                        icon = Icons.time_to_leave;
                        iconColor = Colors.red;
                      } else {
                        return const SizedBox.shrink(); 
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
                        border: Border(left: BorderSide(color: iconColor, width: 4)), 
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: iconColor.withAlpha(26), shape: BoxShape.circle),
                            child: Icon(icon, color: iconColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No notifications yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            isDriverMode ? "Updates for your accepted rides will appear here." : "Your ride updates will appear here.", 
            style: const TextStyle(color: Colors.grey)
          ),
        ],
      ),
    );
  }
}