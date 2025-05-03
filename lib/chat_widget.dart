import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class ChatWidget extends StatefulWidget {
  final String roomId;
  final String currentWord;
  final bool isDrawer;

  const ChatWidget({
    super.key,
    required this.roomId,
    required this.currentWord,
    required this.isDrawer,
  });

  @override
  _ChatWidgetState createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

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

  Future<void> _updateUserPoints() async {
    try {
      DocumentReference statsRef = _firestore
          .collection('user_stats')
          .doc(currentUser?.uid);

      // Vérifier si le document existe
      DocumentSnapshot statsDoc = await statsRef.get();
      if (statsDoc.exists) {
        // Mettre à jour seulement les points
        await statsRef.update({
          'points': FieldValue.increment(1)
        });
      } else {
        // Créer le document avec tous les champs
        await statsRef.set({
          'points': 1,
          'party': 0,
          'user': currentUser?.uid
        });
      }
    } catch (e) {
      print('Erreur mise à jour points: $e');
    }
  }


  Future<void> _clearDrawing() async {
    try {
      final batch = _firestore.batch();
      final drawingDocs = await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('drawing')
          .get();

      for (var doc in drawingDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('Dessin effacé avec succès');
    } catch (e) {
      print('Erreur lors de l\'effacement du dessin: $e');
    }
  }

  Future<void> _changeWordAndDrawer() async {
    try {
      // Récupérer les données actuelles de la room
      DocumentSnapshot roomDoc = await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .get();

      if (!roomDoc.exists) return;

      Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
      List<dynamic> players = roomData['players'] ?? [];

      if (players.isEmpty) return;

      // Trouver le prochain dessinateur
      int currentDrawerIndex = players.indexOf(roomData['currentDrawer']);
      int nextDrawerIndex = (currentDrawerIndex + 1) % players.length;
      String nextDrawerId = players[nextDrawerIndex];

      // Obtenir un nouveau mot
      String newWord = await _getRandomWord();

      // Mettre à jour la room
      await _firestore.collection('rooms').doc(widget.roomId).update({
        'currentWord': newWord,
        'currentDrawer': nextDrawerId,
      });

      // Effacer le dessin précédent
      await _clearDrawing();

      print('Nouveau mot et dessinateur mis à jour avec succès');
    } catch (e) {
      print('Erreur lors du changement de mot et de dessinateur: $e');
    }
  }

  Future<void> _updatePlayerScore() async {
    try {
      // Récupérer les données actuelles
      DocumentSnapshot roomDoc = await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .get();

      if (!roomDoc.exists) return;

      Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
      List<dynamic> playerInfo = roomData['playerInfo'] ?? [];

      // Mettre à jour le score du joueur
      bool playerFound = false;
      for (int i = 0; i < playerInfo.length; i++) {
        if (playerInfo[i]['uid'] == currentUser?.uid) {
          playerInfo[i]['score'] = (playerInfo[i]['score'] ?? 0) + 1;
          playerFound = true;
          break;
        }
      }

      if (playerFound) {
        // Sauvegarder le nouveau score
        await _firestore.collection('rooms').doc(widget.roomId).update({
          'playerInfo': playerInfo,
        });

        // Changer le mot et le dessinateur
        await _changeWordAndDrawer();

        print('Score mis à jour et nouveau tour initialisé');
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du score: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;


    try {
      String messageText = _messageController.text.trim().toLowerCase();
      String currentWord = widget.currentWord.toLowerCase();
      bool hasFoundWord = messageText == currentWord;

      // Vérifier si le dessinateur essaie de deviner
      if (widget.isDrawer && hasFoundWord) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le dessinateur ne peut pas deviner le mot !'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Envoyer le message
      await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'text': _messageController.text,
        'senderId': currentUser?.uid,
        'senderEmail': currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
        'isCorrectGuess': hasFoundWord && !widget.isDrawer,
      });

      // Si le mot est trouvé
      if (hasFoundWord && !widget.isDrawer) {
        await _updatePlayerScore();
        await _updateUserPoints();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bravo ! Vous avez trouvé le mot ! Changement de joueur...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Effacer le champ de texte
      _messageController.clear();
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi du message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index];
                    final isCurrentUser = message['senderId'] == currentUser?.uid;
                    final isCorrectGuess = message['isCorrectGuess'] ?? false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Align(
                        alignment: isCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCorrectGuess
                                ? Colors.green[100]
                                : (isCurrentUser
                                ? Colors.blue[100]
                                : Colors.grey[300]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isCurrentUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['senderEmail'] ?? 'Anonymous',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(message['text']),
                              if (isCorrectGuess)
                                Text(
                                  '✓ Mot trouvé !',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: widget.isDrawer
                          ? 'Vous êtes le dessinateur !'
                          : 'Devinez le mot...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}