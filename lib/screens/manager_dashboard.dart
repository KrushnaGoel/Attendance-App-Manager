import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manager/screens/edit_employee_detail.dart';
import 'package:manager/screens/edit_manager_profile.dart';
import 'package:manager/main.dart'; 

class ManagerDashboard extends StatefulWidget {
  @override
  _ManagerDashboardState createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final User? user = FirebaseAuth.instance.currentUser;
  late String managerEmail;

  @override
  void initState() {
    super.initState();
    managerEmail = user?.email?.toLowerCase() ?? '';
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      MyApp.loginRoute,
      (route) => false,
    );
  }

  Stream<QuerySnapshot> _getEmployeesStream() {
    return FirebaseFirestore.instance
        .collection('employees')
        .where('managerEmail', isEqualTo: managerEmail)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.pushNamed(context, MyApp.editManagerProfileRoute),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getEmployeesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching employees.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final employees = snapshot.data?.docs ?? [];
          if (employees.isEmpty) {
            return Center(child: Text('No employees found.'));
          }
          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              DocumentSnapshot employeeDoc = employees[index];
              String employeeEmail = employeeDoc.id;
              String employeeName = employeeDoc['name'] ?? 'Unnamed';

              return EmployeeCard(
                employeeEmail: employeeEmail,
                employeeName: employeeName,
                managerEmail: managerEmail,
              );
            },
          );
        },
      ),
    );
  }
}

class EmployeeCard extends StatefulWidget {
  final String employeeEmail;
  final String employeeName;
  final String managerEmail;

  const EmployeeCard({
    required this.employeeEmail,
    required this.employeeName,
    required this.managerEmail,
  });

  @override
  _EmployeeCardState createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<EmployeeCard> {
  Duration _timeInOffice = Duration(seconds: 0);
  bool _isInOffice = false;
  Timer? _updateTimer; // Timer to refresh the UI every second when employee is in the office

  @override
  void initState() {
    super.initState();
    _listenToAttendanceUpdates();
  }

  void _listenToAttendanceUpdates() {
    String date = DateTime.now().toString().split(' ')[0]; // Get YYYY-MM-DD
    String documentId = '${widget.employeeEmail}_$date';

    FirebaseFirestore.instance
        .collection('attendance')
        .doc(documentId)
        .snapshots()
        .listen((attendanceDoc) {
      if (attendanceDoc.exists) {
        Map<String, dynamic> data = attendanceDoc.data() as Map<String, dynamic>;
        List<dynamic> inOutTimes = data['inOutTimes'] ?? [];
        double totalWorkDuration = (data['totalWorkDuration'] as num?)?.toDouble() ?? 0.0;

        bool isInOffice = false;
        Duration currentSessionDuration = Duration.zero;

        if (inOutTimes.isNotEmpty) {
          var lastEntry = inOutTimes.last;
          if (lastEntry['outTime'] == null) {
            isInOffice = true;
            Timestamp inTimestamp = lastEntry['inTime'];
            DateTime inTime = inTimestamp.toDate();
            DateTime now = DateTime.now();
            currentSessionDuration = now.difference(inTime);
          }
        }

        Duration totalTime = Duration(
                milliseconds: (totalWorkDuration * 3600 * 1000).toInt()) +
            currentSessionDuration;

        setState(() {
          _isInOffice = isInOffice;
          _timeInOffice = totalTime;
        });

        if (isInOffice) {
          _startUpdateTimer();
        } else {
          _stopUpdateTimer();
        }
      } else {
        // No attendance record for today
        setState(() {
          _isInOffice = false;
          _timeInOffice = Duration(seconds: 0);
        });
        _stopUpdateTimer();
      }
    });
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel(); // Cancel any existing timer
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      // Trigger a rebuild every second to update the timer display
      setState(() {
        // Recalculate the time in office to reflect the ongoing session
        _timeInOffice = _timeInOffice + Duration(seconds: 1);
      });
    });
  }

  void _stopUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours.remainder(24));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _editEmployee() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEmployeePage(
          employeeEmail: widget.employeeEmail,
          employeeName: widget.employeeName,
        ),
      ),
    );
  }

  Future<void> _removeEmployee() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Employee'),
        content: Text('Are you sure you want to remove this employee?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm) {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeEmail)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Employee removed successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _isInOffice ? Colors.green[50] : Colors.red[50],
      child: ListTile(
        title: Text(
          widget.employeeName,
          style: TextStyle(fontSize: 18),
        ),
        subtitle: Text(
          'Time in Office: ${_formatDuration(_timeInOffice)}',
          style: TextStyle(fontSize: 16),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _editEmployee,
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _removeEmployee,
            ),
          ],
        ),
      ),
    );
  }
}