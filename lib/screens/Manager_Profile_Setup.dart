import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:manager/main.dart';

class ManagerProfileSetupPage extends StatefulWidget {
  @override
  _ManagerProfileSetupPageState createState() => _ManagerProfileSetupPageState();
}

class _ManagerProfileSetupPageState extends State<ManagerProfileSetupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _proximityController = TextEditingController();
  bool _isLoading = false;

  Map<String, dynamic>? officeLocation;

  @override
  void dispose() {
    _nameController.dispose();
    _proximityController.dispose();
    super.dispose();
  }

  Future<void> _setOfficeLocation() async {
    Location location = Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    // Check if service is enabled
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    // Get location data
    try {
      LocationData? currentLocation = await location.getLocation();
      if (currentLocation != null) {
        setState(() {
          officeLocation = {
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Office location set successfully.')),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    }
  }

  Future<void> _submitProfile() async {
    String name = _nameController.text.trim();
    String proximityStr = _proximityController.text.trim();

    if (name.isEmpty || officeLocation == null || proximityStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide all the required information')),
      );
      return;
    }

    double? proximity = double.tryParse(proximityStr);
    if (proximity == null || proximity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid proximity value')),
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
        Navigator.pushReplacementNamed(context, MyApp.loginRoute);
        return;
      }

      String email = user.email!.toLowerCase();

      // Update the manager's document in Firestore
      await _firestore.collection('managers').doc(email).set({
        'name': name,
        'email': email,
        'officeLocation': officeLocation,
        'proximity': proximity, // Add proximity field
        // Add other fields as needed
      }, SetOptions(merge: true));

      // Navigate to the manager dashboard
      Navigator.pushReplacementNamed(context, MyApp.managerDashboardRoute);
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

  Widget _buildProfileSetupForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _setOfficeLocation,
            child: Text('Set Office Location'),
          ),
          SizedBox(height: 8),
          if (officeLocation != null)
            Text(
              'Location set: (${officeLocation!['latitude']}, ${officeLocation!['longitude']})',
              style: TextStyle(fontSize: 16),
            ),
          SizedBox(height: 16),
          TextField(
            controller: _proximityController,
            decoration: InputDecoration(
              labelText: 'Proximity (in meters)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: _buildProfileSetupForm(),
      ),
    );
  }
}
