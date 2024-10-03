import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manager/main.dart'; 

class ManagerDashboard extends StatefulWidget {
  @override
  _ManagerDashboardState createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String managerEmail;
  late String managerName;
  bool _isLoading = true;
  List<DocumentSnapshot> _employees = [];

  @override
  void initState() {
    super.initState();
    _fetchManagerData();
  }

  Future<void> _fetchManagerData() async {
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
        managerName = managerDoc['name'] ?? 'Manager';
        await _fetchEmployees();
      } else {
        // Manager document does not exist
        Navigator.pushReplacementNamed(context, MyApp.managerProfileSetupRoute);
      }
    } catch (e) {
      print('Error fetching manager data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching manager data: ${e.toString()}')),
      );
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      QuerySnapshot employeeSnapshot = await _firestore
          .collection('employees')
          .where('managerEmail', isEqualTo: managerEmail)
          .get();

      setState(() {
        _employees = employeeSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching employees: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching employees: ${e.toString()}')),
      );
    }
  }

  Future<void> _addEmployee() async {
    TextEditingController _emailController = TextEditingController();
    TextEditingController _nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Employee Email',
              ),
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Employee Name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              String employeeEmail = _emailController.text.trim().toLowerCase();
              String employeeName = _nameController.text.trim();

              if (employeeEmail.isEmpty || employeeName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please provide all the required information')),
                );
                return;
              }

              Navigator.of(context).pop();

              try {
                // Check if the employee already exists
                DocumentSnapshot employeeDoc = await _firestore
                    .collection('employees')
                    .doc(employeeEmail)
                    .get();

                if (employeeDoc.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Employee already exists')),
                  );
                  return;
                }

                // Create the employee document
                await _firestore.collection('employees').doc(employeeEmail).set({
                  'email': employeeEmail,
                  'name': employeeName,
                  'managerEmail': managerEmail,
                  // Add other fields as needed
                });

                // Refresh the employee list
                await _fetchEmployees();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Employee added successfully')),
                );
              } catch (e) {
                print('Error adding employee: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding employee: ${e.toString()}')),
                );
              }
            },
            child: Text('Add'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeEmployee(String employeeEmail) async {
    try {
      // Delete the employee document from the 'employees' collection
      await _firestore.collection('employees').doc(employeeEmail).delete();

      // Refresh the employee list
      await _fetchEmployees();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Employee removed successfully')),
      );
    } catch (e) {
      print('Error removing employee: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing employee: ${e.toString()}')),
      );
    }
  }

  Future<void> _confirmRemoveEmployee(String employeeEmail, String employeeName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Employee'),
        content: Text('Are you sure you want to remove $employeeName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeEmployee(employeeEmail);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, MyApp.loginRoute);
  }

  Widget _buildEmployeeList() {
    if (_employees.isEmpty) {
      return Center(child: Text('No employees added yet.'));
    }

    return ListView.builder(
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        DocumentSnapshot employeeDoc = _employees[index];
        String employeeName = employeeDoc['name'] ?? 'Employee';
        String employeeEmail = employeeDoc['email'] ?? '';

        return ListTile(
          title: Text(employeeName),
          subtitle: Text(employeeEmail),
          trailing: IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _confirmRemoveEmployee(employeeEmail, employeeName),
            tooltip: 'Remove Employee',
          ),
          // Add more details or actions as needed
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $managerName'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            tooltip: 'Edit Profile',
            onPressed: () {
              // Navigate to EditManagerProfilePage using named route
              Navigator.pushNamed(context, MyApp.editManagerProfileRoute).then((_) {
                // Refresh manager data in case of changes
                _fetchManagerData();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchEmployees,
              child: _buildEmployeeList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEmployee,
        child: Icon(Icons.person_add),
        tooltip: 'Add Employee',
      ),
    );
  }
}
