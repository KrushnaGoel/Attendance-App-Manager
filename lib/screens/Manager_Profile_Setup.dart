import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class ManagerProfileSetupPage extends StatefulWidget {
  @override
  _ManagerProfileSetupPageState createState() => _ManagerProfileSetupPageState();
}

class _ManagerProfileSetupPageState extends State<ManagerProfileSetupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  LocationData? _locationData;

  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    Location location = Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    // Check if service is enabled
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        // Cannot get location
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }
    }

    // Check for permissions
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        // Permissions not granted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    // Get location data
    try {
      _locationData = await location.getLocation();
      setState(() {});
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    }
  }

  Future<void> _submitProfile() async {
    if (_nameController.text.isEmpty || _locationData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide all the required information')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user == null) {
        // User is not logged in
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      String email = user.email!.toLowerCase();

      // Update the manager's document in Firestore
      await _firestore.collection('managers').doc(email).set({
        'name': _nameController.text.trim(),
        'email': email,
        'officeLocation': {
          'latitude': _locationData!.latitude,
          'longitude': _locationData!.longitude,
        },
        // You can add other fields as needed
      }, SetOptions(merge: true));

      // Navigate to the manager dashboard
      Navigator.pushReplacementNamed(context, '/managerDashboard');
    } on FirebaseException catch (e) {
      print('FirebaseException: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting profile: ${e.message}')),
      );
    } catch (e) {
      print('Error submitting profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              child: Icon(Icons.person, size: 60),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: Text('Set Office Location'),
            ),
            SizedBox(height: 16),
            if (_locationData != null)
              Text(
                'Location set: (${_locationData!.latitude}, ${_locationData!.longitude})',
              ),
            SizedBox(height: 24),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitProfile,
                    child: Text('Submit Profile'),
                  ),
          ],
        ),
      ),
    );
  }
}
