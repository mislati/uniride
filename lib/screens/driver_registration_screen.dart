import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_router.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _matricController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _upgradeToDriver() async {
    String rawMatric = _matricController.text.trim().toUpperCase();
    
    if (rawMatric.isEmpty) {
      _showSnackbar('Please enter your Matric Number.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _auth.currentUser!.uid;
      
      // 1. Convert to the secure ID format (e.g., UG22SCCS1153)
      String safeMatricId = rawMatric.replaceAll('/', '');

      // 2. Check the approvals collection
      DocumentSnapshot approvalDoc = await _firestore.collection('approved_drivers').doc(safeMatricId).get();

      if (!approvalDoc.exists) {
        _showSnackbar('Matric Number not authorized. Please contact Admin.');
        setState(() => _isLoading = false);
        return;
      }

      var approvalData = approvalDoc.data() as Map<String, dynamic>;
      if (approvalData['isRegistered'] == true) {
        _showSnackbar('This Matric Number is already registered to another account.');
        setState(() => _isLoading = false);
        return;
      }

      // 3. Upgrade their user profile in Firestore
      await _firestore.collection('users').doc(uid).update({
        'role': 'driver',
        'matricNumber': rawMatric, 
        'driverApprovedAt': FieldValue.serverTimestamp(),
      });

      // 4. Mark the matric number as claimed
      await _firestore.collection('approved_drivers').doc(safeMatricId).update({
        'isRegistered': true,
        'driverUid': uid,
      });

      // 5. Success! Route them to their new dashboard
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const RoleRouter()),
          (route) => false, 
        );
      }
      
    } catch (e) {
      _showSnackbar('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.drive_eta_rounded, size: 50, color: Color(0xFF5A5BFF)),
              const SizedBox(height: 20),
              const Text(
                'Become a Driver',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter your approved matriculation number to unlock driver features on your account.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: _matricController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Matric Number',
                  hintText: 'e.g., UG22/SCCS/1153',
                  prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15), 
                    borderSide: BorderSide.none
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _upgradeToDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A5BFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify & Upgrade', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}