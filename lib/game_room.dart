import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'drawing_board.dart';
import 'chat_widget.dart';
import 'players_drawer.dart';

class GameRoom extends StatefulWidget {
  final String roomId;

  const GameRoom({super.key, required this.roomId});

  @override
  _GameRoomState createState() => _GameRoomState();
}

class _GameRoomState extends State<GameRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isJoined = false;
  bool _isLoading = true;
  Map<String, dynamic>? _playerData;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  Future<void> _initializeRoom() async {
    try {
      await _checkAndJoinRoom();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Erreur lors de l\'initialisation de la room: $e');
      _showError('Erreur lors de l\'initialisation de la room');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _checkAndJoinRoom() async {
    if (currentUser == null) {
      _showError('Vous devez être connecté pour rejoindre une room');
      Navigator.pop(context);
      return;
    }

    try {
      DocumentSnapshot roomSnapshot = await _firestore.collection('rooms').doc(widget.roomId).get();

      if (!roomSnapshot.exists) {
        _showError('Cette room n\'existe plus');
        Navigator.pop(context);
        return;
      }

      Map<String, dynamic> roomData = roomSnapshot.data() as Map<String, dynamic>;
      List<dynamic> players = roomData['players'] ?? [];

      // La première fois que le joueur rejoint cette room
      if (!players.contains(currentUser?.uid)) {
        await _incrementPartyCount();
      }

      if (players.contains(currentUser?.uid)) {
        List<dynamic> playerInfo = roomData['playerInfo'] ?? [];
        for (var player in playerInfo) {
          if (player['uid'] == currentUser?.uid) {
            _playerData = Map<String, dynamic>.from(player);
            break;
          }
        }
        setState(() => _isJoined = true);
        return;
      }

      if (players.length >= 5) {
        _showError('La room est pleine (5/5)');
        Navigator.pop(context);
        return;
      }

      _playerData = {
        'uid': currentUser?.uid,
        'email': currentUser?.email,
        'score': 0,
        'joinedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _firestore.collection('rooms').doc(widget.roomId).update({
        'players': FieldValue.arrayUnion([currentUser?.uid]),
        'playerInfo': FieldValue.arrayUnion([_playerData])
      });

      setState(() => _isJoined = true);
    } catch (e) {
      print('Erreur lors de la jointure de la room: $e');
      _showError('Erreur lors de la jointure de la room');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _incrementPartyCount() async {
    try {
      DocumentReference statsRef = _firestore.collection('user_stats').doc(currentUser?.uid);

      DocumentSnapshot statsDoc = await statsRef.get();
      if (statsDoc.exists) {
        await statsRef.update({
          'party': FieldValue.increment(1)
        });
      } else {
        await statsRef.set({
          'party': 1,
          'points': 0,
          'user': currentUser?.uid
        });
      }
    } catch (e) {
      print('Erreur mise à jour parties: $e');
    }
  }

  Future<void> _leaveRoom() async {
    if (!_isJoined || currentUser == null || _playerData == null) return;

    try {
      await _firestore.collection('rooms').doc(widget.roomId).update({
        'players': FieldValue.arrayRemove([currentUser?.uid]),
        'playerInfo': FieldValue.arrayRemove([_playerData])
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Erreur lors de la sortie de la room: $e');
      _showError('Erreur lors de la sortie de la room');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _openPlayersDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('rooms').doc(widget.roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.data!.exists) {
          Future.microtask(() {
            if (mounted) Navigator.pop(context);
          });
          return Scaffold(
            body: Center(child: Text('Cette room n\'existe plus')),
          );
        }

        final roomData = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> players = roomData['players'] ?? [];
        final List<dynamic> playerInfo = roomData['playerInfo'] ?? [];
        final String currentWord = roomData['currentWord'] ?? '';
        final String currentDrawerId = roomData['currentDrawer'] ?? '';
        final bool isGameActive = roomData['isGameActive'] ?? false;
        final String creatorId = roomData['createdBy'] ?? '';

        print("DEBUG VALUES:");
        print("creatorId: $creatorId");
        print("currentWord: $currentWord");
        print("currentUser?.uid: ${currentUser?.uid}");
        print("isCreator: ${currentUser?.uid == creatorId}");

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text('PictionIonis - Room ${widget.roomId.substring(0, 5)}'),
            leading: IconButton(
              icon: Badge(
                label: Text(playerInfo.length.toString()),
                child: Icon(Icons.people),
              ),
              onPressed: _openPlayersDrawer,
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.exit_to_app),
                onPressed: _leaveRoom,
                tooltip: 'Quitter la room',
              ),
            ],
          ),
          endDrawer: PlayersDrawer(
            roomId: widget.roomId,
            players: players,
            playerInfo: playerInfo,
            currentUser: currentUser,
            creatorId: creatorId,
          ),
          body: Column(
            children: [
              Expanded(
                flex: 2,
                child: DrawingBoard(
                  roomId: widget.roomId,
                  canDraw: currentUser?.uid == currentDrawerId,
                  isCreator: currentUser?.uid ==
                      creatorId, // Vérifiez que cette valeur est correcte
                  currentWord:
                      currentWord, // Vérifiez que cette valeur n'est pas vide
                ),
              ),
              Expanded(
                flex: 1,
                child: ChatWidget(
                  roomId: widget.roomId,
                  currentWord: currentWord,
                  isDrawer: currentUser?.uid == currentDrawerId,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (_isJoined && currentUser != null && _playerData != null) {
      _firestore.collection('rooms').doc(widget.roomId).update({
        'players': FieldValue.arrayRemove([currentUser?.uid]),
        'playerInfo': FieldValue.arrayRemove([_playerData])
      }).catchError((error) {
        print('Erreur lors de la sortie de la room dans dispose: $error');
      });
    }
    super.dispose();
  }
}
