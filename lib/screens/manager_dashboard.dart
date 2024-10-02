import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Import GoogleSignIn

class ManagerDashboard extends StatefulWidget {
  @override
  _ManagerDashboardState createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final TextEditingController _emailController = TextEditingController();
  final CollectionReference managers =
      FirebaseFirestore.instance.collection('managers');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // Add GoogleSignIn instance

  String? managerEmail;

  @override
  void initState() {
    super.initState();
    User? user = _auth.currentUser;
    if (user != null) {
      managerEmail = user.email;
    } else {
      // Handle the case where the user is not logged in
      Navigator.pushReplacementNamed(context, '/login');
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

  Future<void> _addEmployeeEmail() async {
    String email = _emailController.text.trim();

    if (email.isNotEmpty && managerEmail != null) {
      // Add the employee email under the manager's document
      await managers.doc(managerEmail).set({
        'employees': FieldValue.arrayUnion([email])
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Employee added')),
      );

      _emailController.clear();
      setState((){});
    }
  }

  // Function to fetch employees
  Future<List<String>> _getEmployees() async {
    DocumentSnapshot managerDoc = await managers.doc(managerEmail).get();
    if (managerDoc.exists) {
      List<dynamic> employees = managerDoc.get('employees') ?? [];
      return List<String>.from(employees);
    }
    return [];
  }

  Future<void> _removeEmployeeEmail(String email) async {
    if (managerEmail != null) {
      await managers.doc(managerEmail).update({
        'employees': FieldValue.arrayRemove([email])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Employee removed')),
      );

      setState(() {
        // Refresh the UI
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut, // Use the _signOut method here
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Logged in as: $managerEmail'),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Employee Email',
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addEmployeeEmail,
              child: Text('Add Employee'),
            ),
            SizedBox(height: 24),
            Text(
              'Employees',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _getEmployees(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  } else if (snapshot.hasData) {
                    List<String> employees = snapshot.data!;
                    return ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(employees[index]),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () async {
                              await _removeEmployeeEmail(employees[index]);
                              setState(() {
                                // Refresh the UI
                              });
                            },
                          ),
                        );
                      },
                    );
                  } else {
                    return Text('No employees found.');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
