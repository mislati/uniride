import 'package:flutter/material.dart';
import 'rider_main_screen.dart';

class DriverDrawer extends StatefulWidget {
  const DriverDrawer({super.key});

  @override
  State<DriverDrawer> createState() => _DriverDrawerState();
}

class _DriverDrawerState extends State<DriverDrawer> {
  bool _isSwitching = false;

  Future<void> _switchToRider(BuildContext context) async {
    setState(() => _isSwitching = true);
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!context.mounted) return;
    
    // FIX: Wipe the navigation stack completely and build RiderMainScreen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RiderMainScreen()),
      (Route<dynamic> route) => false,
    );
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
              title: const Text('Switch to Rider Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: _isSwitching ? null : () => _switchToRider(context),
            ),
          ],
        ),
      ),
    );
  }
}