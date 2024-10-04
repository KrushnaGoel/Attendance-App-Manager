import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ManagerLoginPage extends StatefulWidget {
  @override
  _ManagerLoginPageState createState() => _ManagerLoginPageState();
}

class _ManagerLoginPageState extends State<ManagerLoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signInWithGoogle() async {
  try {
    // Start the sign-in process
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
    if (googleUser == null) {
      // User canceled the sign-in
      return;
    }

    // Obtain the auth details
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase
    final UserCredential userCredential = await _auth.signInWithCredential(credential);

    // Get the signed-in user's email
    final String email = userCredential.user?.email?.toLowerCase() ?? '';

    // Check if the email exists in the 'managers' collection
    final DocumentSnapshot managerDoc = await _firestore.collection('managers').doc(email).get();

    if (managerDoc.exists) {
      // User is a manager
      // Check if the manager has a name associated
      if (managerDoc.data() != null && (managerDoc.data() as Map<String, dynamic>).containsKey('name')) {
        // Manager profile exists, navigate to dashboard
        Navigator.pushReplacementNamed(context, '/managerDashboard');
      } else {
        // Manager profile does not exist, navigate to profile setup
        Navigator.pushReplacementNamed(context, '/managerProfileSetup');
      }
    } else {
      // User is not a manager
      await _auth.signOut();
      await _googleSignIn.disconnect();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access denied: You are not authorized as a manager'),
        ),
      );
    }
  } catch (e) {
    print('Error during sign-in: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sign-in failed: ${e.toString()}'),
      ),
    );
  }
}


  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.disconnect();

      // Navigate back to the login page or update the UI
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manager Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _signInWithGoogle,
          child: Text('Sign in with Google'),
        ),
      ),
    );
  }
}
