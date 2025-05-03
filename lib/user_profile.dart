import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfilePage extends StatefulWidget {
  final User? currentUser;

  const UserProfilePage({Key? key, required this.currentUser}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isLoading = true;
  int _totalGames = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      DocumentSnapshot statsDoc = await FirebaseFirestore.instance
          .collection('user_stats')
          .doc(widget.currentUser?.uid)
          .get();

      if (statsDoc.exists) {
        final data = statsDoc.data() as Map<String, dynamic>;
        setState(() {
          _totalGames = data['party'] ?? 0;
          _totalPoints = data['points'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _totalGames = 0;
          _totalPoints = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des statistiques: $e');
      setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mon Profil'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar et informations de base
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),
                  // Email
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.email, color: Colors.blue),
                      title: Text('Email'),
                      subtitle: Text(widget.currentUser?.email ?? ''),
                    ),
                  ),
                  // Date d'inscription
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text('Membre depuis'),
                      subtitle: Text(widget.currentUser?.metadata.creationTime
                          ?.toString()
                          .split(' ')[0] ??
                          ''),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Statistiques
            Text(
              'Statistiques',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.games, color: Colors.blue, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Parties jouées',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _totalGames.toString(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Points gagnés',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _totalPoints.toString(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}