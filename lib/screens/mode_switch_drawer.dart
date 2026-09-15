import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_registration_screen.dart';
import 'driver_main_screen.dart'; 

class ModeSwitchDrawer extends StatefulWidget {
  const ModeSwitchDrawer({super.key});

  @override
  State<ModeSwitchDrawer> createState() => _ModeSwitchDrawerState();
}

class _ModeSwitchDrawerState extends State<ModeSwitchDrawer> {
  bool _isSwitching = false;

  Future<void> _attemptSwitchToDriver(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    setState(() => _isSwitching = true);
    
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (!context.mounted) return; 
      
      if (userDoc.exists) {
        String currentRole = userDoc.get('role') ?? 'rider';
        
        if (currentRole == 'driver') {
          // FIX: Wipe the navigation stack completely and build DriverMainScreen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DriverMainScreen()),
            (Route<dynamic> route) => false,
          );
        } else {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [Icon(Icons.drive_eta, color: Color(0xFF5A5BFF)), SizedBox(width: 10), Text('Driver Mode')]),
              content: const Text('You did not register as a driver.\n\nWant to start driving?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext); 
                    Navigator.pop(context); 
                  }, 
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF), foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(dialogContext); 
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverRegistrationScreen()));
                  },
                  child: const Text('Register Now'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Text(
                'Quick Actions', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)
              ),
            ),
            ListTile(
              leading: _isSwitching 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.swap_horiz, color: Color(0xFF5A5BFF)),
              title: const Text('Switch to Driver Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: _isSwitching ? null : () => _attemptSwitchToDriver(context),
            ),
          ],
        ),
      ),
    );
  }
}