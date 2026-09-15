import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  // --- DYNAMIC SOS METHOD ---
  Future<void> _triggerSOS(BuildContext context) async {
    // Optional: Show a quick loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fetching emergency contact...'), duration: Duration(seconds: 1)),
    );

    String emergencyNumber = '08000000000'; // Fallback number

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('settings').doc('platform').get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        String fetchedPhone = data['supportPhone'] ?? '';
        if (fetchedPhone.isNotEmpty) {
          emergencyNumber = fetchedPhone;
        }
      }
    } catch (e) {
      debugPrint('Error fetching SOS number: $e');
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: emergencyNumber);
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _updateProfileField(String field, String currentValue, String title) async {
    final TextEditingController editController = TextEditingController(text: currentValue);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit $title', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: 'Enter new $title',
            filled: true,
            fillColor: const Color(0xFFF4F6FF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
          keyboardType: field == 'phone' ? TextInputType.phone : TextInputType.name,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = editController.text.trim();
              if (newValue.isNotEmpty) {
                final User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    field: newValue,
                  });
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A5BFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? const Center(child: Text("No user logged in."))
          : StreamBuilder<DocumentSnapshot>( 
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("Error loading profile data."));
                }

                var userData = snapshot.data!.data() as Map<String, dynamic>;
                
                String email = userData['email'] ?? user.email ?? 'No Email';
                String phone = userData['phone'] ?? 'No Phone Provided';
                String role = userData['role'] ?? 'Rider';
                String matric = userData['matricNumber'] ?? 'N/A';
                
                String rawName = userData['fullName'] ?? '';
                String displayName = (rawName.isEmpty || rawName == 'Unknown User') ? matric : rawName;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFF5A5BFF), shape: BoxShape.circle),
                        child: const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 50, color: Color(0xFF5A5BFF)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF5A5BFF), size: 20),
                            onPressed: () => _updateProfileField('fullName', rawName.isEmpty ? '' : rawName, 'Name'),
                          ),
                        ],
                      ),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A5BFF).withAlpha(26),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(role.toUpperCase(), style: const TextStyle(color: Color(0xFF5A5BFF), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(height: 40),
                      
                      _buildProfileItem(Icons.badge, 'Matric Number', matric, isEditable: false),
                      const SizedBox(height: 16),
                      _buildProfileItem(Icons.email, 'Email Address', email, isEditable: false),
                      const SizedBox(height: 16),
                      _buildProfileItem(Icons.phone, 'Phone Number', phone, isEditable: true, onEdit: () => _updateProfileField('phone', phone, 'Phone Number')),
                      
                      const SizedBox(height: 40),
                      
                      // --- DYNAMIC SOS EMERGENCY BUTTON ---
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () => _triggerSOS(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                          ),
                          icon: const Icon(Icons.emergency, size: 24),
                          label: const Text('SOS / EMERGENCY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () => _logout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          label: const Text('Log Out', style: TextStyle(fontSize: 18, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value, {required bool isEditable, VoidCallback? onEdit}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          if (isEditable && onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF5A5BFF)),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}