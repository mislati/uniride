import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'role_router.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _matricController = TextEditingController();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  bool _isLoginMode = true; 
  bool _isDriverMode = false; 
  bool _obscurePassword = true; 

  void _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final rawMatric = _matricController.text.trim().toUpperCase();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Please fill in your email and password.', isError: true);
      return;
    }

    if (!_isLoginMode) {
      if (phone.isEmpty || rawMatric.isEmpty) {
        _showSnackbar('Phone number and Matric Number are required for registration.', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, 
          password: password
        );
        
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        
        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('role') && data['role'] == 'admin') {
            await _auth.signOut();
            _showSnackbar('Admin accounts must use the Web Control Center.', isError: true);
            setState(() => _isLoading = false);
            return;
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RoleRouter()),
          );
        }
      } else {
        String safeMatricId = '';

        if (_isDriverMode) {
          safeMatricId = rawMatric.replaceAll('/', '');

          DocumentSnapshot approvalDoc = await _firestore.collection('approved_drivers').doc(safeMatricId).get();
          
          if (!approvalDoc.exists) {
            _showSnackbar('Matric Number not authorized. Please contact Admin.', isError: true);
            setState(() => _isLoading = false);
            return;
          }

          var data = approvalDoc.data() as Map<String, dynamic>?;
          if (data != null && data['isRegistered'] == true) {
            _showSnackbar('An account already exists for this Matric Number.', isError: true);
            setState(() => _isLoading = false);
            return;
          }
        }

        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, 
          password: password
        );
        
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'phone': phone,
          'matricNumber': rawMatric, 
          'fullName': rawMatric,    
          'role': _isDriverMode ? 'driver' : 'rider',
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': false, 
        });

        if (_isDriverMode) {
          await _firestore.collection('approved_drivers').doc(safeMatricId).update({
            'isRegistered': true,
            'driverUid': userCredential.user!.uid,
          });
        }
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RoleRouter()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showSnackbar('Email already exists. Please log in instead.', isError: true);
      } else {
        _showSnackbar(e.message ?? 'Authentication failed.', isError: true);
      }
    } catch (e) {
      _showSnackbar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackbar('Please enter your email first to reset your password.', isError: true);
      return;
    }
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSnackbar('Password reset link sent to $email', isError: false);
    } catch (e) {
      _showSnackbar('Failed to send reset link. Check if the email is correct.', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _matricController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0x1A5A5BFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.motorcycle, 
                    size: 60,
                    color: Color(0xFF5A5BFF),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLoginMode ? 'Welcome Back!' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode 
                      ? 'Login to request your next ride' 
                      : 'Sign up to start riding with your peers',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 2, offset: Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (!_isLoginMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isDriverMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !_isDriverMode ? const Color(0xFF5A5BFF) : const Color(0xFFF4F6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Rider',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: !_isDriverMode ? Colors.white : Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isDriverMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isDriverMode ? const Color(0xFF5A5BFF) : const Color(0xFFF4F6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Driver',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _isDriverMode ? Colors.white : Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      TextField(
                        controller: _emailController,
                        decoration: _buildInputDecoration('GSU Email', Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      
                      if (!_isLoginMode) ...[
                        TextField(
                          controller: _phoneController,
                          decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined, hint: 'e.g., 07061641444'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _matricController,
                          decoration: _buildInputDecoration('Matric Number', Icons.badge_outlined, hint: 'e.g., UG22/SCCS/1153'),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextField(
                        controller: _passwordController,
                        decoration: _buildInputDecoration('Password', Icons.lock_outline, isPassword: true),
                        obscureText: _obscurePassword,
                      ),
                      
                      if (_isLoginMode) 
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF5A5BFF), fontWeight: FontWeight.bold)),
                          ),
                        ),

                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5A5BFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  _isLoginMode 
                                      ? 'Login' 
                                      : (_isDriverMode ? 'Register as Driver' : 'Register as Rider'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5A5BFF),
                  ),
                  child: Text(
                    _isLoginMode 
                        ? "Don't have an account? Sign up" 
                        : "Already have an account? Log in",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // --- DYNAMIC CONTACT US BUTTON ---
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    String supportEmail = 'support@uniride.com'; // Fallback
                    try {
                      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('settings').doc('platform').get();
                      if (doc.exists) {
                        var data = doc.data() as Map<String, dynamic>;
                        String fetchedEmail = data['supportEmail'] ?? '';
                        if (fetchedEmail.isNotEmpty) {
                          supportEmail = fetchedEmail;
                        }
                      }
                    } catch (e) {
                      debugPrint('Error fetching support email: $e');
                    }

                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: supportEmail,
                      query: 'subject=Driver Matriculation Approval Request', 
                    );
                    if (await canLaunchUrl(emailLaunchUri)) {
                      await launchUrl(emailLaunchUri);
                    } else {
                      debugPrint('Could not launch email client.');
                    }
                  },
                  icon: const Icon(Icons.help_outline, color: Color(0xFF5A5BFF), size: 18),
                  label: const Text(
                    'New Driver? Contact us for Matric Approval',
                    style: TextStyle(color: Color(0xFF5A5BFF), fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hint, bool isPassword = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFF4F6FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }
}