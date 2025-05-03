import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayersDrawer extends StatelessWidget {
  final String roomId;
  final List<dynamic> players;
  final List<dynamic> playerInfo;
  final User? currentUser;
  final String? creatorId;

  const PlayersDrawer({
    super.key,
    required this.roomId,
    required this.players,
    required this.playerInfo,
    required this.currentUser,
    this.creatorId,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.people,
                      size: 35,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Joueurs (${playerInfo.length}/5)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: playerInfo.length,
                itemBuilder: (context, index) {
                  final player = playerInfo[index];
                  final isCurrentPlayer = player['uid'] == currentUser?.uid;
                  final isCreator = player['uid'] == creatorId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isCurrentPlayer ? Colors.blue : Colors.grey,
                      child: Text(
                        player['email']
                            .toString()
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            player['email'].toString(),
                            style: TextStyle(
                              fontWeight: isCurrentPlayer
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isCreator)
                          Icon(Icons.star, color: Colors.amber, size: 20),
                      ],
                    ),
                    subtitle: Text('Score: ${player['score']} points'),
                    trailing: isCurrentPlayer
                        ? Chip(
                            label: Text(
                              'Vous',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.blue,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
