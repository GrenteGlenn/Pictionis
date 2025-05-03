import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_room.dart';
import 'user_profile.dart';

class CreateRoomDialog extends StatefulWidget {
  final Function(String?) onCreateRoom;

  const CreateRoomDialog({Key? key, required this.onCreateRoom}) : super(key: key);

  @override
  _CreateRoomDialogState createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  bool usePassword = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Créer une nouvelle room'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: Text('Protéger par mot de passe'),
            value: usePassword,
            onChanged: (bool value) {
              setState(() {
                usePassword = value;
              });
            },
          ),
          if (usePassword)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            String? password = usePassword ? _passwordController.text : null;
            if (usePassword && password!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Veuillez entrer un mot de passe'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.pop(context);
            widget.onCreateRoom(password);
          },
          child: Text('Créer'),
        ),
      ],
    );
  }
}

class PasswordDialog extends StatefulWidget {
  final String roomId;
  final String expectedPassword;

  const PasswordDialog({
    Key? key,
    required this.roomId,
    required this.expectedPassword,
  }) : super(key: key);

  @override
  _PasswordDialogState createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  String? errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Room protégée par mot de passe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              border: OutlineInputBorder(),
              errorText: errorMessage,
            ),
            obscureText: true,
            onSubmitted: (_) => _verifyPassword(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _verifyPassword,
          child: Text('Rejoindre'),
        ),
      ],
    );
  }

  void _verifyPassword() {
    if (_passwordController.text == widget.expectedPassword) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        errorMessage = 'Mot de passe incorrect';
      });
    }
  }
}

class RoomSelectionPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  RoomSelectionPage({super.key});

  Future<String> _getRandomWord() async {
    try {
      String data = await rootBundle.loadString('assets/words.json');
      final jsonResult = json.decode(data);
      List<String> words = List<String>.from(jsonResult['words']);
      return words[Random().nextInt(words.length)];
    } catch (e) {
      print('Erreur lors du chargement du mot: $e');
      return 'maison';
    }
  }

  Future<void> _showCreateRoomDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => CreateRoomDialog(
        onCreateRoom: (password) => _createRoom(context, password),
      ),
    );
  }

  Future<void> _createRoom(BuildContext context, String? password) async {
    try {
      final String randomWord = await _getRandomWord();

      final playerInfo = [
        {
          'uid': currentUser?.uid,
          'email': currentUser?.email,
          'score': 0,
        }
      ];

      final roomRef = await _firestore.collection('rooms').add({
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.uid,
        'players': [currentUser?.uid],
        'playerInfo': playerInfo,
        'currentWord': randomWord,
        'isGameActive': false,
        'currentDrawer': currentUser?.uid,
        'hasPassword': password != null,
        'password': password,
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameRoom(roomId: roomRef.id),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la création de la room: $e');
    }
  }

  Future<void> _joinRoom(BuildContext context, DocumentSnapshot room) async {
    final hasPassword = room['hasPassword'] ?? false;
    final password = room['password'];

    if (hasPassword) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => PasswordDialog(
          roomId: room.id,
          expectedPassword: password,
        ),
      );

      if (confirmed != true) return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameRoom(roomId: room.id),
        ),
      );
    }
  }

  Future<void> _deleteEmptyRooms() async {
    try {
      QuerySnapshot rooms = await _firestore
          .collection('rooms')
          .where('isGameActive', isEqualTo: false)
          .get();

      for (DocumentSnapshot room in rooms.docs) {
        List<dynamic> players = room['players'] ?? [];
        if (players.isEmpty) {
          await _deleteRoomSubcollections(room.id);
          await room.reference.delete();
        }
      }
    } catch (e) {
      print('Erreur lors de la suppression des rooms vides: $e');
    }
  }

  Future<void> _deleteRoomSubcollections(String roomId) async {
    try {
      var messages = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .get();
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }

      var drawings = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('drawing')
          .get();
      for (var doc in drawings.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Erreur lors de la suppression des sous-collections: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _deleteEmptyRooms());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.settings),
          tooltip: 'Paramètres du profil',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(currentUser: currentUser),
              ),
            );
          },
        ),
        centerTitle: true,  // Centre le titre
        title: Text('PictionIonis'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _deleteEmptyRooms,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _showCreateRoomDialog(context),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15.0),
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Créer une nouvelle room',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('rooms')
                  .where('isGameActive', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur de chargement',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final nonEmptyRooms = snapshot.data!.docs.where((room) {
                  List<dynamic> players = room['players'] ?? [];
                  return players.isNotEmpty;
                }).toList();

                if (nonEmptyRooms.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune room disponible',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: nonEmptyRooms.length,
                    itemBuilder: (context, index) {
                      final room = nonEmptyRooms[index];
                      final players = room['players'] as List;
                      final creatorId = room['createdBy'] as String?;
                      final hasPassword = room['hasPassword'] ?? false;
                      final creator = room['playerInfo'].firstWhere(
                            (player) => player['uid'] == creatorId,
                        orElse: () => {'email': 'Anonyme'},
                      );

                      return InkWell(
                        onTap: () => _joinRoom(context, room),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.blue[600]!, Colors.blue[800]!],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.games,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                  if (hasPassword)
                                    Positioned(
                                      right: -10,
                                      top: -10,
                                      child: Icon(
                                        Icons.lock,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Room ${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Créée par: ${creator['email'].toString().split('@')[0]}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 5),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${players.length}/5 joueurs',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}