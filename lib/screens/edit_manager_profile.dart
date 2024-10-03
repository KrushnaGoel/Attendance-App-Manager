// lib/edit_manager_profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:manager/main.dart'; // Import to access route names

class EditManagerProfilePage extends StatefulWidget {
  @override
  _EditManagerProfilePageState createState() => _EditManagerProfilePageState();
}

class _EditManagerProfilePageState extends State<EditManagerProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _proximityController = TextEditingController();
  bool _isLoading = true;

  late String managerEmail;
  late String currentName;
  double? currentProximity;
  Map<String, dynamic>? officeLocation;

  @override
  void initState() {
    super.initState();
    _fetchManagerDetails();
  }

  Future<void> _fetchManagerDetails() async {
    User? user = _auth.currentUser;
    if (user == null) {
      // User is not logged in
      Navigator.pushReplacementNamed(context, MyApp.loginRoute);
      return;
    }

    managerEmail = user.email!.toLowerCase();

    try {
      DocumentSnapshot managerDoc =
          await _firestore.collection('managers').doc(managerEmail).get();

      if (managerDoc.exists) {
        currentName = managerDoc['name'] ?? '';
        _nameController.text = currentName;
        officeLocation = managerDoc['officeLocation'];
        currentProximity = (managerDoc['proximity'] as num?)?.toDouble();
        _proximityController.text = currentProximity != null
            ? currentProximity.toString()
            : '';
        setState(() {
          _isLoading = false;
        });
      } else {
        // Manager document does not exist
        Navigator.pushReplacementNamed(context, MyApp.managerProfileSetupRoute);
      }
    } catch (e) {
      print('Error fetching manager details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching details: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateProfile() async {
    String newName = _nameController.text.trim();
    String proximityStr = _proximityController.text.trim();

    if (newName.isEmpty || officeLocation == null || proximityStr.isEmpty) {
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
      Map<String, dynamic> updateData = {
        'name': newName,
        'proximity': proximity,
        'officeLocation': officeLocation,
      };

      await _firestore.collection('managers').doc(managerEmail).update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context); // Go back to ManagerDashboard
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          SnackBar(content: Text('Office location updated successfully.')),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushNamedAndRemoveUntil(context, MyApp.loginRoute, (route) => false);
  }

  Widget _buildEditForm() {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Manager Name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              // Office Location and Update Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      officeLocation != null
                          ? 'Location: (${officeLocation!['latitude']}, ${officeLocation!['longitude']})'
                          : 'Office Location Not Set',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _setOfficeLocation,
                    child: Text('Update Location'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Proximity
              TextField(
                controller: _proximityController,
                decoration: InputDecoration(
                  labelText: 'Proximity (in meters)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProfile,
                child: Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEditForm(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red, // Red color for the button
                      ),
                      child: Text('Logout'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
