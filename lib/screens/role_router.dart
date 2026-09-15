import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rider_main_screen.dart'; 
import 'driver_main_screen.dart'; 
import 'auth_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  Future<void> _routeUser() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        String role = userDoc.get('role');
        
        if (mounted) {
          if (role == 'driver') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DriverMainScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RiderMainScreen()));
          }
        }
      } else {
        if (mounted) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error routing user: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F6FF),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF5A5BFF)),
      ),
    );
  }
}