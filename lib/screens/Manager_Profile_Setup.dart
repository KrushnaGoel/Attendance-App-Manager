import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:location/location.dart';

class ManagerProfileSetupPage extends StatefulWidget {
  @override
  _ManagerProfileSetupPageState createState() => _ManagerProfileSetupPageState();
}

class _ManagerProfileSetupPageState extends State<ManagerProfileSetupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _nameController = TextEditingController();
  File? _imageFile;
  LocationData? _locationData;

  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker _picker = ImagePicker();
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: source, imageQuality: 50);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

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
  if (_nameController.text.isEmpty || _imageFile == null || _locationData == null) {
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

    // Ensure the image file is not null and exists
    if (_imageFile == null || !_imageFile!.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected image is invalid. Please choose a different image.')),
      );
      return;
    }
    // Upload the photo to Firebase Storage
    String fileName = 'managers/$email/profile_photo.jpg';
    print('Uploading to path: $fileName');

    UploadTask uploadTask = _storage.ref(fileName).putFile(
      _imageFile!,
    );

    // Listen to the upload task events
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      print('Task state: ${snapshot.state}');
      print('Progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100} %');
    });

    // Wait for the upload to complete and catch any errors
    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() {
      print('Upload complete');
    }).catchError((error) {
      print('Error during upload: $error');
      throw error; // Re-throw the error to be caught in the catch block
    });

    // Get the download URL
    String downloadURL = await taskSnapshot.ref.getDownloadURL();

    // Update the manager's document in Firestore
    await _firestore.collection('managers').doc(email).set({
      'name': _nameController.text.trim(),
      'photoURL': downloadURL,
      'officeLocation': {
        'latitude': _locationData!.latitude,
        'longitude': _locationData!.longitude,
      },
    }, SetOptions(merge: true));

    // Navigate to the manager dashboard
    Navigator.pushReplacementNamed(context, '/managerDashboard');
  } on FirebaseException catch (e) {
    print('FirebaseException during upload: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error uploading image: ${e.message}')),
    );
    return;
  } catch (e) {
    print('Error during upload: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
    );
    return;
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
            if (_imageFile != null)
              CircleAvatar(
                radius: 60,
                backgroundImage: FileImage(_imageFile!),
              )
            else
              CircleAvatar(
                radius: 60,
                child: Icon(Icons.person, size: 60),
              ),
            TextButton(
              onPressed: _showImageSourceActionSheet,
              child: Text('Upload Photo'),
            ),
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
