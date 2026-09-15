import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverHistoryScreen extends StatelessWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Driver History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? const Center(child: Text("Please log in to see history."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ride_requests')
                  .where('driverId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("You haven't completed any rides yet.", style: TextStyle(color: Colors.grey, fontSize: 16))
                  );
                }

                var docs = snapshot.data!.docs;
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
                    var rideDoc = docs[index];
                    var rideData = rideDoc.data() as Map<String, dynamic>;
                    
                    String status = rideData['status'] ?? 'unknown';
                    String destination = rideData['destination'] ?? 'Unknown Location';
                    
                    // Extract exact dynamic price saved to database
                    int exactPrice = rideData['price'] ?? 200;
                    
                    Color statusColor = Colors.grey;
                    if (status == 'completed') statusColor = Colors.green;
                    if (status == 'accepted') statusColor = Colors.orange;
                    if (status == 'pending') statusColor = const Color(0xFF5A5BFF);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: statusColor.withAlpha(26), shape: BoxShape.circle),
                            child: Icon(Icons.receipt_long, color: statusColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(destination, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Status: ${status.toUpperCase()}', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('₦$exactPrice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}